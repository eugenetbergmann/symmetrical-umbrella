IF OBJECT_ID('dbo.ETB2_Planning_Net_Requirements', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Planning_Net_Requirements;
GO

CREATE VIEW dbo.ETB2_Planning_Net_Requirements AS
WITH Demand_Aggregated AS (
    SELECT
        ITEMNMBR,
        SUM(CAST(Base_Demand_Qty AS NUMERIC(18, 4))) AS Total_Demand,
        COUNT(DISTINCT CAST(DUEDATE AS DATE)) AS Demand_Days,
        MIN(CAST(DUEDATE AS DATE)) AS Earliest_Demand_Date,
        MAX(CAST(DUEDATE AS DATE)) AS Latest_Demand_Date
    FROM dbo.ETB2_Demand_Cleaned_Base
    WHERE Is_Within_Active_Planning_Window = 1
    GROUP BY ITEMNMBR
)
SELECT
    ITEMNMBR,
    CAST(Total_Demand AS NUMERIC(18, 4)) AS Net_Requirement_Qty,
    CAST(0 AS NUMERIC(18, 4)) AS Safety_Stock_Level,
    Demand_Days AS Days_Of_Supply,
    CASE
        WHEN Total_Demand = 0 THEN 'NONE'
        WHEN Total_Demand <= 100 THEN 'LOW'
        WHEN Total_Demand <= 500 THEN 'MEDIUM'
        ELSE 'HIGH'
    END AS Requirement_Priority,
    'DAYS_OF_SUPPLY' AS Requirement_Status,
    Earliest_Demand_Date,
    Latest_Demand_Date
FROM Demand_Aggregated
ORDER BY 
    CASE
        WHEN Total_Demand = 0 THEN 4
        WHEN Total_Demand <= 100 THEN 3
        WHEN Total_Demand <= 500 THEN 2
        ELSE 1
    END ASC,
    Total_Demand DESC;
GO

-- TEST: Run this to verify view works
SELECT TOP 20 * FROM dbo.ETB2_Planning_Net_Requirements;
