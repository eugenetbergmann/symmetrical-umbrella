-- ============================================================================
-- VIEW 17: dbo.ETB2_PAB_EventLedger_v1
-- Deploy Order: 17 of 17 (Deploy BETWEEN 13 and 14)
-- Status: Ready for SSMS Deployment
-- ============================================================================
-- Purpose: Audit trail for PAB order changes - tracks all order modifications
-- Grain: One row per order event (order created, modified, received, cancelled)
-- ============================================================================
-- Copy/Paste this entire statement into SSMS query window
-- Then: Highlight all → Right-click → Create View → Save as dbo.ETB2_PAB_EventLedger_v1
-- ============================================================================

-- ============================================================================
-- FG SOURCE (PAB-style): Pre-calculate FG/Construct from ETB_PAB_MO
-- ============================================================================
WITH FG_From_MO AS (
    SELECT
        m.ORDERNUMBER,
        m.FG AS FG_Item_Number,
        m.[FG Desc] AS FG_Description,
        m.Customer AS Construct,
        UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(m.ORDERNUMBER, 'MO', ''),
                                '-', ''
                            ),
                            ' ', ''
                        ),
                        '/', ''
                    ),
                    '.', ''
                ),
                '#', ''
            )
        ) AS CleanOrder
    FROM dbo.ETB_PAB_MO m WITH (NOLOCK)
    WHERE m.FG IS NOT NULL
      AND m.FG <> ''
),

-- ============================================================================
-- CleanOrder mapping for PAB_AUTO
-- ============================================================================
PABWithCleanOrder AS (
    SELECT
        pab.ORDERNUMBER,
        pab.ITEMNMBR,
        pab.DUEDATE,
        pab.Running_Balance,
        pab.STSDESCR,
        UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(pab.ORDERNUMBER, 'MO', ''),
                                '-', ''
                            ),
                            ' ', ''
                        ),
                        '/', ''
                    ),
                    '.', ''
                ),
                '#', ''
            )
        ) AS CleanOrder
    FROM dbo.ETB_PAB_AUTO pab WITH (NOLOCK)
    WHERE pab.STSDESCR <> 'Partially Received'
      AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '60.%'
      AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE '70.%'
)

SELECT 
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
    -- FG SOURCE (PAB-style): NULL for PO events (no MO linkage)
    NULL AS FG_Item_Number,
    NULL AS FG_Description,
    -- Construct SOURCE (PAB-style): NULL for PO events (no MO linkage)
    NULL AS Construct
FROM dbo.POP10100 p WITH (NOLOCK)
INNER JOIN dbo.POP10110 pd WITH (NOLOCK) ON p.PONUMBER = pd.PONUMBER
LEFT JOIN dbo.IV00102 i WITH (NOLOCK) ON pd.ITEMNMBR = i.ITEMNMBR
WHERE pd.ITEMNMBR IN (SELECT Item_Number FROM dbo.ETB2_Demand_Cleaned_Base)

UNION ALL

SELECT 
    LTRIM(RTRIM(pco.ORDERNUMBER)) AS Order_Number,
    '' AS Vendor_ID,
    LTRIM(RTRIM(pco.ITEMNMBR)) AS Item_Number,
    '' AS Unit_Of_Measure,
    CASE 
        WHEN ISNUMERIC(LTRIM(RTRIM(pco.Running_Balance))) = 1 
        THEN COALESCE(TRY_CAST(LTRIM(RTRIM(pco.Running_Balance)) AS DECIMAL(18,5)), 0)
        ELSE 0 
    END AS Ordered_Qty,
    0 AS Received_Qty,
    CASE 
        WHEN ISNUMERIC(LTRIM(RTRIM(pco.Running_Balance))) = 1 
        THEN COALESCE(TRY_CAST(LTRIM(RTRIM(pco.Running_Balance)) AS DECIMAL(18,5)), 0)
        ELSE 0 
    END AS Remaining_Qty,
    'DEMAND' AS Event_Type,
    TRY_CONVERT(DATE, pco.DUEDATE) AS Order_Date,
    TRY_CONVERT(DATE, pco.DUEDATE) AS Required_Date,
    GETDATE() AS ETB2_Load_Date,
    ISNULL(vi.ITEMDESC, '') AS Item_Description,
    -- FG SOURCE (PAB-style): From ETB_PAB_MO linkage
    fg.FG_Item_Number,
    fg.FG_Description,
    -- Construct SOURCE (PAB-style): From ETB_PAB_MO linkage
    fg.Construct
FROM PABWithCleanOrder pco
LEFT JOIN dbo.Prosenthal_Vendor_Items vi WITH (NOLOCK) 
    ON LTRIM(RTRIM(pco.ITEMNMBR)) = LTRIM(RTRIM(vi.[Item Number]))
LEFT JOIN FG_From_MO fg
    ON pco.CleanOrder = fg.CleanOrder;

-- ============================================================================
-- END OF VIEW 17
-- ============================================================================
