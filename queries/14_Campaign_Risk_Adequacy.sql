/*******************************************************************************
* View Name:    ETB2_Campaign_Risk_Adequacy
* Deploy Order: 14 of 17 ⚠️ DEPLOY AFTER FILE 17 (EventLedger)
* 
* Purpose:      Inventory adequacy assessment vs collision buffer requirements
* Grain:        One row per campaign per item
* 
* Dependencies:
*   ✓ dbo.ETB2_Inventory_Unified_Eligible (view 07)
*   ✓ dbo.ETB2_PAB_EventLedger_v1 (view 17 - MUST BE DEPLOYED FIRST)
*   ✓ dbo.ETB2_Demand_Cleaned_Base (view 04)
*   ✓ dbo.ETB2_Campaign_Collision_Buffer (view 13)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Campaign_Risk_Adequacy
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Campaign_Risk_Adequacy
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    b.ITEMNMBR,
    b.Campaign_ID,
    COALESCE(SUM(i.Available_Qty), 0) AS Available_Inventory,
    SUM(b.collision_buffer_qty) AS Required_Buffer,
    -- Adequacy score: available / required (higher is better)
    CASE 
        WHEN SUM(b.collision_buffer_qty) > 0 
        THEN CAST(COALESCE(SUM(i.Available_Qty), 0) AS DECIMAL(10,2)) / SUM(b.collision_buffer_qty)
        ELSE 1.0
    END AS Adequacy_Score,
    -- Risk classification based on adequacy
    CASE 
        WHEN COALESCE(SUM(i.Available_Qty), 0) < SUM(b.collision_buffer_qty) * 0.5 THEN 'HIGH'
        WHEN COALESCE(SUM(i.Available_Qty), 0) < SUM(b.collision_buffer_qty) THEN 'MEDIUM'
        ELSE 'LOW'
    END AS campaign_collision_risk,
    -- Days of buffer coverage
    CASE 
        WHEN SUM(b.collision_buffer_qty) > 0 
        THEN CAST(COALESCE(SUM(i.Available_Qty), 0) / SUM(b.collision_buffer_qty) * 30 AS INT)
        ELSE 30
    END AS Days_Buffer_Coverage,
    -- Recommendation
    CASE 
        WHEN COALESCE(SUM(i.Available_Qty), 0) < SUM(b.collision_buffer_qty) * 0.5 THEN 'URGENT_PROCUREMENT'
        WHEN COALESCE(SUM(i.Available_Qty), 0) < SUM(b.collision_buffer_qty) THEN 'SCHEDULE_PROCUREMENT'
        ELSE 'ADEQUATE'
    END AS Recommendation
FROM dbo.ETB2_Campaign_Collision_Buffer b
LEFT JOIN dbo.ETB2_Inventory_Unified_Eligible i ON b.ITEMNMBR = i.ITEMNMBR
GROUP BY b.ITEMNMBR, b.Campaign_ID

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
