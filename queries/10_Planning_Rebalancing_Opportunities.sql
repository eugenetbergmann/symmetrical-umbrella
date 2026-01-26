/*******************************************************************************
* View: ETB2_Planning_Rebalancing_Opportunities
* Order: 10 of 17 ⚠️ DEPLOY TENTH
* 
* Dependencies (MUST exist first):
*   ✓ ETB2_Demand_Cleaned_Base (file 04)
*   ✓ ETB2_Inventory_WC_Batches (file 05)
*   ✓ ETB2_Inventory_Quarantine_Restricted (file 06)
*
* External Tables Required:
*   ✓ dbo.ETB_PAB_AUTO
*   ✓ dbo.IV00300
*
* DEPLOYMENT METHOD:
* 1. In SSMS Object Explorer: Right-click Views → New View
* 2. When Query Designer opens with grid: Click Query Designer menu → Pane → SQL
* 3. Delete any default SQL in the pane
* 4. Copy ENTIRE query below (from SELECT to semicolon)
* 5. Paste into SQL pane
* 6. Click Execute (!) to test - should return rows
* 7. If successful, click Save (disk icon)
* 8. Save as: dbo.ETB2_Planning_Rebalancing_Opportunities
*
* Expected Result: Inventory transfer recommendations
*******************************************************************************/

-- Copy from here ↓

SELECT
    i.ITEMNMBR,
    i.LOCNID AS Source_Location,
    d.Demand_Date AS Target_Location,
    CASE 
        WHEN i.Quantity > 100 AND DATEDIFF(DAY, GETDATE(), i.Expiry_Date) < 90 
        THEN i.Quantity * 0.5 
        ELSE 0 
    END AS Transfer_Qty,
    DATEDIFF(DAY, GETDATE(), i.Expiry_Date) AS Days_To_Expiry,
    CASE 
        WHEN i.Quantity > 100 AND DATEDIFF(DAY, GETDATE(), i.Expiry_Date) < 90 
        THEN i.Quantity * 10 
        ELSE 0 
    END AS Savings_Potential
FROM dbo.ETB2_Inventory_WC_Batches i
CROSS JOIN dbo.ETB2_Demand_Cleaned_Base d
WHERE i.ITEMNMBR = d.ITEMNMBR
    AND i.FEFO_Rank > 3;

-- Copy to here ↑
