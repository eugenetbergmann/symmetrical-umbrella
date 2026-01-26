/*******************************************************************************
* View: ETB2_PAB_EventLedger_v1
* Order: 17 of 17 ⚠️ DEPLOY BETWEEN FILES 13 AND 14 (NOT LAST!)
* 
* ⚠️ CRITICAL: This file deploys AFTER file 13 but BEFORE file 14!
* 
* Dependencies (MUST exist first):
*   ✓ ETB2_Demand_Cleaned_Base (file 04)
*   ✓ dbo.IV00102 (external table - must exist)
*   ✓ dbo.POP10100 (external table - must exist)
*   ✓ dbo.POP10110 (external table - must exist)
*   ✓ dbo.POP10300 (external table - must exist)
*
* External Tables Required:
*   ✓ dbo.ETB_PAB_AUTO
*   ✓ dbo.IV00102
*   ✓ dbo.POP10100
*   ✓ dbo.POP10110
*   ✓ dbo.POP10300
*
* DEPLOYMENT METHOD:
* 1. In SSMS Object Explorer: Right-click Views → New View
* 2. When Query Designer opens with grid: Click Query Designer menu → Pane → SQL
* 3. Delete any default SQL in the pane
* 4. Copy ENTIRE query below (from SELECT to semicolon)
* 5. Paste into SQL pane
* 6. Click Execute (!) to test - should return rows
* 7. If successful, click Save (disk icon)
* 8. Save as: dbo.ETB2_PAB_EventLedger_v1
*
* Expected Result: Atomic event ledger with all transaction types
*******************************************************************************/

-- Copy from here ↓

SELECT
    NEWID() AS Event_ID,
    'Demand' AS Event_Type,
    ITEMNMBR,
    DUEDAT AS Event_Date,
    QTYORDER AS Quantity,
    'ETB_PAB_AUTO' AS Source_System,
    ORD AS Reference_ID
FROM dbo.ETB_PAB_AUTO
WHERE POSTATUS <> 'CANCELLED'

UNION ALL

SELECT
    NEWID() AS Event_ID,
    'Receipt' AS Event_Type,
    ITEMNMBR,
    TRXDT AS Event_Date,
    TRXQTY AS Quantity,
    'IV00102' AS Source_System,
    DOCNUMBR AS Reference_ID
FROM dbo.IV00102

UNION ALL

SELECT
    NEWID() AS Event_ID,
    'Purchase_Order' AS Event_Type,
    p.ITEMNMBR,
    h.DOCDATE AS Event_Date,
    p.QTYORDER AS Quantity,
    'POP10100' AS Source_System,
    h.PONUMBER AS Reference_ID
FROM dbo.POP10100 h
JOIN dbo.POP10110 p ON h.PONUMBER = p.PONUMBER

UNION ALL

SELECT
    NEWID() AS Event_ID,
    'PO_Receipt' AS Event_Type,
    ITEMNMBR,
    RCVDATE AS Event_Date,
    QTYSHPPD AS Quantity,
    'POP10300' AS Source_System,
    POPRCTNM AS Reference_ID
FROM dbo.POP10300;

-- Copy to here ↑
