/*******************************************************************************
* View Name:    ETB2_PAB_EventLedger_v1
* Deploy Order: 17 of 17 ⚠️ DEPLOY BETWEEN FILES 13 AND 14 (NOT LAST!)
* 
* ⚠️⚠️⚠️ CRITICAL DEPLOYMENT ORDER ⚠️⚠️⚠️
* 
*   Deploy this AFTER file 13 (Campaign_Collision_Buffer)
*   Deploy this BEFORE file 14 (Campaign_Risk_Adequacy)
*   
*   Correct order: 01 → 02 → ... → 13 → 17 → 14 → 15 → 16
*   Wrong order: 01 → 02 → ... → 13 → 14 → 17 → 15 → 16 (WILL FAIL!)
* 
* Purpose:      Atomic event ledger for supply chain audit trail
* Grain:        One row per event (BEGIN_BAL, PO, DEMAND, EXPIRY, RECEIPT)
* 
* Dependencies:
*   ✓ dbo.ETB2_Demand_Cleaned_Base (view 04)
*   ✓ dbo.IV00102 (transaction history - external table)
*   ✓ dbo.POP10100 (PO header - external table)
*   ✓ dbo.POP10110 (PO lines - external table)
*   ✓ dbo.POP10300 (PO receipts - external table)
*
* DEPLOYMENT:
* 1. SSMS Object Explorer → Right-click "Views" → "New View..."
* 2. Query Designer menu → "Pane" → "SQL" (show SQL pane only)
* 3. Copy SELECT statement below (between markers)
* 4. Paste into SQL pane
* 5. Execute (!) to test
* 6. Save as: dbo.ETB2_PAB_EventLedger_v1
*
* Validation: SELECT COUNT(*) FROM dbo.ETB2_PAB_EventLedger_v1
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

-- Event Type 1: BEGIN_BAL (initial balance - placeholder for period start)
SELECT 
    NEWID() AS Event_ID,
    'BEGIN_BAL' AS Event_Type,
    ITEMNMBR,
    GETDATE() AS Event_Date,
    0 AS Quantity,  -- Placeholder: actual beginning balance would come from period close
    'SYSTEM' AS Source_System,
    'PERIOD_OPEN' AS Reference_ID
FROM dbo.ETB2_Demand_Cleaned_Base
WHERE ROWNUM = 1  -- Single placeholder row

UNION ALL

-- Event Type 2: DEMAND (from cleaned demand base)
SELECT 
    NEWID() AS Event_ID,
    'DEMAND' AS Event_Type,
    ITEMNMBR,
    Demand_Date AS Event_Date,
    Quantity,
    'ETB_PAB_AUTO' AS Source_System,
    'DEMAND_' + CAST(ROW_NUMBER() OVER (ORDER BY ITEMNMBR, Demand_Date) AS VARCHAR) AS Reference_ID
FROM dbo.ETB2_Demand_Cleaned_Base

UNION ALL

-- Event Type 3: PO_COMMITMENT (purchase order commitments)
SELECT 
    NEWID() AS Event_ID,
    'PO_COMMITMENT' AS Event_Type,
    p.ITEMNMBR,
    h.DOCDATE AS Event_Date,
    p.QTYORDER AS Quantity,
    'POP10100' AS Source_System,
    h.PONUMBER AS Reference_ID
FROM dbo.POP10100 h
INNER JOIN dbo.POP10110 p ON h.PONUMBER = p.PONUMBER
WHERE h.POSTATUS = 1  -- Approved POs only

UNION ALL

-- Event Type 4: PO_RECEIPT (goods received)
SELECT 
    NEWID() AS Event_ID,
    'PO_RECEIPT' AS Event_Type,
    ITEMNMBR,
    RCVDATE AS Event_Date,
    QTYSHPPD AS Quantity,
    'POP10300' AS Source_System,
    POPRCTNM AS Reference_ID
FROM dbo.POP10300
WHERE POSTATUS = 1  -- Received items only

UNION ALL

-- Event Type 5: INVENTORY_TRANSACTION (from IV00102)
SELECT 
    NEWID() AS Event_ID,
    'INVENTORY_TXN' AS Event_Type,
    ITEMNMBR,
    TRXDT AS Event_Date,
    TRXQTY AS Quantity,
    'IV00102' AS Source_System,
    DOCNUMBR AS Reference_ID
FROM dbo.IV00102
WHERE TRXDT >= DATEADD(DAY, -90, GETDATE())  -- Last 90 days only

-- ============================================================================
-- COPY TO HERE
-- ============================================================================
