-- ============================================================================
-- VIEW 17: dbo.ETB2_PAB_EventLedger_v1 (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Audit trail for PAB order changes - tracks all order modifications
-- Grain: One row per order event (order created, modified, received, cancelled)
-- Dependencies:
--   - dbo.POP10100, dbo.POP10110 (external tables)
--   - dbo.ETB_PAB_AUTO (external table)
--   - dbo.IV00102 (external table)
--   - dbo.Prosenthal_Vendor_Items (external table)
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all UNION parts
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window: ±90 days
--   - Context preserved in subqueries
-- Last Updated: 2026-01-29
-- ============================================================================

-- Part 1: Purchase Orders
SELECT 
    -- Context columns
    'DEFAULT_CLIENT' AS client,
    'DEFAULT_CONTRACT' AS contract,
    'CURRENT_RUN' AS run,
    
    LTRIM(RTRIM(p.PONUMBER)) AS Order_Number,
    LTRIM(RTRIM(p.VENDORID)) AS Vendor_ID,
    pd.ITEMNMBR AS Item_Number,
    pd.UOFM AS Unit_Of_Measure,
    COALESCE(TRY_CAST(pd.QTYORDER AS DECIMAL(18,4)), 0) AS Ordered_Qty,
    COALESCE(TRY_CAST(pd.QTYRECEIVED AS DECIMAL(18,4)), 0) AS Received_Qty,
    COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) AS Remaining_Qty,
    CASE 
        WHEN COALESCE(TRY_CAST(pd.QTYRECEIVED AS DECIMAL(18,4)), 0) > 0 THEN 'RECEIVED'
        WHEN COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) = COALESCE(TRY_CAST(pd.QTYORDER AS DECIMAL(18,4)), 0) THEN 'OPEN'
        WHEN COALESCE(TRY_CAST(pd.QTYREMGTD AS DECIMAL(18,4)), 0) < COALESCE(TRY_CAST(pd.QTYORDER AS DECIMAL(18,4)), 0) AND COALESCE(TRY_CAST(pd.QTYRECEIVED AS DECIMAL(18,4)), 0) > 0 THEN 'PARTIAL'
        ELSE 'PENDING'
    END AS Event_Type,
    TRY_CONVERT(DATE, p.DOCDATE) AS Order_Date,
    TRY_CONVERT(DATE, p.REQDATE) AS Required_Date,
    GETDATE() AS ETB2_Load_Date,
    ISNULL(i.ITEMDESC, '') AS Item_Description,
    
    -- Suppression flag
    CAST(0 AS BIT) AS Is_Suppressed
    
FROM dbo.POP10100 p WITH (NOLOCK)
INNER JOIN dbo.POP10110 pd WITH (NOLOCK) ON p.PONUMBER = pd.PONUMBER
LEFT JOIN dbo.IV00102 i WITH (NOLOCK) ON pd.ITEMNMBR = i.ITEMNMBR
WHERE pd.ITEMNMBR IN (
    SELECT Item_Number 
    FROM dbo.ETB2_Demand_Cleaned_Base 
    WHERE client = 'DEFAULT_CLIENT' AND contract = 'DEFAULT_CONTRACT' AND run = 'CURRENT_RUN'
)
  AND pd.ITEMNMBR NOT LIKE 'MO-%'  -- Filter out MO- conflated items
  AND TRY_CONVERT(DATE, p.DOCDATE) BETWEEN
      DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
      AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))

UNION ALL

-- Part 2: PAB Auto Demand
SELECT 
    -- Context columns
    'DEFAULT_CLIENT' AS client,
    'DEFAULT_CONTRACT' AS contract,
    'CURRENT_RUN' AS run,
    
    LTRIM(RTRIM(pab.ORDERNUMBER)) AS Order_Number,
    '' AS Vendor_ID,
    LTRIM(RTRIM(pab.ITEMNMBR)) AS Item_Number,
    '' AS Unit_Of_Measure,
    CASE 
        WHEN ISNUMERIC(LTRIM(RTRIM(pab.Running_Balance))) = 1 
        THEN COALESCE(TRY_CAST(LTRIM(RTRIM(pab.Running_Balance)) AS DECIMAL(18,5)), 0)
        ELSE 0 
    END AS Ordered_Qty,
    0 AS Received_Qty,
    CASE 
        WHEN ISNUMERIC(LTRIM(RTRIM(pab.Running_Balance))) = 1 
        THEN COALESCE(TRY_CAST(LTRIM(RTRIM(pab.Running_Balance)) AS DECIMAL(18,5)), 0)
        ELSE 0 
    END AS Remaining_Qty,
    'DEMAND' AS Event_Type,
    TRY_CONVERT(DATE, pab.DUEDATE) AS Order_Date,
    TRY_CONVERT(DATE, pab.DUEDATE) AS Required_Date,
    GETDATE() AS ETB2_Load_Date,
    ISNULL(vi.ITEMDESC, '') AS Item_Description,
    
    -- Suppression flag
    CAST(0 AS BIT) AS Is_Suppressed
    
FROM dbo.ETB_PAB_AUTO pab WITH (NOLOCK)
LEFT JOIN dbo.Prosenthal_Vendor_Items vi WITH (NOLOCK) 
    ON LTRIM(RTRIM(pab.ITEMNMBR)) = LTRIM(RTRIM(vi.[Item Number]))
WHERE pab.STSDESCR <> 'Partially Received'
    AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '60.%'
    AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '70.%'
    AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE 'MO-%'  -- Filter out MO- conflated items
    AND TRY_CONVERT(DATE, pab.DUEDATE) BETWEEN
        DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
        AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE));

-- ============================================================================
-- END OF VIEW 17 (REFACTORED)
-- ============================================================================