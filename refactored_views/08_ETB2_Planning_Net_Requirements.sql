-- ============================================================================
-- VIEW 08: dbo.ETB2_Planning_Net_Requirements
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire WITH...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Planning_Net_Requirements
-- ============================================================================
-- Purpose: Net requirements calculation from demand within planning window
-- Grain: Item
-- Dependencies:
--   - dbo.ETB2_Demand_Cleaned_Base (view 04)
-- Last Updated: 2026-01-28
-- ============================================================================

WITH Demand_Aggregated AS (
    SELECT
        ITEMNMBR,
        SUM(COALESCE(TRY_CAST(Base_Demand_Qty AS NUMERIC(18, 4)), 0)) AS Total_Demand,
        COUNT(DISTINCT CAST(DUEDATE AS DATE)) AS Demand_Days,
        COUNT(DISTINCT ORDERNUMBER) AS Order_Count,
        MIN(CAST(DUEDATE AS DATE)) AS Earliest_Demand_Date,
        MAX(CAST(DUEDATE AS DATE)) AS Latest_Demand_Date
    FROM dbo.ETB2_Demand_Cleaned_Base WITH (NOLOCK)
    WHERE Is_Within_Active_Planning_Window = 1
    GROUP BY ITEMNMBR
)
SELECT
    ITEMNMBR,
    CAST(Total_Demand AS NUMERIC(18, 4)) AS Net_Requirement_Qty,
    CAST(0 AS NUMERIC(18, 4)) AS Safety_Stock_Level,
    Demand_Days AS Days_Of_Supply,
    Order_Count,
    CASE
        WHEN Total_Demand = 0 THEN 'NONE'
        WHEN Total_Demand <= 100 THEN 'LOW'
        WHEN Total_Demand <= 500 THEN 'MEDIUM'
        ELSE 'HIGH'
    END AS Requirement_Priority,
    CASE
        WHEN Total_Demand = 0 THEN 'NO_DEMAND'
        WHEN Total_Demand <= 100 THEN 'LOW_PRIORITY'
        WHEN Total_Demand <= 500 THEN 'MEDIUM_PRIORITY'
        ELSE 'HIGH_PRIORITY'
    END AS Requirement_Status,
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
    Total_Demand DESC
