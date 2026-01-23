/*
================================================================================
Test Suite: dbo.ETB2_PAB_EventLedger_v1 Validation
Description: Comprehensive validation of atomic event ledger view
Version: 1.0.0
Last Modified: 2026-01-23

Purpose:
   - Verify view creation and basic structure
   - Validate event type distribution and quantities
   - Check running balance calculations
   - Confirm 60.x and 70.x items are INCLUDED
   - Verify PO commitment and receipt separation
   - Validate MO de-duplication logic
   - Check expiry event handling

================================================================================
*/

-- ============================================================
-- TEST 1: Verify view creation and basic structure
-- ============================================================
PRINT '=== TEST 1: View Structure Validation ===';
SELECT TOP 20 
  ORDERNUMBER,
  ITEMNMBR,
  ItemDescription,
  Site,
  DUEDATE,
  STSDESCR,
  SortPriority,
  EventType,
  BEG_BAL,
  Deductions,
  Expiry,
  [PO's],
  UOMSCHDL,
  Running_Balance,
  EventSeq
FROM dbo.ETB2_PAB_EventLedger_v1 
ORDER BY ITEMNMBR, DUEDATE;

-- ============================================================
-- TEST 2: Event type distribution and quantities
-- ============================================================
PRINT '=== TEST 2: Event Type Distribution ===';
SELECT 
  EventType, 
  COUNT(*) AS EventCount, 
  SUM(BEG_BAL) AS Total_BEG_BAL,
  SUM([PO's]) AS Total_POs,
  SUM(Deductions) AS Total_Deductions,
  SUM(Expiry) AS Total_Expiry,
  SUM(BEG_BAL + Deductions + Expiry + [PO's]) AS NetQty
FROM dbo.ETB2_PAB_EventLedger_v1
GROUP BY EventType
ORDER BY EventType;

-- ============================================================
-- TEST 3: Verify 60.x and 70.x items are INCLUDED
-- ============================================================
PRINT '=== TEST 3: 60.x and 70.x Items (Should be INCLUDED) ===';
SELECT 
  DISTINCT ITEMNMBR,
  COUNT(*) OVER (PARTITION BY ITEMNMBR) AS EventCount,
  MIN(EventType) OVER (PARTITION BY ITEMNMBR) AS FirstEventType
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE ITEMNMBR LIKE '60.%' OR ITEMNMBR LIKE '70.%'
ORDER BY ITEMNMBR;

-- ============================================================
-- TEST 4: PO commitment and receipt separation
-- ============================================================
PRINT '=== TEST 4: PO Commitment vs Receipt Separation ===';
SELECT 
  EventType, 
  COUNT(*) AS Count,
  SUM([PO's]) AS TotalQty,
  AVG([PO's]) AS AvgQty,
  MIN([PO's]) AS MinQty,
  MAX([PO's]) AS MaxQty
FROM dbo.ETB2_EventLedger_v1
WHERE EventType IN ('PO_COMMITMENT', 'PO_RECEIPT')
GROUP BY EventType
ORDER BY EventType;

-- ============================================================
-- TEST 5: MO de-duplication validation
-- ============================================================
PRINT '=== TEST 5: MO De-duplication (Multiple Dates per Item) ===';
SELECT 
  ORDERNUMBER,
  ITEMNMBR,
  COUNT(*) AS LineCount,
  MIN(DUEDATE) AS EarliestDate,
  MAX(DUEDATE) AS LatestDate,
  SUM(Deductions) AS TotalDeductions,
  COUNT(DISTINCT DUEDATE) AS DistinctDates
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE EventType = 'DEMAND'
GROUP BY ORDERNUMBER, ITEMNMBR
HAVING COUNT(*) > 1
ORDER BY ORDERNUMBER, ITEMNMBR;

-- ============================================================
-- TEST 6: Running balance calculation verification
-- ============================================================
PRINT '=== TEST 6: Running Balance Calculation (Sample Item) ===';
WITH ItemSample AS (
  SELECT TOP 1 ITEMNMBR, Site
  FROM dbo.ETB2_PAB_EventLedger_v1
  WHERE EventType = 'BEGIN_BAL'
  ORDER BY ITEMNMBR
)
SELECT 
  e.ORDERNUMBER,
  e.ITEMNMBR,
  e.Site,
  e.DUEDATE,
  e.EventType,
  e.SortPriority,
  e.BEG_BAL,
  e.[PO's],
  e.Deductions,
  e.Expiry,
  (e.BEG_BAL + e.[PO's] + e.Deductions + e.Expiry) AS EventQty,
  e.Running_Balance,
  e.EventSeq
FROM dbo.ETB2_PAB_EventLedger_v1 e
CROSS JOIN ItemSample s
WHERE e.ITEMNMBR = s.ITEMNMBR AND e.Site = s.Site
ORDER BY e.Site, e.DUEDATE, e.SortPriority, e.ORDERNUMBER;

-- ============================================================
-- TEST 7: Expiry event validation
-- ============================================================
PRINT '=== TEST 7: Expiry Events ===';
SELECT 
  ORDERNUMBER,
  ITEMNMBR,
  ItemDescription,
  Site,
  DUEDATE,
  STSDESCR,
  Expiry,
  Running_Balance
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE EventType = 'EXPIRY'
ORDER BY DUEDATE DESC;

-- ============================================================
-- TEST 8: Beginning balance validation
-- ============================================================
PRINT '=== TEST 8: Beginning Balance Events ===';
SELECT 
  ITEMNMBR,
  ItemDescription,
  Site,
  BEG_BAL,
  Running_Balance,
  EventSeq
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE EventType = 'BEGIN_BAL'
ORDER BY ITEMNMBR, Site;

-- ============================================================
-- TEST 9: Event sequence ordering validation
-- ============================================================
PRINT '=== TEST 9: Event Sequence Ordering (Sample Item/Site) ===';
WITH ItemSiteSample AS (
  SELECT TOP 1 ITEMNMBR, Site
  FROM dbo.ETB2_PAB_EventLedger_v1
  WHERE EventType = 'BEGIN_BAL'
  ORDER BY ITEMNMBR
)
SELECT 
  e.EventSeq,
  e.DUEDATE,
  e.SortPriority,
  e.EventType,
  e.ORDERNUMBER,
  e.BEG_BAL,
  e.[PO's],
  e.Deductions,
  e.Expiry,
  e.Running_Balance
FROM dbo.ETB2_PAB_EventLedger_v1 e
CROSS JOIN ItemSiteSample s
WHERE e.ITEMNMBR = s.ITEMNMBR AND e.Site = s.Site
ORDER BY e.EventSeq;

-- ============================================================
-- TEST 10: Data quality checks
-- ============================================================
PRINT '=== TEST 10: Data Quality Checks ===';
SELECT 
  'NULL ORDERNUMBER' AS Issue, COUNT(*) AS Count
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE ORDERNUMBER IS NULL
UNION ALL
SELECT 
  'NULL ITEMNMBR', COUNT(*)
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE ITEMNMBR IS NULL
UNION ALL
SELECT 
  'NULL Site', COUNT(*)
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE Site IS NULL
UNION ALL
SELECT 
  'NULL DUEDATE', COUNT(*)
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE DUEDATE IS NULL
UNION ALL
SELECT 
  'NULL EventType', COUNT(*)
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE EventType IS NULL
UNION ALL
SELECT 
  'NULL Running_Balance', COUNT(*)
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE Running_Balance IS NULL;

-- ============================================================
-- TEST 11: Verify event priority ordering
-- ============================================================
PRINT '=== TEST 11: Event Priority Ordering ===';
SELECT 
  SortPriority,
  EventType,
  COUNT(*) AS Count
FROM dbo.ETB2_PAB_EventLedger_v1
GROUP BY SortPriority, EventType
ORDER BY SortPriority, EventType;

-- ============================================================
-- TEST 12: Summary statistics
-- ============================================================
PRINT '=== TEST 12: Summary Statistics ===';
SELECT 
  COUNT(*) AS TotalEvents,
  COUNT(DISTINCT ITEMNMBR) AS UniqueItems,
  COUNT(DISTINCT Site) AS UniqueSites,
  COUNT(DISTINCT ORDERNUMBER) AS UniqueOrders,
  MIN(DUEDATE) AS EarliestDate,
  MAX(DUEDATE) AS LatestDate,
  SUM(BEG_BAL) AS TotalBeginningBalance,
  SUM([PO's]) AS TotalPOs,
  SUM(Deductions) AS TotalDeductions,
  SUM(Expiry) AS TotalExpiry
FROM dbo.ETB2_PAB_EventLedger_v1;

/*
================================================================================
EXPECTED RESULTS:
- TEST 1: Should return 20 rows with all required columns populated
- TEST 2: Should show 5 event types (BEGIN_BAL, PO_COMMITMENT, PO_RECEIPT, DEMAND, EXPIRY)
- TEST 3: Should return rows for 60.x and 70.x items (confirming they are INCLUDED)
- TEST 4: Should show both PO_COMMITMENT and PO_RECEIPT as separate events
- TEST 5: Should show MOs with multiple dates de-duplicated to earliest date
- TEST 6: Should show running balance increasing/decreasing correctly
- TEST 7: Should show expiry events with negative quantities
- TEST 8: Should show beginning balance as first event per item/site
- TEST 9: Should show events ordered by date, then sort priority, then order number
- TEST 10: Should show 0 rows (no NULL values in critical columns)
- TEST 11: Should show SortPriority 1-4 with corresponding event types
- TEST 12: Should show summary counts and totals

================================================================================
*/
