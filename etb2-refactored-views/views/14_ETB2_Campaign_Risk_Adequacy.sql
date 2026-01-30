-- ============================================================================
-- VIEW 14: dbo.ETB2_Campaign_Risk_Adequacy (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Inventory adequacy assessment vs collision buffer requirements
-- Grain: One row per campaign per item
-- Dependencies:
--   - dbo.ETB2_Campaign_Collision_Buffer (view 13)
--   - dbo.ETB2_Inventory_Unified (view 07)
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
    b.client,
    b.contract,
    b.run,
    
    b.item_number,
    b.customer_number,
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
    
    -- Suppression flag (combined)
    CAST(MAX(CASE WHEN b.Is_Suppressed = 1 OR COALESCE(i.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END) AS BIT) AS Is_Suppressed
    
FROM dbo.ETB2_Campaign_Collision_Buffer b WITH (NOLOCK)
LEFT JOIN dbo.ETB2_Inventory_Unified i WITH (NOLOCK) 
    ON b.item_number = i.item_number
    AND b.customer_number = i.customer_number
    AND b.client = i.client
    AND b.contract = i.contract
    AND b.run = i.run
WHERE b.item_number NOT LIKE 'MO-%'  -- Filter out MO- conflated items
GROUP BY b.client, b.contract, b.run, b.item_number, b.customer_number, b.Campaign_ID
HAVING MAX(CASE WHEN b.Is_Suppressed = 1 OR COALESCE(i.Is_Suppressed, 0) = 1 THEN 1 ELSE 0 END) = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 14 (REFACTORED)
-- ============================================================================