-- ============================================================================
-- VIEW 08: dbo.ETB2_Planning_Net_Requirements (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Net requirements calculation from demand within planning window
-- Grain: Item
-- Dependencies:
--   - dbo.ETB2_Demand_Cleaned_Base (view 04)
--   - dbo.ETB2_Config_Items (view 02B) - for Item_Description, UOM_Schedule
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all GROUP BY clauses
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window expanded to ±90 days
--   - Context preserved in subqueries
-- Last Updated: 2026-01-29
-- ============================================================================

WITH Demand_Aggregated AS (
    SELECT
        -- Context columns preserved
        client,
        contract,
        run,
        
        item_number,
        customer_number,
        SUM(COALESCE(TRY_CAST(Base_Demand_Qty AS NUMERIC(18, 4)), 0)) AS Total_Demand,
        COUNT(DISTINCT CAST(Due_Date AS DATE)) AS Demand_Days,
        COUNT(DISTINCT Order_Number) AS Order_Count,
        MIN(CAST(Due_Date AS DATE)) AS Earliest_Demand_Date,
        MAX(CAST(Due_Date AS DATE)) AS Latest_Demand_Date,
        
        -- Suppression flag (aggregate - if any suppressed, mark all)
        MAX(CASE WHEN Is_Suppressed = 1 THEN 1 ELSE 0 END) AS Has_Suppressed
        
    FROM dbo.ETB2_Demand_Cleaned_Base WITH (NOLOCK)
    WHERE Is_Within_Active_Planning_Window = 1
      AND item_number NOT LIKE 'MO-%'  -- Filter out MO- conflated items
    GROUP BY client, contract, run, item_number, customer_number
)
SELECT
    -- Context columns preserved
    da.client,
    da.contract,
    da.run,
    
    da.item_number,
    da.customer_number,
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
    da.Latest_Demand_Date,
    
    -- Suppression flag
    CAST(CASE WHEN da.Has_Suppressed = 1 OR COALESCE(ci.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END AS BIT) AS Is_Suppressed
    
FROM Demand_Aggregated da
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON da.item_number = ci.item_number
    AND da.client = ci.client
    AND da.contract = ci.contract
    AND da.run = ci.run
WHERE da.item_number NOT LIKE 'MO-%'  -- Filter out MO- conflated items
  AND CAST(CASE WHEN da.Has_Suppressed = 1 OR COALESCE(ci.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END AS BIT) = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 08 (REFACTORED)
-- ============================================================================