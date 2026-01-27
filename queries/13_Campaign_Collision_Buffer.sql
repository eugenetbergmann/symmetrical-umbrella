/*******************************************************************************
* View Name:    ETB2_Campaign_Collision_Buffer
* Deploy Order: 13 of 17
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      Calculate collision buffer requirements based on concurrency
* Grain:        One row per campaign per item with collision risk
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.ETB3_Campaign_Normalized_Demand (view 11 - deploy first)
*   ✓ dbo.ETB2_Campaign_Concurrency_Window (view 12 - deploy first)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_Campaign_Collision_Buffer
* 8. Refresh Views folder
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_Campaign_Collision_Buffer
*   Expected: Campaigns with collision buffer requirements
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    n.Campaign_ID,
    n.ITEMNMBR,
    n.Total_Campaign_Quantity,
    n.CCU,
    -- Collision buffer calculation: 20% of CCU for overlapping campaigns
    COALESCE(SUM(w.Combined_CCU) * 0.20, 0) AS collision_buffer_qty,
    n.Peak_Period_Start,
    n.Peak_Period_End,
    -- Risk level based on buffer size
    CASE 
        WHEN COALESCE(SUM(w.Combined_CCU) * 0.20, 0) > n.CCU * 0.5 THEN 'HIGH'
        WHEN COALESCE(SUM(w.Combined_CCU) * 0.20, 0) > n.CCU * 0.25 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS Collision_Risk_Level,
    COUNT(w.Campaign_B) AS Overlapping_Campaigns
FROM dbo.ETB3_Campaign_Normalized_Demand n
LEFT JOIN dbo.ETB2_Campaign_Concurrency_Window w 
    ON (n.Campaign_ID = w.Campaign_A OR n.Campaign_ID = w.Campaign_B)
    AND n.ITEMNMBR IN (SELECT ITEMNMBR FROM dbo.ETB3_Campaign_Normalized_Demand WHERE Campaign_ID = 
        CASE WHEN n.Campaign_ID = w.Campaign_A THEN w.Campaign_B ELSE w.Campaign_A END)
GROUP BY n.Campaign_ID, n.ITEMNMBR, n.Total_Campaign_Quantity, n.CCU,
         n.Peak_Period_Start, n.Peak_Period_End

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Risk distribution:
   SELECT 
       Collision_Risk_Level,
       COUNT(*) AS Campaigns,
       SUM(collision_buffer_qty) AS Total_Buffer
   FROM dbo.ETB2_Campaign_Collision_Buffer
   GROUP BY Collision_Risk_Level
   ORDER BY Collision_Risk_Level

2. High-risk campaigns:
   SELECT TOP 10
       Campaign_ID,
       ITEMNMBR,
       collision_buffer_qty,
       Collision_Risk_Level
   FROM dbo.ETB2_Campaign_Collision_Buffer
   WHERE Collision_Risk_Level = 'HIGH'
   ORDER BY collision_buffer_qty DESC

3. Buffer coverage check:
   SELECT 
       AVG(collision_buffer_qty) AS Avg_Buffer,
       MIN(collision_buffer_qty) AS Min_Buffer,
       MAX(collision_buffer_qty) AS Max_Buffer
   FROM dbo.ETB2_Campaign_Collision_Buffer
*/
