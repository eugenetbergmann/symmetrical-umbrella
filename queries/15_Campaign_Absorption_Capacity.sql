/*******************************************************************************
* View Name:    ETB2_Campaign_Absorption_Capacity
* Deploy Order: 15 of 17
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      Executive KPI - campaign absorption capacity vs inventory
* Grain:        One row per campaign item (aggregated)
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.ETB2_Campaign_Collision_Buffer (view 13 - deploy first)
*   ✓ dbo.ETB2_Campaign_Risk_Adequacy (view 14 - deploy first)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_Campaign_Absorption_Capacity
* 8. Refresh Views folder
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_Campaign_Absorption_Capacity
*   Expected: One row per campaign
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    r.Campaign_ID,
    SUM(r.Available_Inventory) AS Total_Inventory,
    SUM(r.Required_Buffer) AS Total_Buffer_Required,
    -- Absorption ratio: inventory / buffer (executive KPI)
    CASE 
        WHEN SUM(r.Required_Buffer) > 0 
        THEN CAST(SUM(r.Available_Inventory) AS DECIMAL(10,2)) / SUM(r.Required_Buffer)
        ELSE 1.0
    END AS Absorption_Ratio,
    -- Executive classification
    CASE 
        WHEN SUM(r.Available_Inventory) < SUM(r.Required_Buffer) * 0.5 THEN 'CRITICAL'
        WHEN SUM(r.Available_Inventory) < SUM(r.Required_Buffer) THEN 'AT_RISK'
        WHEN SUM(r.Available_Inventory) < SUM(r.Required_Buffer) * 1.5 THEN 'HEALTHY'
        ELSE 'OVER_STOCKED'
    END AS Campaign_Health,
    COUNT(DISTINCT r.ITEMNMBR) AS Items_In_Campaign,
    AVG(r.Adequacy_Score) AS Avg_Adequacy,
    GETDATE() AS Calculated_Date
FROM dbo.ETB2_Campaign_Risk_Adequacy r
GROUP BY r.Campaign_ID

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Health distribution:
   SELECT 
       Campaign_Health,
       COUNT(*) AS Campaigns,
       AVG(Absorption_Ratio) AS Avg_Absorption
   FROM dbo.ETB2_Campaign_Absorption_Capacity
   GROUP BY Campaign_Health
   ORDER BY Campaign_Health

2. Critical campaigns:
   SELECT 
       Campaign_ID,
       Total_Inventory,
       Total_Buffer_Required,
       Absorption_Ratio
   FROM dbo.ETB2_Campaign_Absorption_Capacity
   WHERE Campaign_Health = 'CRITICAL'
   ORDER BY Absorption_Ratio ASC

3. Executive summary:
   SELECT 
       AVG(Absorption_Ratio) AS Global_Absorption_Ratio,
       MIN(Absorption_Ratio) AS Min_Ratio,
       MAX(Absorption_Ratio) AS Max_Ratio
   FROM dbo.ETB2_Campaign_Absorption_Capacity
*/
