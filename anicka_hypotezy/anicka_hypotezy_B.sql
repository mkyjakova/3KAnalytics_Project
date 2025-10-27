/*1) Logika (kroky)
Seskupit pro každý produkt celkové tržby (Total_Revenue) a tržby v sezóně (Seasonal_Revenue) a mimo sezónu (Offseason_Revenue).
Vypočítat podíl Seasonal_Share = Seasonal_Revenue / Total_Revenue (v %). Ošetřit dělení nulou.
Klasifikovat produkt podle prahů (>=70% → Seasonal, <=30% → NonSeasonal, jinak → Mixed).
Vybrat ze skupiny pouze ty, které odpovídají cílové kategorii (sezónní / nesezónní).
(Volitelné) řadit podle Seasonal_Share nebo Total_Revenue pro prioritu.

2) Univerzální CTE (základní agregace)
Toto použijeme jako základ pro oba dotazy.*/

-- 0) parametr: prahy a volitelně vyřazení pandemických roků
DECLARE @SEASONAL_THRESHOLD DECIMAL(5,2) = 0.70;  -- 70% + DECIMAL(5,2) znamená, že číslo může mít maximálně 5 číslic celkem, z toho 2 číslice za desetinnou čárkou.
DECLARE @NONSEASONAL_THRESHOLD DECIMAL(5,2) = 0.30; -- 30%
DECLARE @EXCLUDE_PANDEMIC BIT = 1; -- 1 = vyřadit roky 2020-2022, 0 = nevyřazovat

---------------------------------------------------------
-- 1) CTE: agregace tržeb po produktech (může být i po jednotkách)
---------------------------------------------------------
;WITH Sales_Agg AS (
    SELECT
        b.Product_en,
        b.Product_cz,
        SUM(b.Price) AS Total_Revenue,
        SUM(CASE WHEN b.IsSeason = 1 THEN b.Price ELSE 0 END) AS Seasonal_Revenue,
        SUM(CASE WHEN b.IsSeason = 0 THEN b.Price ELSE 0 END) AS Offseason_Revenue
    FROM v_Sales_Base b
    /* volitelně vyřadit pandemické roky */
    WHERE (@EXCLUDE_PANDEMIC = 0) OR (b.PeriodType <> 'Pandemic')
    GROUP BY
        b.Product_en,
        b.Product_cz
)
-- 2) vypočítat podíly a klasifikovat
, Sales_With_Share AS (
    SELECT
        Product_en,
        Product_cz,
        Total_Revenue,
        Seasonal_Revenue,
        Offseason_Revenue,
        /* ošetření dělení nulou: pokud Total_Revenue = 0, pak 0 */
        CASE WHEN Total_Revenue = 0 THEN 0.0
             ELSE CAST(Seasonal_Revenue AS float) / CAST(Total_Revenue AS float)
        END AS Seasonal_Share
    FROM Sales_Agg
)
SELECT * FROM Sales_With_Share; -- základní tabulka pro další filtrování


/*Vysvětlení:
SUM(CASE WHEN b.IsSeason = 1 THEN b.Price ELSE 0 END) spočítá tržby jen během sezóny.
Parametr @EXCLUDE_PANDEMIC vám dovolí rychle přepínat, jestli chcete v analýze zahrnout roky 2020–2022.
Seasonal_Share je mezi 0 a 1. Pokud chcete procenta, násobte *100 nebo vystavte jako ROUND(...*100,2).*/


;WITH Sales_Agg AS (
    SELECT b.Product_en, b.Product_cz,
           SUM(b.Price) AS Total_Revenue,
           SUM(CASE WHEN b.IsSeason = 1 THEN b.Price ELSE 0 END) AS Seasonal_Revenue,
           SUM(CASE WHEN b.IsSeason = 0 THEN b.Price ELSE 0 END) AS Offseason_Revenue
    FROM v_Sales_Base b
    WHERE (@EXCLUDE_PANDEMIC = 0) OR (b.PeriodType <> 'Pandemic')
    GROUP BY b.Product_en, b.Product_cz
),
Sales_With_Share AS (
    SELECT
        Product_en, Product_cz, Total_Revenue, Seasonal_Revenue, Offseason_Revenue,
        CASE WHEN Total_Revenue = 0 THEN 0.0 ELSE CAST(Seasonal_Revenue AS float) / CAST(Total_Revenue AS float) END AS Seasonal_Share
    FROM Sales_Agg
)
SELECT
    Product_en,
    Product_cz,
    Total_Revenue,
    Seasonal_Revenue,
    Offseason_Revenue,
    ROUND(Seasonal_Share * 100, 2) AS Seasonal_Share_pct,
    CASE
        WHEN Seasonal_Share >= @SEASONAL_THRESHOLD THEN 'Seasonal'
        WHEN Seasonal_Share <= @NONSEASONAL_THRESHOLD THEN 'NonSeasonal'
        ELSE 'Mixed'
    END AS Seasonality_Class
FROM Sales_With_Share
ORDER BY Seasonality_Class, Seasonal_Share DESC, Total_Revenue DESC;