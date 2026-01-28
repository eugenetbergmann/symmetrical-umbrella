/*******************************************************************************
 * View Name:    ETB2_Campaign_Risk_Adequacy
 * Deploy Order: 14 of 17 ⚠️ DEPLOY AFTER FILE 17 (EventLedger)
 * Status:       🔴 NOT YET DEPLOYED
 * 
 * Purpose:      Inventory adequacy assessment vs collision buffer requirements
 * Grain:        One row per campaign per item
 * 
 * Dependencies (MUST exist - verify first):
 *   ✅ ETB2_Config_Lead_Times (deployed)
 *   ✅ ETB2_Config_Part_Pooling (deployed)
 *   ✅ ETB2_Config_Active (deployed)
 *   ✅ dbo.ETB2_Inventory_Unified (view 07 - deploy first)
 *   ✅ dbo.ETB2_PAB_EventLedger_v1 (view 17 - MUST BE DEPLOYED FIRST)
 *   ✅ dbo.ETB2_Demand_Cleaned_Base (view 04 - deploy first)
 *   ✅ dbo.ETB2_Campaign_Collision_Buffer (view 13 - deploy first)
 *
 * ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
 * 1. Object Explorer → Right-click "Views" → "New View..."
 * 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
 * 3. Delete default SQL
 * 4. Copy SELECT below (between markers)
 * 5. Paste into SQL pane
 * 6. Execute (!) to test
 * 7. Save as: dbo.ETB2_Campaign_Risk_Adequacy
 * 8. Refresh Views folder
 *
 * Validation: 
 *   SELECT COUNT(*) FROM dbo.ETB2_Campaign_Risk_Adequacy
 *   Expected: One row per campaign per item with adequacy assessment
 *******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    b.ITEMNMBR,
    b.Campaign_ID,
    COALESCE(SUM(COALESCE(TRY_CAST(i.QTY AS DECIMAL(18,4)), 0)), 0) AS Available_Inventory,
    SUM(b.collision_buffer_qty) AS Required_Buffer,
    CASE 
        WHEN SUM(b.collision_buffer_qty) > 0 
        THEN CAST(COALESCE(SUM(COALESCE(TRY_CAST(i.QTY AS DECIMAL(18,4)), 0)), 0) AS DECIMAL(10,2)) / SUM(b.collision_buffer_qty)
        ELSE 1.0
    END AS Adequacy_Score,
    CASE 
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.QTY AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) * 0.5 THEN 'HIGH'
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.QTY AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) THEN 'MEDIUM'
        ELSE 'LOW'
    END AS campaign_collision_risk,
    CASE 
        WHEN SUM(b.collision_buffer_qty) > 0 
        THEN CAST(COALESCE(SUM(COALESCE(TRY_CAST(i.QTY AS DECIMAL(18,4)), 0)), 0) / NULLIF(SUM(b.collision_buffer_qty), 0) * 30 AS INT)
        ELSE 30
    END AS Days_Buffer_Coverage,
    CASE 
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.QTY AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) * 0.5 THEN 'URGENT_PROCUREMENT'
        WHEN COALESCE(SUM(COALESCE(TRY_CAST(i.QTY AS DECIMAL(18,4)), 0)), 0) < SUM(b.collision_buffer_qty) THEN 'SCHEDULE_PROCUREMENT'
        ELSE 'ADEQUATE'
    END AS Recommendation
FROM dbo.ETB2_Campaign_Collision_Buffer b WITH (NOLOCK)
LEFT JOIN dbo.ETB2_Inventory_Unified i WITH (NOLOCK) ON b.ITEMNMBR = i.ITEMNMBR
GROUP BY b.ITEMNMBR, b.Campaign_ID;

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Adequacy summary:
   SELECT 
       campaign_collision_risk,
       COUNT(*) AS Campaigns,
       AVG(Adequacy_Score) AS Avg_Adequacy
   FROM dbo.ETB2_Campaign_Risk_Adequacy
   GROUP BY campaign_collision_risk
   ORDER BY campaign_collision_risk;

2. Urgent items:
   SELECT TOP 10
       Campaign_ID,
       ITEMNMBR,
       Available_Inventory,
       Required_Buffer,
       Recommendation
   FROM dbo.ETB2_Campaign_Risk_Adequacy
   WHERE Recommendation = 'URGENT_PROCUREMENT'
   ORDER BY (Available_Inventory - Required_Buffer) ASC;

3. Adequacy score distribution:
   SELECT 
       MIN(Adequacy_Score) AS Min_Score,
       AVG(Adequacy_Score) AS Avg_Score,
       MAX(Adequacy_Score) AS Max_Score
   FROM dbo.ETB2_Campaign_Risk_Adequacy;
*/
