/*******************************************************************************
* View Name:    ETB2_Planning_Rebalancing_Opportunities
* Deploy Order: 10 of 17
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      Identify inventory rebalancing opportunities between work centers
* Grain:        One row per item per surplus/deficit location pair
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.ETB2_Demand_Cleaned_Base (view 04 - deploy first)
*   ✓ dbo.ETB2_Inventory_WC_Batches (view 05 - deploy first)
*   ✓ dbo.ETB2_Inventory_Quarantine_Restricted (view 06 - deploy first)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_Planning_Rebalancing_Opportunities
* 8. Refresh Views folder
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_Planning_Rebalancing_Opportunities
*   Expected: Transfer recommendations
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    Surplus.ITEMNMBR,
    Surplus.Source_WC AS From_Work_Center,
    Surplus.Surplus_Qty,
    Deficit.Target_WC AS To_Work_Center,
    Deficit.Deficit_Qty,
    -- Transfer quantity limited by smaller of surplus/deficit
    CASE 
        WHEN Surplus.Surplus_Qty < Deficit.Deficit_Qty 
        THEN Surplus.Surplus_Qty 
        ELSE Deficit.Deficit_Qty 
    END AS Recommended_Transfer,
    Surplus.Surplus_Qty - Deficit.Deficit_Qty AS Net_Position,
    'TRANSFER' AS Rebalancing_Type,
    GETDATE() AS Identified_Date
FROM (
    -- Identify surplus locations
    SELECT 
        ITEMNMBR,
        LOCNID AS Source_WC,
        SUM(QTY) AS Surplus_Qty
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE
    WHERE QTY > 0 AND LOCNCODE LIKE 'WC[_-]%'
    GROUP BY ITEMNMBR, LOCNID
) Surplus
INNER JOIN (
    -- Identify deficit locations (based on demand)
    SELECT 
        d.ITEMNMBR,
        i.LOCNID AS Target_WC,
        SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) AS Deficit_Qty
    FROM dbo.ETB2_Demand_Cleaned_Base d
    LEFT JOIN dbo.ETB2_Inventory_WC_Batches i ON d.ITEMNMBR = i.ITEMNMBR
    GROUP BY d.ITEMNMBR, i.LOCNID
    HAVING SUM(d.Quantity) - COALESCE(SUM(i.Quantity), 0) > 0
) Deficit ON Surplus.ITEMNMBR = Deficit.ITEMNMBR

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Transfer summary:
   SELECT COUNT(*) AS Transfer_Opportunities FROM dbo.ETB2_Planning_Rebalancing_Opportunities

2. Top transfer volumes:
   SELECT TOP 10
       ITEMNMBR,
       From_Work_Center,
       To_Work_Center,
       Recommended_Transfer
   FROM dbo.ETB2_Planning_Rebalancing_Opportunities
   ORDER BY Recommended_Transfer DESC

3. Total rebalancing impact:
   SELECT 
       SUM(Recommended_Transfer) AS Total_Transfer_Qty,
       COUNT(DISTINCT ITEMNMBR) AS Items_To_Transfer
   FROM dbo.ETB2_Planning_Rebalancing_Opportunities
*/
