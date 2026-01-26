/*******************************************************************************
* View Name:    ETB2_Inventory_Quarantine_Restricted
* Deploy Order: 06 of 17
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      Quarantine (WFQ) and restricted (RMQTY) inventory with hold periods
* Grain:        One row per item per location per restriction type
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.IV00300 (receipts - external table)
*   ✓ dbo.IV00101 (item master - external table)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_Inventory_Quarantine_Restricted
* 8. Refresh Views folder
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_Inventory_Quarantine_Restricted
*   Expected: Rows matching restricted/quarantine inventory
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

SELECT 
    i.ITEMNMBR,
    i.LOCNID AS Location,
    (i.QTYOH - i.QTYCOMTD) AS Available_Qty,  -- Available = on hand - committed
    CASE 
        WHEN i.QTYRCTD > i.QTYSOLD THEN 'WFQ'   -- Wait for Quality: receipts > sales
        ELSE 'RMQTY'                              -- Restricted Material Quality
    END AS Restriction_Type,
    -- Hold periods: WFQ = 14 days, RMQTY = 7 days
    DATEADD(DAY, 
        CASE WHEN i.QTYRCTD > i.QTYSOLD THEN 14 ELSE 7 END,
        GETDATE()
    ) AS Hold_Until,
    'Quality Review' AS Reason_Code,
    i.RCTRXNUM AS Receipt_Reference,
    GETDATE() AS Assessed_Date
FROM dbo.IV00300 i
WHERE (i.QTYOH - i.QTYCOMTD) > 0  -- Only positive available quantities
    AND i.IV00300.IVDOCTYP = 1    -- Receipt documents only

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Row count check:
   SELECT COUNT(*) FROM dbo.ETB2_Inventory_Quarantine_Restricted
   -- Should show restricted inventory items

2. Restriction type distribution:
   SELECT 
       Restriction_Type,
       COUNT(*) AS Items,
       SUM(Available_Qty) AS Total_Qty
   FROM dbo.ETB2_Inventory_Quarantine_Restricted
   GROUP BY Restriction_Type

3. Hold period check:
   SELECT TOP 10
       ITEMNMBR,
       Restriction_Type,
       Hold_Until,
       Available_Qty
   FROM dbo.ETB2_Inventory_Quarantine_Restricted
   ORDER BY Hold_Until ASC
   -- Items releasing soonest first
*/
