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
--   - dbo.ETB2_Config_Items (view 02B) - for Item_Description, UOM_Schedule
-- Last Updated: 2026-01-28
-- ============================================================================

WITH Demand_Aggregated AS (
    SELECT
        Item_Number,
        SUM(COALESCE(TRY_CAST(Base_Demand_Qty AS NUMERIC(18, 4)), 0)) AS Total_Demand,
        COUNT(DISTINCT CAST(Due_Date AS DATE)) AS Demand_Days,
        COUNT(DISTINCT Order_Number) AS Order_Count,
        MIN(CAST(Due_Date AS DATE)) AS Earliest_Demand_Date,
        MAX(CAST(Due_Date AS DATE)) AS Latest_Demand_Date
    FROM dbo.ETB2_Demand_Cleaned_Base WITH (NOLOCK)
    WHERE Is_Within_Active_Planning_Window = 1
    GROUP BY Item_Number
)
SELECT
    da.Item_Number,
    ci.Item_Description,
    ci.UOM_Schedule,
    CAST(da.Total_Demand AS NUMERIC(18, 4)) AS Net_Requirement_Qty,
    CAST(0 AS NUMERIC(18, 4)) AS Safety_Stock_Level,
    da.Demand_Days AS Days_Of_Supply,
    da.Order_Count,
    CASE
        WHEN da.Total_Demand = 0 THEN 'NONE'
        WHEN da.Total_Demand <= 100 THEN 'LOW'
        WHEN da.Total_Demand <= 500 THEN 'MEDIUM'
        ELSE 'HIGH'
    END AS Requirement_Priority,
    CASE
        WHEN da.Total_Demand = 0 THEN 'NO_DEMAND'
        WHEN da.Total_Demand <= 100 THEN 'LOW_PRIORITY'
        WHEN da.Total_Demand <= 500 THEN 'MEDIUM_PRIORITY'
        ELSE 'HIGH_PRIORITY'
    END AS Requirement_Status,
    da.Earliest_Demand_Date,
    da.Latest_Demand_Date
FROM Demand_Aggregated da
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON da.Item_Number = ci.Item_Number;

-- ============================================================================
-- END OF VIEW 08
-- ============================================================================
