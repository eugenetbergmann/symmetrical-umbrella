/*
================================================================================
View: dbo.ETB2_PAB_EventLedger_v1
Description: Atomic event ledger matching PAB_AUTO pattern with separate PO 
             commitment and receipt events
Version: 1.0.0
Last Modified: 2026-01-23
Dependencies:
    - dbo.ETB_PAB_AUTO (source for beginning balance, demand, expiry)
    - dbo.ETB2_Demand_Cleaned_Base (demand reference)
    - IV00102 (inventory on hand)
    - POP10100, POP10110 (PO lines and headers)
    - POP10300 (PO receipts)
    - Prosenthal_Vendor_Items (item master)

Purpose:
   - Builds atomic event ledger with separate PO commitment and receipt events
   - Includes 60.x and 70.x items (IN-PROCESS MATERIALS)
   - De-duplicates MOs with multiple due dates (earliest date per item/MO)
   - Calculates running balance across all event types
   - Provides event sequencing for deterministic ordering

Business Rules:
   - 60.x and 70.x items are IN-PROCESS MATERIALS - INCLUDED (not excluded)
   - PO commitments and receipts are SEPARATE additive events (not netted)
   - MOs with multiple due dates de-duplicated to earliest date per item/MO
   - Demand reference: ETB2_Demand_Cleaned_Base (filters 'Partially Received')
   - Expiry events from demand view if available
   - Event ordering: BEGIN_BAL (1) > PO_COMMITMENT/PO_RECEIPT (2) > DEMAND (3) > EXPIRY (4)

Event Structure:
   Event Type       | SortPriority | Column        | Sign
   -----------------|--------------|---------------|------
   BEGIN_BAL        | 1            | BEG_BAL       | +
   PO_COMMITMENT    | 2            | [PO's]        | +
   PO_RECEIPT       | 2            | [PO's]        | +
   DEMAND           | 3            | Deductions    | -
   EXPIRY           | 4            | Expiry        | -

================================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_PAB_EventLedger_v1
AS

WITH AllEvents AS (
  -- ============================================================
  -- 1. BEGINNING BALANCE (one row per item/site with inventory)
  -- ============================================================
  SELECT 
    '' AS ORDERNUMBER,
    TRIM(i.ITEMNMBR) AS ITEMNMBR,
    TRIM(COALESCE(pvi.ITEMDESC, '')) AS ItemDescription,
    TRIM(i.LOCNCODE) AS Site,
    CAST('1900-01-01' AS date) AS DUEDATE,
    'Beginning Balance' AS STSDESCR,
    1 AS SortPriority,
    CAST(i.QTYONHND AS decimal(19,5)) AS BEG_BAL,
    CAST(0 AS decimal(19,5)) AS Deductions,
    CAST(0 AS decimal(19,5)) AS Expiry,
    CAST(0 AS decimal(19,5)) AS [PO's],
    'BEGIN_BAL' AS EventType,
    TRIM(COALESCE(pvi.UOMSCHDL, '')) AS UOMSCHDL
  FROM IV00102 i WITH (NOLOCK)
  INNER JOIN Prosenthal_Vendor_Items pvi WITH (NOLOCK)
    ON LTRIM(RTRIM(i.ITEMNMBR)) = LTRIM(RTRIM(pvi.[Item Number]))
  WHERE i.QTYONHND <> 0
    AND pvi.Active = 'Yes'
  
  UNION ALL
  
  -- ============================================================
  -- 2. PO COMMITMENTS (full ordered qty minus cancellations)
  -- ============================================================
  SELECT 
    TRIM(POL.PONUMBER) AS ORDERNUMBER,
    TRIM(POL.ITEMNMBR) AS ITEMNMBR,
    TRIM(COALESCE(pvi.ITEMDESC, '')) AS ItemDescription,
    TRIM(POL.LOCNCODE) AS Site,
    CAST(POL.REQDATE AS date) AS DUEDATE,
    CASE POH.POSTATUS 
      WHEN 2 THEN 'Released'
      WHEN 4 THEN 'Change Order'
      ELSE 'Other PO Status'
    END AS STSDESCR,
    2 AS SortPriority,
    CAST(0 AS decimal(19,5)) AS BEG_BAL,
    CAST(0 AS decimal(19,5)) AS Deductions,
    CAST(0 AS decimal(19,5)) AS Expiry,
    CAST((POL.QTYORDER - POL.QTYCANCE) AS decimal(19,5)) AS [PO's],
    'PO_COMMITMENT' AS EventType,
    TRIM(COALESCE(pvi.UOMSCHDL, '')) AS UOMSCHDL
  FROM POP10100 POL WITH (NOLOCK)
  INNER JOIN POP10110 POH WITH (NOLOCK) 
    ON POL.PONUMBER = POH.PONUMBER
  INNER JOIN Prosenthal_Vendor_Items pvi WITH (NOLOCK)
    ON LTRIM(RTRIM(POL.ITEMNMBR)) = LTRIM(RTRIM(pvi.[Item Number]))
  WHERE POH.POSTATUS IN (2, 4)  -- Released or Change Order
    AND (POL.QTYORDER - POL.QTYCANCE) > 0
    AND pvi.Active = 'Yes'
    AND POL.REQDATE >= DATEADD(MONTH, -12, GETDATE())  -- Last 12 months
    AND POL.REQDATE <= DATEADD(MONTH, 18, GETDATE())   -- Next 18 months
  
  UNION ALL
  
  -- ============================================================
  -- 3. PO RECEIPTS (additive, not subtractive from commitment)
  -- ============================================================
  SELECT 
    TRIM(R.PONUMBER) AS ORDERNUMBER,
    TRIM(R.ITEMNMBR) AS ITEMNMBR,
    TRIM(COALESCE(pvi.ITEMDESC, '')) AS ItemDescription,
    TRIM(R.LOCNCODE) AS Site,
    CAST(R.RECPTDATE AS date) AS DUEDATE,
    'Received' AS STSDESCR,
    2 AS SortPriority,
    CAST(0 AS decimal(19,5)) AS BEG_BAL,
    CAST(0 AS decimal(19,5)) AS Deductions,
    CAST(0 AS decimal(19,5)) AS Expiry,
    CAST(R.QTYRECVD AS decimal(19,5)) AS [PO's],
    'PO_RECEIPT' AS EventType,
    TRIM(COALESCE(pvi.UOMSCHDL, '')) AS UOMSCHDL
  FROM POP10300 R WITH (NOLOCK)
  INNER JOIN Prosenthal_Vendor_Items pvi WITH (NOLOCK)
    ON LTRIM(RTRIM(R.ITEMNMBR)) = LTRIM(RTRIM(pvi.[Item Number]))
  WHERE R.QTYRECVD > 0
    AND pvi.Active = 'Yes'
    AND R.RECPTDATE >= DATEADD(MONTH, -12, GETDATE())
  
  UNION ALL
  
  -- ============================================================
  -- 4. DEMAND (from existing ETB2_Demand_Cleaned_Base)
  -- DE-DUPLICATION: If MO has multiple lines with same item but different dates,
  -- use earliest date and sum quantities
  -- ============================================================
  SELECT 
    TRIM(D.ORDERNUMBER) AS ORDERNUMBER,
    TRIM(D.ITEMNMBR) AS ITEMNMBR,
    TRIM(D.ItemDescription) AS ItemDescription,
    TRIM(D.SITE) AS Site,
    MIN(D.DUEDATE) AS DUEDATE,  -- ✅ EARLIEST date if multiple
    TRIM(D.STSDESCR) AS STSDESCR,
    3 AS SortPriority,
    CAST(0 AS decimal(19,5)) AS BEG_BAL,
    CAST(-SUM(D.Base_Demand) AS decimal(19,5)) AS Deductions,  -- ✅ SUM if multiple dates
    CAST(0 AS decimal(19,5)) AS Expiry,
    CAST(0 AS decimal(19,5)) AS [PO's],
    'DEMAND' AS EventType,
    TRIM(D.UOMSCHDL) AS UOMSCHDL
  FROM dbo.ETB2_Demand_Cleaned_Base D
  WHERE D.Base_Demand > 0  -- Positive demand only
  GROUP BY 
    D.ORDERNUMBER,
    D.ITEMNMBR,
    D.ItemDescription,
    D.SITE,
    D.STSDESCR,
    D.UOMSCHDL
  -- Note: This de-dups MOs with multiple date rows per item
  
  UNION ALL
  
  -- ============================================================
  -- 5. EXPIRY (if expiry data exists in cleaned demand)
  -- ============================================================
  SELECT 
    TRIM(D.ORDERNUMBER) AS ORDERNUMBER,
    TRIM(D.ITEMNMBR) AS ITEMNMBR,
    TRIM(D.ItemDescription) AS ItemDescription,
    TRIM(D.SITE) AS Site,
    CAST(D.Expiry_Dates AS date) AS DUEDATE,
    'Expiring' AS STSDESCR,
    4 AS SortPriority,
    CAST(0 AS decimal(19,5)) AS BEG_BAL,
    CAST(0 AS decimal(19,5)) AS Deductions,
    CAST(-D.Expiry AS decimal(19,5)) AS Expiry,
    CAST(0 AS decimal(19,5)) AS [PO's],
    'EXPIRY' AS EventType,
    TRIM(D.UOMSCHDL) AS UOMSCHDL
  FROM dbo.ETB2_Demand_Cleaned_Base D
  WHERE D.Expiry > 0
    AND D.Expiry_Dates IS NOT NULL
    AND CAST(D.Expiry_Dates AS date) BETWEEN GETDATE() AND DATEADD(MONTH, 6, GETDATE())
)

SELECT 
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
  
  -- ============================================================
  -- RUNNING BALANCE (cumulative sum of all event columns)
  -- ============================================================
  SUM(BEG_BAL + Deductions + Expiry + [PO's]) OVER (
    PARTITION BY ITEMNMBR, Site
    ORDER BY DUEDATE, SortPriority, ORDERNUMBER
    ROWS UNBOUNDED PRECEDING
  ) AS Running_Balance,
  
  -- ============================================================
  -- Event sequence number for debugging
  -- ============================================================
  ROW_NUMBER() OVER (
    PARTITION BY ITEMNMBR, Site
    ORDER BY DUEDATE, SortPriority, ORDERNUMBER
  ) AS EventSeq
  
FROM AllEvents;

/*
================================================================================
DIAGNOSTIC QUERIES
================================================================================

-- Verify view creation and basic structure
SELECT TOP 20 * FROM dbo.ETB2_PAB_EventLedger_v1 ORDER BY ITEMNMBR, DUEDATE;

-- Check event type distribution
SELECT EventType, COUNT(*) AS EventCount, SUM(BEG_BAL + Deductions + Expiry + [PO's]) AS TotalQty
FROM dbo.ETB2_PAB_EventLedger_v1
GROUP BY EventType
ORDER BY EventType;

-- Verify running balance calculation for a specific item
SELECT 
  ITEMNMBR, 
  Site, 
  DUEDATE, 
  EventType, 
  ORDERNUMBER,
  BEG_BAL,
  [PO's],
  Deductions,
  Expiry,
  Running_Balance,
  EventSeq
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE ITEMNMBR = 'YOUR_TEST_ITEM'
ORDER BY Site, DUEDATE, SortPriority, ORDERNUMBER;

-- Check for 60.x and 70.x items (should be INCLUDED)
SELECT DISTINCT ITEMNMBR
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE ITEMNMBR LIKE '60.%' OR ITEMNMBR LIKE '70.%'
ORDER BY ITEMNMBR;

-- Verify PO commitment and receipt separation (both should exist)
SELECT 
  EventType, 
  COUNT(*) AS Count,
  SUM([PO's]) AS TotalQty
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE EventType IN ('PO_COMMITMENT', 'PO_RECEIPT')
GROUP BY EventType;

-- Check MO de-duplication (should have one row per MO/Item with earliest date)
SELECT 
  ORDERNUMBER,
  ITEMNMBR,
  COUNT(*) AS LineCount,
  MIN(DUEDATE) AS EarliestDate,
  SUM(Deductions) AS TotalDeductions
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE EventType = 'DEMAND'
GROUP BY ORDERNUMBER, ITEMNMBR
HAVING COUNT(*) > 1;

-- Verify expiry events exist and are properly dated
SELECT TOP 20 *
FROM dbo.ETB2_PAB_EventLedger_v1
WHERE EventType = 'EXPIRY'
ORDER BY DUEDATE;

================================================================================
*/
