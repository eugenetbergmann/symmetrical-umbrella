-- ============================================================================
-- VIEW 13: dbo.ETB2_Campaign_Collision_Buffer (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Calculate collision buffer requirements based on concurrency
-- Grain: One row per campaign per item with collision risk
-- Dependencies:
--   - dbo.ETB2_Campaign_Normalized_Demand (view 11)
--   - dbo.ETB2_Campaign_Concurrency_Window (view 12)
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all GROUP BY clauses
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Context preserved in subqueries
-- Last Updated: 2026-01-29
-- ============================================================================

SELECT 
    -- Context columns preserved
    n.client,
    n.contract,
    n.run,
    
    n.Campaign_ID,
    n.Item_Number,
    n.Total_Campaign_Quantity,
    n.CCU,
    COALESCE(SUM(w.Combined_CCU) * 0.20, 0) AS collision_buffer_qty,
    n.Peak_Period_Start,
    n.Peak_Period_End,
    CASE 
        WHEN COALESCE(SUM(w.Combined_CCU) * 0.20, 0) > n.CCU * 0.5 THEN 'HIGH'
        WHEN COALESCE(SUM(w.Combined_CCU) * 0.20, 0) > n.CCU * 0.25 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Collision_Risk_Level,
    COUNT(w.Campaign_B) AS Overlapping_Campaigns,
    
    -- Suppression flag (combined)
    CAST(MAX(CASE WHEN n.Is_Suppressed = 1 OR COALESCE(w.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END) AS BIT) AS Is_Suppressed
    
FROM dbo.ETB2_Campaign_Normalized_Demand n WITH (NOLOCK)
LEFT JOIN dbo.ETB2_Campaign_Concurrency_Window w WITH (NOLOCK) 
    ON (n.Campaign_ID = w.Campaign_A OR n.Campaign_ID = w.Campaign_B)
    AND n.Item_Number = w.Item_Number
    AND n.client = w.client
    AND n.contract = w.contract
    AND n.run = w.run
WHERE n.Item_Number NOT LIKE 'MO-%'  -- Filter out MO- conflated items
GROUP BY n.client, n.contract, n.run, n.Campaign_ID, n.Item_Number, n.Total_Campaign_Quantity, n.CCU,
         n.Peak_Period_Start, n.Peak_Period_End
HAVING MAX(CASE WHEN n.Is_Suppressed = 1 OR COALESCE(w.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END) = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 13 (REFACTORED)
-- ============================================================================