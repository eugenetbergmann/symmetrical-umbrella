/*******************************************************************************
* View Name:    ETB2_Inventory_Quarantine_Restricted
* Deploy Order: 06 of 17
* 
* Purpose:      Quarantine (WFQ) and restricted (RMQTY) inventory with hold periods
* Grain:        One row per item per location per restriction type
* 
* Dependencies:
*   ✓ dbo.IV00300 (receipts - external table)
*   ✓ dbo.IV00101 (item master - external table)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_Inventory_Quarantine_Restricted
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_Inventory_Quarantine_Restricted
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
