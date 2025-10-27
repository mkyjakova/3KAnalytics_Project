/*H1: Měsíce červen–srpen tvoří více než 70 % celkových tržeb.*/
SELECT
  d.Year
  SUM(sf.Price) AS Total_Revenue,
  SUM(CASE WHEN d.Month IN (6,7,8) THEN sf.Price ELSE 0 END) AS Summer_Revenue,
  ROUND(
    (SUM(CASE WHEN d.Month IN (6,7,8) THEN sf.Price ELSE 0 END) * 1.0 /               --- 1.0 použijeme pro zajišťuje, že dělení proběhne jako desetinné (FLOAT/DECIMAL) dělení
     SUM(sf.Price)) * 100, 2                                                          ---2 → říká ROUND, aby výsledek měl dvě desetinná místa
  ) AS Season_Share_Pct
FROM Sales_Fact sf
JOIN Date_Dim d ON sf.Date = d.Date
GROUP BY d.Year
ORDER BY d.Year;

---------------------------------------------------------------------------------------


/*H2:*/
-- H2.1 - Analýza sezónních měsíců po jednotlivých rocích
WITH Season_Monthly AS (
    SELECT
        Year,
        Month,
        SUM(Seasonal_Revenue) AS Revenue
    FROM v_Sales_Summary
    WHERE Month IN (6, 7, 8)
    GROUP BY Year, Month
)
SELECT
    Year,
    Month,
    Revenue,
    --RANK() → přiřadí pořadí (1, 2, 3, …),
    --OVER (PARTITION BY PeriodType ...) rozdělí data podle PeriodType, tedy každé období se hodnotí zvlášť
    --ORDER BY Revenue DESC → nejvyšší tržba má rank = 1
    RANK() OVER (PARTITION BY Year ORDER BY Revenue DESC) AS Rank_in_Season
FROM Season_Monthly
ORDER BY Year, Month;

-- H2.2 - Porovnání podle typu období (Pandemic vs Normal)
--hodnotí všechny roky dohromady, který měsíc byl nejsilnější v období pandemie a který v nomálním
WITH Season_Period AS (
    SELECT
        PeriodType,
        Month,
        SUM(Price) AS Revenue
    FROM v_Sales_Base
    WHERE IsSeason = 1
    GROUP BY PeriodType, Month
)
SELECT
    PeriodType,
    Month,
    Revenue,
    RANK() OVER (PARTITION BY PeriodType ORDER BY Revenue DESC) AS MonthRank
FROM Season_Period
ORDER BY PeriodType, Month, MonthRank;

-- H2.3 - Podíl července na celé sezóně (všechny roky dohromady)
SELECT
    Month,
    SUM(Seasonal_Revenue) AS Revenue,
    ROUND(100.0 * SUM(Seasonal_Revenue) /
        SUM(SUM(Seasonal_Revenue)) OVER (), 2) AS Pct_of_Season
FROM v_Sales_Summary
WHERE Month IN (6,7,8)
GROUP BY Month
ORDER BY Month;

--H2.4 Podíl července na celé sezóně (za nepandemické roky)
SELECT
    Month,
    SUM(Seasonal_Revenue) AS Revenue,
    ROUND(100.0 * SUM(Seasonal_Revenue) /
        SUM(SUM(Seasonal_Revenue)) OVER (), 2) AS Pct_of_Season
FROM v_Sales_Summary
WHERE 
    Month IN (6,7,8)
    AND Year NOT IN (2020, 2021, 2022)
GROUP BY Month
ORDER BY Month;

--------------------------------------------------------------------

/*H3.1 Základní dotaz — identifikace sezónních měsíců (práh = 45% ročního maxima)
Tento dotaz:
vypočítá pro každý rok, které měsíce jsou „aktivní“ (is_active = 1),
určí první a poslední aktivní měsíc a délku sezóny.*/

WITH monthly AS (
    -- měsíční tržby (používáme už připravené view)
    SELECT Year, Month, Total_Revenue
    FROM v_Sales_Summary
    -- pokud chcete testovat pouze normální roky (bez pandemie), odkomentujte:
    WHERE Year NOT IN (2020,2021,2022)
),
yr_stats AS (
    -- statistiky na rok: roční maximum (použijeme jako referenci)
    SELECT
        Year,
        MAX(Total_Revenue) AS year_max_rev,
        AVG(Total_Revenue) AS year_avg_rev
    FROM monthly
    GROUP BY Year
),
marked AS (
    -- označíme měsíce, které jsou "v sezóně" podle prahu (45 % z ročního maxima)
    SELECT
        m.Year,
        m.Month,
        m.Total_Revenue,
        s.year_max_rev,
        s.year_avg_rev,
        CASE
            WHEN m.Total_Revenue >= 0.45 *s.year_max_rev THEN 1            --pokud chceš ověři hypotézu ohledně posunu sezóny posuň hranici na 0,25 --> 25% sezónního maxima
            ELSE 0
        END AS is_active
    FROM monthly m
    JOIN yr_stats s ON m.Year = s.Year
),
season_bounds AS (
    -- pro každý rok najdeme první a poslední aktivní měsíc a délku (počet měsíců)
    SELECT
        Year,
        MIN(CASE WHEN is_active = 1 THEN Month END) AS season_start_month,
        MAX(CASE WHEN is_active = 1 THEN Month END) AS season_end_month,
        SUM(is_active) AS season_months
    FROM marked
    GROUP BY Year
)
SELECT
    Year,
    season_start_month,
    season_end_month,
    season_months,
    (season_end_month - season_start_month + 1) AS season_length_span_months
FROM season_bounds
ORDER BY Year;

/*Test trendu (lineární sklon) — je start posouvající se dříve a konec později?
Po získání season_start_month a season_end_month pro každý rok můžeme spočítat jednoduchý lineární trend (slope) v SQL. Jeden způsob je spočítat lineární regresi (sklon) pro Year → season_start_month a Year → season_end_month.
Tady je jeden SQL blok, který spočítá slope pomocí klasického vzorce (kovariance/variance):*/

WITH monthly AS (
    SELECT Year, Month, Total_Revenue
    FROM v_Sales_Summary
    WHERE Year NOT IN (2020,2021,2022)
),
yr_stats AS (
    SELECT Year, MAX(Total_Revenue) AS year_max_rev
    FROM monthly
    GROUP BY Year
),
marked AS (
    SELECT m.Year, m.Month,
           CASE WHEN m.Total_Revenue >= yr.year_max_rev * 0.10 THEN 1 ELSE 0 END AS is_active
    FROM monthly m
    JOIN yr_stats yr ON m.Year = yr.Year
),
season_bounds AS (
    SELECT
        Year,
        MIN(CASE WHEN is_active = 1 THEN Month END) AS season_start,
        MAX(CASE WHEN is_active = 1 THEN Month END) AS season_end
    FROM marked
    GROUP BY Year
),
agg AS (
    SELECT
        CAST(COUNT(*) AS NUMERIC) AS n,
        CAST(AVG(Year) AS NUMERIC) AS avg_year,
        CAST(AVG(season_start) AS NUMERIC) AS avg_start,
        CAST(AVG(season_end) AS NUMERIC) AS avg_end
    FROM season_bounds
),
cov_var AS (
    SELECT
        SUM( (sb.Year - a.avg_year) * (sb.season_start - a.avg_start) ) AS cov_year_start,
        SUM( (sb.Year - a.avg_year) * (sb.Year - a.avg_year) ) AS var_year,
        SUM( (sb.Year - a.avg_year) * (sb.season_end - a.avg_end) ) AS cov_year_end
    FROM season_bounds sb
    CROSS JOIN (SELECT * FROM agg) a
)

SELECT
    CASE WHEN var_year = 0 THEN NULL ELSE (cov_year_start / var_year) END AS slope_start_per_year,
    CASE WHEN var_year = 0 THEN NULL ELSE (cov_year_end / var_year) END AS slope_end_per_year
FROM cov_var;

-----------------------
--Ověření hypotézy pro startovní měsíc/ okrajový měsíc květen
WITH MonthlyGrowth AS (
    SELECT
        Year,
        Month,
        Total_Revenue,
        LAG(Total_Revenue) OVER (PARTITION BY Year ORDER BY Month) AS Prev_Revenue,
        CASE 
            WHEN LAG(Total_Revenue) OVER (PARTITION BY Year ORDER BY Month) IS NULL THEN NULL
            ELSE ROUND(
                (Total_Revenue - LAG(Total_Revenue) OVER (PARTITION BY Year ORDER BY Month)) 
                / NULLIF(LAG(Total_Revenue) OVER (PARTITION BY Year ORDER BY Month), 0) * 100, 1
            )
        END AS Growth_Pct
    FROM v_Sales_Summary
    WHERE Year NOT IN (2020, 2021, 2022)
)
SELECT
    Year,
    Month,
    Total_Revenue,
    Growth_Pct
FROM MonthlyGrowth
WHERE Growth_Pct > 50  -- můžeš si hranici upravit, např. 30 % nebo 100 %
ORDER BY Year, Month;

------------------------
--Nalezení prního výraznějšího růstu oproti předchozímu měsíci
WITH MonthlyGrowth AS (
    SELECT
        Year,
        Month,
        Total_Revenue,
        LAG(Total_Revenue) OVER (PARTITION BY Year ORDER BY Month) AS Prev_Revenue,
        CASE 
            WHEN LAG(Total_Revenue) OVER (PARTITION BY Year ORDER BY Month) IS NULL THEN NULL
            ELSE ROUND(
                (Total_Revenue - LAG(Total_Revenue) OVER (PARTITION BY Year ORDER BY Month)) 
                / NULLIF(LAG(Total_Revenue) OVER (PARTITION BY Year ORDER BY Month), 0) * 100, 1
            )
        END AS Growth_Pct
    FROM v_Sales_Summary
    WHERE Year NOT IN (2020, 2021)
)
SELECT Year, Month, Total_Revenue, Growth_Pct
FROM MonthlyGrowth
WHERE Year NOT IN (2020,2021)
ORDER BY Year, Month;

-----H3.2 Podíl května na sezóně (jen nepandemické roky) - sezónní mají kolem kolem 25% a více 5 měsíc po pandemickém roce dosahuje kolem 9%
                                                         -- dokonce i v po pandemickém období 2022
                                                         -- porovnejte procentuálně s jinými měsíci
WITH Season_Months AS (
    SELECT
        Year,
        Month,
        SUM(Total_Revenue) AS Total_Revenue
    FROM v_Sales_Summary
    WHERE Year NOT IN (2020, 2021)
      AND Month BETWEEN 5 AND 8  -- květen až srpen
    GROUP BY Year, Month
),
Season_Sum AS (
    SELECT
        Year,
        SUM(Total_Revenue) AS Season_Revenue
    FROM Season_Months
    GROUP BY Year
)
SELECT
    m.Year,
    MONTH,
    ROUND(m.Total_Revenue / s.Season_Revenue * 100, 1) AS May_Share_Pct
FROM Season_Months m
JOIN Season_Sum s ON m.Year = s.Year
WHERE Month BETWEEN 5 AND 8
ORDER BY m.Year, Month;

--------Podíl května na sezóně (i pandemické roky)
       -- jeho samostatný procentuální růst
WITH Season_Months AS (
    SELECT
        Year,
        Month,
        SUM(Total_Revenue) AS Total_Revenue
    FROM v_Sales_Summary
    WHERE Month BETWEEN 5 AND 9  -- květen až srpen
    GROUP BY Year, Month
),
Season_Sum AS (
    SELECT
        Year,
        SUM(Total_Revenue) AS Season_Revenue
    FROM Season_Months
    GROUP BY Year
)
SELECT
    m.Year,
    ROUND(m.Total_Revenue / s.Season_Revenue * 100, 1) AS May_Share_Pct
FROM Season_Months m
JOIN Season_Sum s ON m.Year = s.Year
WHERE m.Month = 5
ORDER BY m.Year;

-------------------------------------------------------

/*H4 Meziroční % změny (Year-over-Year, YoY)*/
WITH yearly AS (
  SELECT
    Year,
    SUM(Total_Revenue) AS Revenue
  FROM v_Sales_Summary
  --WHERE Year NOT IN (2020, 2021,2022)    ---odkomentuj pokud chceš vidět jen nepandemické
  GROUP BY Year
)
SELECT
  Year,
  Revenue,
  LAG(Revenue) OVER (ORDER BY Year) AS Prev_Revenue,
  CASE
    WHEN LAG(Revenue) OVER (ORDER BY Year) IS NULL THEN NULL
    WHEN LAG(Revenue) OVER (ORDER BY Year) = 0 THEN NULL
    ELSE ROUND( (Revenue - LAG(Revenue) OVER (ORDER BY Year)) * 100.0 / LAG(Revenue) OVER (ORDER BY Year), 2)
  END AS YoY_pct
FROM yearly
ORDER BY Year;

/*H4.2CAGR — průměrné roční procentní tempo růstu mezi prvním a posledním rokem
Matematika: CAGR = (End / Start)^(1 / n) - 1, kde n = počet meziročních kroků (last_year - first_year).
-- CAGR mezi prvním a posledním rokem (možnost vyřadit pandemické roky)*/
WITH yearly AS (
  SELECT
    Year,
    SUM(Total_Revenue) AS Revenue
  FROM v_Sales_Summary
  -- odkomentuj následující řádek, pokud chceš vyloučit pandemické roky
  --WHERE Year NOT IN (2020,2021,2022)
  GROUP BY Year
),
bounds AS (
    SELECT
        MIN(Year) AS first_year,
        MAX(Year) AS last_year
    FROM yearly
),
vals AS (
    SELECT
        (SELECT Revenue FROM yearly WHERE Year = b.first_year) AS start_revenue,
        (SELECT Revenue FROM yearly WHERE Year = b.last_year) AS end_revenue,
        b.first_year,
        b.last_year,
        (b.last_year - b.first_year) AS years_diff
    FROM bounds b
)
SELECT
    first_year,
    last_year,
    years_diff,
    start_revenue,
    end_revenue,
    CASE
        WHEN start_revenue IS NULL OR end_revenue IS NULL OR start_revenue <= 0 OR years_diff = 0 THEN NULL
        ELSE ROUND(
            (POWER(CAST(end_revenue AS FLOAT) / CAST(start_revenue AS FLOAT), 1.0 / NULLIF(years_diff, 0)) - 1.0) * 100, 
            2
        )
    END AS CAGR_pct
FROM vals;
