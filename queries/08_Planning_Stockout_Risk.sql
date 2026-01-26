/*******************************************************************************
* View Name:    ETB2_Planning_Stockout_Risk
* Deploy Order: 08 of 17
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      ATP (Available to Promise) balance and stockout risk classification
* Grain:        One row per item
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.ETB2_Demand_Cleaned_Base (view 04 - deploy first)
*   ✓ dbo.ETB2_Inventory_WC_Batches (view 05 - deploy first)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_Planning_Stockout_Risk
* 8. Refresh Views folder
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_Planning_Stockout_Risk
*   Expected: One row per item with demand
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    d.ITEMNMBR,
    SUM(d.Quantity) AS Projected_Demand,
    COALESCE(SUM(i.Quantity), 0) AS Current_Inventory,
    SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) AS ATP,  -- ATP = Demand - Inventory
    CASE 
        -- CRITICAL: Negative ATP (stockout imminent)
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) < 0 THEN 'CRITICAL'
        -- HIGH: ATP < 50% of demand
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) < SUM(d.Quantity) * 0.5 THEN 'HIGH'
        -- MEDIUM: ATP < 100% of demand
        WHEN SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) < SUM(d.Quantity) THEN 'MEDIUM'
        -- LOW: ATP >= demand
        ELSE 'LOW'
    END AS Risk_Classification,
    CASE 
        WHEN SUM(d.Quantity) > 0 
        THEN CAST(COALESCE(SUM(i.Quantity), 0) AS DECIMAL(10,2)) / SUM(d.Quantity)
        ELSE 1.0
    END AS Service_Level_Pct,
    -- Days of supply based on average daily demand
    CASE 
        WHEN SUM(d.Quantity) > 0 
        THEN CAST(COALESCE(SUM(i.Quantity), 0) / (SUM(d.Quantity) / 30) AS INT)
        ELSE 999
    END AS Days_Of_Supply
FROM dbo.ETB2_Demand_Cleaned_Base d
LEFT JOIN dbo.ETB2_Inventory_WC_Batches i ON d.ITEMNMBR = i.ITEMNMBR
GROUP BY d.ITEMNMBR

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Risk distribution:
   SELECT 
       Risk_Classification,
       COUNT(*) AS Items,
       SUM(Projected_Demand) AS Total_Demand
   FROM dbo.ETB2_Planning_Stockout_Risk
   GROUP BY Risk_Classification
   ORDER BY Risk_Classification

2. Critical items check:
   SELECT TOP 10
       ITEMNMBR,
       ATP,
       Risk_Classification,
       Days_Of_Supply
   FROM dbo.ETB2_Planning_Stockout_Risk
   WHERE Risk_Classification = 'CRITICAL'
   ORDER BY ATP ASC

3. Service level summary:
   SELECT 
       AVG(Service_Level_Pct) AS Avg_Service_Level,
       MIN(Service_Level_Pct) AS Min_Service_Level,
       MAX(Service_Level_Pct) AS Max_Service_Level
   FROM dbo.ETB2_Planning_Stockout_Risk
*/
