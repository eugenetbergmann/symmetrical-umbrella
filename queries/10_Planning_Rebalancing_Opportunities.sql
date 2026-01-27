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
 *   ✅ dbo.ETB3_Demand_Cleaned_Base (view 04 - deploy first)
 *   ✅ dbo.ETB2_Inventory_Unified (view 07 - deploy first)
 *
 * ⚠️ DEPLOYMENT METHOD:
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
    CASE 
        WHEN Surplus.Surplus_Qty < Deficit.Deficit_Qty 
        THEN Surplus.Surplus_Qty 
        ELSE Deficit.Deficit_Qty 
    END AS Recommended_Transfer,
    Surplus.Surplus_Qty - Deficit.Deficit_Qty AS Net_Position,
    'TRANSFER' AS Rebalancing_Type,
    GETDATE() AS Identified_Date
FROM (
    SELECT 
        pib.ITEMNMBR,
        pib.LOCNCODE AS Source_WC,
        SUM(pib.Qty_Available) AS Surplus_Qty
    FROM dbo.ETB_INVENTORY_WC pib
    WHERE pib.Qty_Available > 0 
    GROUP BY pib.ITEMNMBR, pib.LOCNCODE
) Surplus
INNER JOIN (
    SELECT 
        d.ITEMNMBR,
        i.LOCNCODE AS Target_WC,
        SUM(d.Base_Demand_Qty) - COALESCE(SUM(i.Qty_Available), 0) AS Deficit_Qty
    FROM dbo.ETB3_Demand_Cleaned_Base d
    LEFT JOIN dbo.ETB2_Inventory_Unified i ON d.ITEMNMBR = i.ITEMNMBR
    WHERE d.Is_Within_Active_Planning_Window = 1
    GROUP BY d.ITEMNMBR, i.LOCNCODE
    HAVING SUM(d.Base_Demand_Qty) - COALESCE(SUM(i.Qty_Available), 0) > 0
) Deficit ON Surplus.ITEMNMBR = Deficit.ITEMNMBR;

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
