-- ============================================================================
-- VIEW 1 of 6: ETB2_PAB_EventLedger_v1
-- ENHANCEMENT: Standardize to IV00101, optimize column order
-- ============================================================================

CREATE OR ALTER VIEW dbo.ETB2_PAB_EventLedger_v1
AS
WITH AllEvents AS (
  
  -- ============================================================
  -- 1. BEGINNING BALANCE (one row per item/site with inventory)
  -- ============================================================
  SELECT 
    '' AS ORDERNUMBER,
    TRIM(i.ITEMNMBR) AS ITEMNMBR,
    TRIM(COALESCE(itm.ITEMDESC, '')) AS Item_Description,
    TRIM(COALESCE(itm.UOMSCHDL, '')) AS Unit_Of_Measure,
    TRIM(i.LOCNCODE) AS Site,
    CAST('1900-01-01' AS date) AS DUEDATE,
    'Beginning Balance' AS STSDESCR,
    1 AS SortPriority,
    CAST(i.QTYONHND AS decimal(19,5)) AS BEG_BAL,
    CAST(0 AS decimal(19,5)) AS Deductions,
    CAST(0 AS decimal(19,5)) AS Expiry,
    CAST(0 AS decimal(19,5)) AS [PO's],
    'BEGIN_BAL' AS EventType
  FROM IV00102 i WITH (NOLOCK)
  LEFT JOIN IV00101 itm WITH (NOLOCK)
    ON LTRIM(RTRIM(i.ITEMNMBR)) = LTRIM(RTRIM(itm.ITEMNMBR))
  WHERE i.QTYONHND <> 0
  
  UNION ALL
  
  -- ============================================================
  -- 2. PO COMMITMENTS (full ordered qty minus cancellations)
  -- ============================================================
  SELECT 
    TRIM(POL.PONUMBER) AS ORDERNUMBER,
    TRIM(POL.ITEMNMBR) AS ITEMNMBR,
    TRIM(COALESCE(itm.ITEMDESC, '')) AS Item_Description,
    TRIM(COALESCE(itm.UOMSCHDL, '')) AS Unit_Of_Measure,
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
    'PO_COMMITMENT' AS EventType
  FROM POP10100 POL WITH (NOLOCK)
  INNER JOIN POP10110 POH WITH (NOLOCK) 
    ON POL.PONUMBER = POH.PONUMBER
  LEFT JOIN IV00101 itm WITH (NOLOCK)
    ON LTRIM(RTRIM(POL.ITEMNMBR)) = LTRIM(RTRIM(itm.ITEMNMBR))
  WHERE POH.POSTATUS IN (2, 4)
    AND (POL.QTYORDER - POL.QTYCANCE) > 0
    AND POL.REQDATE >= DATEADD(MONTH, -12, GETDATE())
    AND POL.REQDATE <= DATEADD(MONTH, 18, GETDATE())
  
  UNION ALL
  
  -- ============================================================
  -- 3. PO RECEIPTS (additive, not subtractive from commitment)
  -- ============================================================
  SELECT 
    TRIM(R.PONUMBER) AS ORDERNUMBER,
    TRIM(R.ITEMNMBR) AS ITEMNMBR,
    TRIM(COALESCE(itm.ITEMDESC, '')) AS Item_Description,
    TRIM(COALESCE(itm.UOMSCHDL, '')) AS Unit_Of_Measure,
    TRIM(R.LOCNCODE) AS Site,
    CAST(R.RECPTDATE AS date) AS DUEDATE,
    'Received' AS STSDESCR,
    2 AS SortPriority,
    CAST(0 AS decimal(19,5)) AS BEG_BAL,
    CAST(0 AS decimal(19,5)) AS Deductions,
    CAST(0 AS decimal(19,5)) AS Expiry,
    CAST(R.QTYRECVD AS decimal(19,5)) AS [PO's],
    'PO_RECEIPT' AS EventType
  FROM POP10300 R WITH (NOLOCK)
  LEFT JOIN IV00101 itm WITH (NOLOCK)
    ON LTRIM(RTRIM(R.ITEMNMBR)) = LTRIM(RTRIM(itm.ITEMNMBR))
  WHERE R.QTYRECVD > 0
    AND R.RECPTDATE >= DATEADD(MONTH, -12, GETDATE())
  
  UNION ALL
  
  -- ============================================================
  -- 4. DEMAND (from ETB_PAB_AUTO, de-duplicated by earliest date)
  -- ============================================================
  SELECT 
    TRIM(D.ORDERNUMBER) AS ORDERNUMBER,
    TRIM(D.ITEMNMBR) AS ITEMNMBR,
    TRIM(COALESCE(itm.ITEMDESC, '')) AS Item_Description,
    TRIM(COALESCE(itm.UOMSCHDL, '')) AS Unit_Of_Measure,
    'MAIN' AS Site,
    MIN(TRY_CONVERT(DATE, D.DUEDATE)) AS DUEDATE,
    TRIM(D.STSDESCR) AS STSDESCR,
    3 AS SortPriority,
    CAST(0 AS decimal(19,5)) AS BEG_BAL,
    CAST(-SUM(CASE 
      WHEN COALESCE(D.REMAINING, 0) > 0 THEN D.REMAINING
      WHEN COALESCE(D.DEDUCTIONS, 0) > 0 THEN D.DEDUCTIONS
      WHEN COALESCE(D.EXPIRY, 0) > 0 THEN D.EXPIRY
      ELSE 0
    END) AS decimal(19,5)) AS Deductions,
    CAST(0 AS decimal(19,5)) AS Expiry,
    CAST(0 AS decimal(19,5)) AS [PO's],
    'DEMAND' AS EventType
  FROM dbo.ETB_PAB_AUTO D
  LEFT JOIN IV00101 itm WITH (NOLOCK)
    ON LTRIM(RTRIM(D.ITEMNMBR)) = LTRIM(RTRIM(itm.ITEMNMBR))
  WHERE D.ITEMNMBR NOT LIKE '60.%'
    AND D.ITEMNMBR NOT LIKE '70.%'
    AND D.STSDESCR <> 'Partially Received'
    AND (COALESCE(D.REMAINING, 0) + COALESCE(D.DEDUCTIONS, 0) + COALESCE(D.EXPIRY, 0)) > 0
  GROUP BY D.ORDERNUMBER, D.ITEMNMBR, D.STSDESCR, itm.ITEMDESC, itm.UOMSCHDL
  
  UNION ALL
  
  -- ============================================================
  -- 5. EXPIRY (if expiry data exists)
  -- ============================================================
  SELECT 
    TRIM(D.ORDERNUMBER) AS ORDERNUMBER,
    TRIM(D.ITEMNMBR) AS ITEMNMBR,
    TRIM(COALESCE(itm.ITEMDESC, '')) AS Item_Description,
    TRIM(COALESCE(itm.UOMSCHDL, '')) AS Unit_Of_Measure,
    'MAIN' AS Site,
    TRY_CONVERT(DATE, D.[Date + Expiry]) AS DUEDATE,
    'Expiring' AS STSDESCR,
    4 AS SortPriority,
    CAST(0 AS decimal(19,5)) AS BEG_BAL,
    CAST(0 AS decimal(19,5)) AS Deductions,
    CAST(-COALESCE(D.EXPIRY, 0) AS decimal(19,5)) AS Expiry,
    CAST(0 AS decimal(19,5)) AS [PO's],
    'EXPIRY' AS EventType
  FROM dbo.ETB_PAB_AUTO D
  LEFT JOIN IV00101 itm WITH (NOLOCK)
    ON LTRIM(RTRIM(D.ITEMNMBR)) = LTRIM(RTRIM(itm.ITEMNMBR))
  WHERE D.EXPIRY > 0
    AND D.[Date + Expiry] IS NOT NULL
    AND TRY_CONVERT(DATE, D.[Date + Expiry]) BETWEEN GETDATE() AND DATEADD(MONTH, 6, GETDATE())
)

-- ============================================================
-- FINAL OUTPUT: Planner-optimized column order
-- ============================================================
SELECT 
  -- IDENTIFICATION (leftmost - what am I looking at?)
  ITEMNMBR                AS Item_Number,
  Item_Description,
  Unit_Of_Measure,
  
  -- EVENT CONTEXT (when and what type?)
  DUEDATE                 AS Event_Date,
  EventType,
  STSDESCR                AS Status_Description,
  ORDERNUMBER             AS Order_Number,
  Site,
  
  -- QUANTITIES (the math - always same order)
  BEG_BAL                 AS Beginning_Balance,
  [PO's]                  AS Purchase_Orders,
  Deductions              AS Demand_Deductions,
  Expiry                  AS Expiry_Quantity,
  
  -- RUNNING BALANCE (the answer)
  SUM(BEG_BAL + Deductions + Expiry + [PO's]) OVER (
    PARTITION BY ITEMNMBR, Site
    ORDER BY DUEDATE, SortPriority, ORDERNUMBER
    ROWS UNBOUNDED PRECEDING
  ) AS Running_Balance,
  
  -- METADATA (for sorting/debugging)
  SortPriority            AS Event_Priority,
  ROW_NUMBER() OVER (
    PARTITION BY ITEMNMBR, Site
    ORDER BY DUEDATE, SortPriority, ORDERNUMBER
  ) AS Event_Sequence
  
FROM AllEvents
ORDER BY 
  Item_Number, 
  Site, 
  Event_Date, 
  Event_Priority, 
  Order_Number;

GO

-- ============================================================================
-- TEST QUERY: Verify enhancement
-- ============================================================================
-- SELECT TOP 100 * FROM dbo.ETB2_PAB_EventLedger_v1 
-- WHERE Item_Description IS NOT NULL
-- ORDER BY Item_Number, Event_Date;
