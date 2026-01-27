/*******************************************************************************
* View Name:    ETB2_Campaign_Normalized_Demand
* Deploy Order: 11 of 17
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      Campaign Consumption Units (CCU) - normalized demand per campaign
* Grain:        One row per campaign per item
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.ETB3_Demand_Cleaned_Base (view 04 - deploy first)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_Campaign_Normalized_Demand
* 8. Refresh Views folder
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_Campaign_Normalized_Demand
*   Expected: One row per campaign per item with demand
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    d.Campaign_ID,
    d.ITEMNMBR,
    SUM(d.Quantity) AS Total_Campaign_Quantity,
    SUM(d.Quantity) / 30.0 AS CCU,  -- Campaign Consumption Unit: daily average
    'DAILY' AS CCU_Unit,
    MIN(d.Demand_Date) AS Peak_Period_Start,
    MAX(d.Demand_Date) AS Peak_Period_End,
    DATEDIFF(DAY, MIN(d.Demand_Date), MAX(d.Demand_Date)) AS Campaign_Duration_Days,
    COUNT(DISTINCT d.Demand_Date) AS Active_Days_Count
FROM dbo.ETB3_Demand_Cleaned_Base d
WHERE d.Campaign_ID IS NOT NULL
    AND d.Campaign_ID <> 'UNKNOWN'
GROUP BY d.Campaign_ID, d.ITEMNMBR

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Campaign summary:
   SELECT 
       COUNT(*) AS Campaign_Item_Count,
       COUNT(DISTINCT Campaign_ID) AS Unique_Campaigns
   FROM dbo.ETB2_Campaign_Normalized_Demand

2. Top campaigns by volume:
   SELECT TOP 10
       Campaign_ID,
       SUM(Total_Campaign_Quantity) AS Total_Qty,
       AVG(CCU) AS Avg_CCU
   FROM dbo.ETB2_Campaign_Normalized_Demand
   GROUP BY Campaign_ID
   ORDER BY Total_Qty DESC

3. CCU distribution:
   SELECT 
       MIN(CCU) AS Min_CCU,
       AVG(CCU) AS Avg_CCU,
       MAX(CCU) AS Max_CCU
   FROM dbo.ETB2_Campaign_Normalized_Demand
*/
