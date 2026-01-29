-- ============================================================================
-- VIEW 09: dbo.ETB2_Planning_Stockout (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: ATP balance and shortage risk analysis
-- Grain: Item
-- Dependencies:
--   - dbo.ETB2_Planning_Net_Requirements (view 08)
--   - dbo.ETB2_Inventory_Unified (view 07)
--   - dbo.ETB2_Config_Items (view 02B) - for Item_Description, UOM_Schedule
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all GROUP BY clauses
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window: ±90 days
--   - Context preserved in subqueries
-- Last Updated: 2026-01-29
-- ============================================================================

WITH
-- Net requirements from demand
NetRequirements AS (
    SELECT
        -- Context columns preserved
        client,
        contract,
        run,
        
        Item_Number,
        Net_Requirement_Qty,
        Order_Count,
        Requirement_Priority,
        Requirement_Status,
        Earliest_Demand_Date,
        Latest_Demand_Date,
        Is_Suppressed
    FROM dbo.ETB2_Planning_Net_Requirements WITH (NOLOCK)
    WHERE Net_Requirement_Qty > 0
),

-- Available inventory (all eligible)
AvailableInventory AS (
    SELECT
        -- Context columns preserved
        client,
        contract,
        run,
        
        Item_Number,
        SUM(Usable_Qty) AS Total_Available,
        MAX(CASE WHEN Is_Suppressed = 1 THEN 1 ELSE 0 END) AS Has_Suppressed
    FROM dbo.ETB2_Inventory_Unified WITH (NOLOCK)
    WHERE Item_Number NOT LIKE 'MO-%'  -- Filter out MO- conflated items
    GROUP BY client, contract, run, Item_Number
)

-- ============================================================
-- FINAL OUTPUT: 16 columns, planner-optimized order
-- ============================================================
SELECT
    -- Context columns preserved
    COALESCE(nr.client, ai.client, 'DEFAULT_CLIENT') AS client,
    COALESCE(nr.contract, ai.contract, 'DEFAULT_CONTRACT') AS contract,
    COALESCE(nr.run, ai.run, 'CURRENT_RUN') AS run,
    
    -- IDENTIFY (what item?) - 4 columns
    COALESCE(nr.Item_Number, ai.Item_Number) AS Item_Number,
    ci.Item_Description,
    ci.UOM_Schedule AS Unit_Of_Measure_Schedule,
    
    -- QUANTIFY (the math) - 4 columns
    COALESCE(nr.Net_Requirement_Qty, 0) AS Net_Requirement,
    COALESCE(ai.Total_Available, 0) AS Total_Available,
    COALESCE(ai.Total_Available, 0) - COALESCE(nr.Net_Requirement_Qty, 0) AS ATP_Balance,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0)
        THEN COALESCE(nr.Net_Requirement_Qty, 0) - COALESCE(ai.Total_Available, 0)
        ELSE 0
    END AS Shortage_Quantity,

    -- DECIDE (risk assessment) - 5 columns
    CASE
        WHEN COALESCE(ai.Total_Available, 0) = 0 THEN 'CRITICAL'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) * 0.5 THEN 'HIGH'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Risk_Level,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) > 0 AND COALESCE(nr.Net_Requirement_Qty, 0) > 0
        THEN CAST(COALESCE(ai.Total_Available, 0) / NULLIF(COALESCE(nr.Net_Requirement_Qty, 0), 0) AS decimal(10,2))
        ELSE 999.99
    END AS Coverage_Ratio,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) = 0 THEN 1
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) * 0.5 THEN 2
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) THEN 3
        ELSE 4
    END AS Priority,
    CASE
        WHEN COALESCE(ai.Total_Available, 0) = 0 THEN 'URGENT: No inventory'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) * 0.5 THEN 'EXPEDITE: Low coverage'
        WHEN COALESCE(ai.Total_Available, 0) < COALESCE(nr.Net_Requirement_Qty, 0) THEN 'MONITOR: Partial coverage'
        ELSE 'OK: Adequate coverage'
    END AS Recommendation,
    nr.Requirement_Priority,
    nr.Requirement_Status,
    
    -- Suppression flag
    CAST(CASE 
        WHEN COALESCE(nr.Is_Suppressed, 0) = 1 OR COALESCE(ai.Has_Suppressed, 0) = 1 OR COALESCE(ci.Is_Suppressed, 0) = 1 
        THEN 1 ELSE 0 
    END AS BIT) AS Is_Suppressed

FROM NetRequirements nr
FULL OUTER JOIN AvailableInventory ai
    ON nr.Item_Number = ai.Item_Number
    AND nr.client = ai.client
    AND nr.contract = ai.contract
    AND nr.run = ai.run
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON COALESCE(nr.Item_Number, ai.Item_Number) = ci.Item_Number
    AND COALESCE(nr.client, ai.client, 'DEFAULT_CLIENT') = ci.client
    AND COALESCE(nr.contract, ai.contract, 'DEFAULT_CONTRACT') = ci.contract
    AND COALESCE(nr.run, ai.run, 'CURRENT_RUN') = ci.run

WHERE COALESCE(nr.Item_Number, ai.Item_Number) NOT LIKE 'MO-%'  -- Filter out MO- conflated items
  AND (COALESCE(nr.Net_Requirement_Qty, 0) > 0 OR COALESCE(ai.Total_Available, 0) > 0)
  AND CAST(CASE 
        WHEN COALESCE(nr.Is_Suppressed, 0) = 1 OR COALESCE(ai.Has_Suppressed, 0) = 1 OR COALESCE(ci.Is_Suppressed, 0) = 1 
        THEN 1 ELSE 0 
    END AS BIT) = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 09 (REFACTORED)
-- ============================================================================