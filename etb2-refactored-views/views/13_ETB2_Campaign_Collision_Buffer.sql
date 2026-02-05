/* VIEW 13 - STATUS: VALIDATED */
-- ============================================================================
-- VIEW 13: dbo.ETB2_Campaign_Collision_Buffer (CONSOLIDATED FINAL)
-- ============================================================================
-- Purpose: Calculate collision buffer requirements based on concurrency
-- Grain: One row per campaign per item with collision risk
-- Dependencies:
--   - dbo.ETB2_Campaign_Normalized_Demand (view 11)
--   - dbo.ETB2_Campaign_Concurrency_Window (view 12)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct carried from normalized demand (view 11)
--   - Is_Suppressed flag
-- Last Updated: 2026-02-05
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
    
    -- FG SOURCE (PAB-style): Carried through from normalized demand (view 11)
    n.FG_Item_Number,
    n.FG_Description,
    -- Construct SOURCE (PAB-style): Carried through from normalized demand (view 11)
    n.Construct,
    
    -- Suppression flag (combined)
    CAST(MAX(CASE WHEN n.Is_Suppressed = 1 OR COALESCE(w.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END) AS BIT) AS Is_Suppressed
    
FROM dbo.ETB2_Campaign_Normalized_Demand n WITH (NOLOCK)
LEFT JOIN dbo.ETB2_Campaign_Concurrency_Window w WITH (NOLOCK) 
    ON (n.Campaign_ID = w.Campaign_A OR n.Campaign_ID = w.Campaign_B)
    AND n.Item_Number = w.Item_Number
    AND n.client = w.client
    AND n.contract = w.contract
    AND n.run = w.run
WHERE n.Item_Number NOT LIKE 'MO-%'
GROUP BY n.client, n.contract, n.run, n.Campaign_ID, n.Item_Number, n.Total_Campaign_Quantity, n.CCU,
         n.Peak_Period_Start, n.Peak_Period_End,
         n.FG_Item_Number, n.FG_Description, n.Construct
HAVING CAST(MAX(CASE WHEN n.Is_Suppressed = 1 OR COALESCE(w.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END) AS BIT) = 0;

-- ============================================================================
-- END OF VIEW 13 (CONSOLIDATED FINAL)
-- ============================================================================
