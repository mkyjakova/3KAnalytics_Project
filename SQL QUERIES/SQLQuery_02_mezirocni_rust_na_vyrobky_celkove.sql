--zmeny po letech na vyrobky

--TOP vyrobky v jednotlivych letech (ks)
WITH RankedProducts AS (
    SELECT
        d.[Year],
        s.Product_en,
        SUM(s.Amount_pcs) AS AmountSoldYearly,
        RANK() OVER (PARTITION BY d.[Year] ORDER BY SUM(s.Amount_pcs) DESC) AS RankYear
    FROM
        Sales_Fact s
        JOIN Produktova_dimenze p ON s.Product_en = p.Product_en
        JOIN Date_Dim d ON s.[Date] = d.[Date]
    GROUP BY
        d.[Year], s.Product_en
)
SELECT
    [Year],
    Product_en,
    AmountSoldYearly
FROM
    RankedProducts
WHERE
    RankYear <= 5
ORDER BY
    [Year], RankYear

--TOP vyrobky v jednotlivych letech (revenue)
WITH RankedProducts AS (
    SELECT
        d.[Year],
        s.Product_en,
        SUM(s.Price) AS YearlyRevenue,
        RANK() OVER (PARTITION BY d.[Year] ORDER BY SUM(s.Price) DESC) AS RankYear
    FROM
        Sales_Fact s
        JOIN Produktova_dimenze p ON s.Product_en = p.Product_en
        JOIN Date_Dim d ON s.[Date] = d.[Date]
    GROUP BY
        d.[Year], s.Product_en
)
SELECT
    [Year],
    Product_en,
    YearlyRevenue
FROM
    RankedProducts
WHERE
    RankYear <= 5
ORDER BY
    [Year], RankYear

--Revenue na kazdy vyrobok po letech
SELECT
    p.Product_en,    
    SUM(CASE WHEN d.[Year] = 2019 THEN s.Price ELSE 0 END) AS Revenue2019,
    SUM(CASE WHEN d.[Year] = 2020 THEN s.Price ELSE 0 END) AS Revenue2020,
    SUM(CASE WHEN d.[Year] = 2021 THEN s.Price ELSE 0 END) AS Revenue2021,
    SUM(CASE WHEN d.[Year] = 2022 THEN s.Price ELSE 0 END) AS Revenue2022,
    SUM(CASE WHEN d.[Year] = 2023 THEN s.Price ELSE 0 END) AS Revenue2023,
    SUM(CASE WHEN d.[Year] = 2024 THEN s.Price ELSE 0 END) AS Revenue2024,
    SUM(CASE WHEN d.[Year] = 2025 THEN s.Price ELSE 0 END) AS Revenue2025,
    SUM(s.Price) AS TotalRevenue
FROM 
    Sales_Fact s
    JOIN Produktova_dimenze p ON s.Product_en = p.Product_en
    JOIN Date_Dim d ON s.[Date] = d.[Date]
GROUP BY
    p.Product_en
ORDER BY
    TotalRevenue DESC

--Revenue na kazdy vyrobok po letech jako procenta z celkoveho zisku
WITH RankedProducts AS (
    SELECT
        d.[Year],
        s.Product_en,
        SUM(s.Price) AS YearlyRevenue,
        100.0 * SUM(s.Price) / SUM(SUM(s.Price)) OVER (PARTITION BY d.[Year]) AS RevenueSharePercent,
        RANK() OVER (PARTITION BY d.[Year] ORDER BY SUM(s.Price) DESC) AS RankYear
    FROM
        Sales_Fact s
        JOIN Produktova_dimenze p ON s.Product_en = p.Product_en
        JOIN Date_Dim d ON s.[Date] = d.[Date]
    GROUP BY
        d.[Year], s.Product_en
)
SELECT
    [Year],
    Product_en,
    YearlyRevenue,
    ROUND(RevenueSharePercent, 2) AS RevenueSharePercent
FROM
    RankedProducts
WHERE
    RankYear <= 5
ORDER BY
    [Year], RankYear