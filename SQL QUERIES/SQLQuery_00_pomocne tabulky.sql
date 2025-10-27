--mezirocni rust (ks, rev, sezona)
-- rust trzeb mezirocne
SELECT
    d.[Year],
    SUM(Price) As YearlyRevenue
FROM 
    Sales_Fact s
    JOIN Date_Dim d ON s.[Date] = d.[Date]
GROUP BY
    d.[Year]
ORDER BY
    Year ASC

--rust prodeje kusu mezirocne
SELECT
    d.[Year],
    SUM(Amount_pcs) As YearlySoldItems
FROM 
    Sales_Fact s
    JOIN Date_Dim d ON s.[Date] = d.[Date]
GROUP BY
    d.[Year]
ORDER BY
    d.Year ASC

--rust trzeb mezirocne v sezone a mimo a rozdil
SELECT
    d.[Year],
    SUM(CASE WHEN d.IsSeason = 1 THEN s.Price ELSE 0 END) AS RevenueInSeason,
    SUM(CASE WHEN d.IsSeason = 0 THEN s.Price ELSE 0 END) AS RevenueOutOfSeason,
    SUM(CASE WHEN d.IsSeason = 1 THEN s.Price ELSE 0 END) - 
    SUM(CASE WHEN d.IsSeason = 0 THEN s.Price ELSE 0 END) AS Difference
FROM 
    Sales_Fact s
    JOIN Date_Dim d ON s.[Date] = d.[Date]
GROUP BY
    d.[Year]
ORDER BY
    d.[Year] ASC

--rust poctu prodanych ks mezirocne v sezone a mimo a rozdil
SELECT
    d.[Year],
    SUM(CASE WHEN d.IsSeason = 1 THEN s.Amount_pcs ELSE 0 END) AS RevenueInSeason,
    SUM(CASE WHEN d.IsSeason = 0 THEN s.Amount_pcs ELSE 0 END) AS RevenueOutOfSeason,
    SUM(CASE WHEN d.IsSeason = 1 THEN s.Amount_pcs ELSE 0 END) - 
    SUM(CASE WHEN d.IsSeason = 0 THEN s.Amount_pcs ELSE 0 END) AS Difference
FROM 
    Sales_Fact s
    JOIN Date_Dim d ON s.[Date] = d.[Date]
GROUP BY
    d.[Year]
ORDER BY
    d.[Year] ASC