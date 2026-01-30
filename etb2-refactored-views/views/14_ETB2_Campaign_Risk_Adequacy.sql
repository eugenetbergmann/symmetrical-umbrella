-- ============================================================================
-- VIEW 14: dbo.ETB2_Campaign_Risk_Adequacy (CONSOLIDATED FINAL)
-- ============================================================================
-- Purpose: Inventory adequacy assessment vs collision buffer requirements
-- Grain: One row per campaign per item
-- Dependencies:
--   - dbo.ETB2_Campaign_Collision_Buffer (view 13)
--   - dbo.ETB2_Inventory_Unified (view 07)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct carried from collision buffer
--   - Is_Suppressed flag
-- Last Updated: 2026-01-30
-- ============================================================================

SELECT 
    -- Context columns preserved
    b.client,
    b.contract,
    b.run,
    
    b.Item_Number,
    b.Campaign_ID,
    COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) AS Available_Inventory,
    SUM(b.collision_buffer_qty) AS Required_Buffer,
    CASE 
        WHEN SUM(b.collision_buffer_qty) > 0 
        THEN CAST(COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) AS DECIMAL(10,2)) / SUM(b.collision_buffer_qty)
        ELSE 1.0
    END AS Adequacy_Score,
    CASE 
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) * 0.5 THEN 'HIGH'
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) THEN 'MEDIUM'
        ELSE 'LOW'
    END AS campaign_collision_risk,
    CASE 
        WHEN SUM(b.collision_buffer_qty) > 0 
        THEN CAST(COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) / NULLIF(SUM(b.collision_buffer_qty), 0) * 30 AS INT)
        ELSE 30
    END AS Days_Buffer_Coverage,
    CASE 
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) * 0.5 THEN 'URGENT_PROCUREMENT'
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.Usable_Qty AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) THEN 'SCHEDULE_PROCUREMENT'
        ELSE 'ADEQUATE'
    END AS Recommendation,
    
    -- FG SOURCE (PAB-style): Carried through from collision buffer
    b.FG_Item_Number,
    b.FG_Description,
    -- Construct SOURCE (PAB-style): Carried through from collision buffer
    b.Construct,
    
    -- Suppression flag (combined)
    CAST(MAX(CASE WHEN b.Is_Suppressed = 1 OR COALESCE(i.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END) AS BIT) AS Is_Suppressed
    
FROM dbo.ETB2_Campaign_Collision_Buffer b WITH (NOLOCK)
LEFT JOIN dbo.ETB2_Inventory_Unified i WITH (NOLOCK) 
    ON b.Item_Number = i.Item_Number
    AND b.client = i.client
    AND b.contract = i.contract
    AND b.run = i.run
WHERE b.Item_Number NOT LIKE 'MO-%'
GROUP BY b.client, b.contract, b.run, b.Item_Number, b.Campaign_ID,
         b.FG_Item_Number, b.FG_Description, b.Construct
HAVING CAST(MAX(CASE WHEN b.Is_Suppressed = 1 OR COALESCE(i.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END) AS BIT) = 0;

-- ============================================================================
-- END OF VIEW 14 (CONSOLIDATED FINAL)
-- ============================================================================
