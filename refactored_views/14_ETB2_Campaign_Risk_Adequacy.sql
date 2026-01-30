-- ============================================================================
-- VIEW 14: dbo.ETB2_Campaign_Risk_Adequacy
-- Deploy Order: 14 of 17 (Deploy AFTER view 17)
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Inventory adequacy assessment vs collision buffer requirements
-- Grain: One row per campaign per item
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_Campaign_Risk_Adequacy
-- ============================================================================

SELECT 
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
    b.Construct
FROM dbo.ETB2_Campaign_Collision_Buffer b WITH (NOLOCK)
LEFT JOIN dbo.ETB2_Inventory_Unified i WITH (NOLOCK) ON b.Item_Number = i.Item_Number
GROUP BY b.Item_Number, b.Campaign_ID, b.FG_Item_Number, b.FG_Description, b.Construct;

-- ============================================================================
-- END OF VIEW 14
-- ============================================================================
