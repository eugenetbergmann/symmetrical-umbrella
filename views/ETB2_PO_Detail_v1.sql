/*
===============================================================================
View: dbo.ETB2_PO_Detail_v1
Description: Purchase order line-level tracking with delivery status
Version: 1.0.0
Last Modified: 2026-01-25
Dependencies:
   - GP tables POP10100 (PO Header)
   - GP tables POP10110 (PO Lines)

Purpose:
   - Tracks purchase order lines with delivery status
   - Calculates quantity remaining and days until due
   - Classifies delivery status (PAST_DUE, DUE_SOON, ON_TIME, COMPLETED)
   - Calculates receipt completion percentage

Business Rules:
   - Quantity_Remaining = Quantity_Ordered - Quantity_Received - Quantity_Cancelled
   - Delivery status based on promised date and remaining quantity
   - Filters to active POs only (not fully closed)
   - Days_Until_Due = DATEDIFF(Promised_Date, TODAY)

RESTORES:
   - dbo.Rolyat_PO_Detail (View 15)

USAGE:
   - Upstream for ETB2_Supply_Chain_Master_v1
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_PO_Detail_v1
AS

WITH POData AS (
  -- Join PO header and line data
  SELECT 
    h.PONUMBER,
    h.VENDORID,
    h.PODATE,
    h.POSTATUS,
    l.LNITMSEQ,
    l.ITEMNMBR,
    l.ITEMDESC,
    l.QTYORDER,
    l.QTYRCEIV,
    l.QTYCNCLD,
    l.PROMDATE,
    l.UNITCOST,
    l.EXTDCOST,
    GETDATE() AS Snapshot_Date
  FROM POP10100 h WITH (NOLOCK)
  INNER JOIN POP10110 l WITH (NOLOCK)
    ON h.PONUMBER = l.PONUMBER
  WHERE h.POSTATUS NOT IN (4)  -- Exclude fully closed POs
),

QuantityCalculations AS (
  -- Calculate quantities and delivery status
  SELECT 
    PONUMBER,
    VENDORID,
    PODATE,
    POSTATUS,
    LNITMSEQ,
    ITEMNMBR,
    ITEMDESC,
    QTYORDER,
    QTYRCEIV,
    QTYCNCLD,
    PROMDATE,
    UNITCOST,
    EXTDCOST,
    
    -- Quantity remaining
    CAST(QTYORDER - QTYRCEIV - QTYCNCLD AS DECIMAL(18,5)) AS Quantity_Remaining,
    
    -- Days until due
    DATEDIFF(DAY, CAST(GETDATE() AS date), CAST(PROMDATE AS date)) AS Days_Until_Due,
    
    -- Receipt completion percentage
    CASE 
      WHEN QTYORDER > 0 
      THEN CAST(QTYRCEIV * 100.0 / QTYORDER AS DECIMAL(5,2))
      ELSE 0
    END AS Receipt_Completion_Pct,
    
    -- Delivery status classification
    CASE 
      WHEN POSTATUS = 4 OR (QTYORDER - QTYRCEIV - QTYCNCLD) <= 0 
        THEN 'COMPLETED'
      WHEN DATEDIFF(DAY, CAST(GETDATE() AS date), CAST(PROMDATE AS date)) < 0 
        AND (QTYORDER - QTYRCEIV - QTYCNCLD) > 0 
        THEN 'PAST_DUE'
      WHEN DATEDIFF(DAY, CAST(GETDATE() AS date), CAST(PROMDATE AS date)) BETWEEN 0 AND 7 
        AND (QTYORDER - QTYRCEIV - QTYCNCLD) > 0 
        THEN 'DUE_SOON'
      ELSE 'ON_TIME'
    END AS Delivery_Status,
    
    Snapshot_Date
  FROM POData
)

-- Final output
SELECT 
  PONUMBER,
  VENDORID,
  PODATE,
  POSTATUS,
  LNITMSEQ,
  ITEMNMBR,
  ITEMDESC,
  QTYORDER,
  QTYRCEIV,
  QTYCNCLD,
  Quantity_Remaining,
  PROMDATE,
  Days_Until_Due,
  UNITCOST,
  EXTDCOST,
  Receipt_Completion_Pct,
  Delivery_Status,
  Snapshot_Date
FROM QuantityCalculations
WHERE Quantity_Remaining > 0
   OR Delivery_Status = 'COMPLETED'
ORDER BY PONUMBER, LNITMSEQ;
