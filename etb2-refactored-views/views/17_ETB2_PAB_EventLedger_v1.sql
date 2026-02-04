-- ============================================================================
-- FG SOURCE (FIXED): Pre-calculate FG/Construct from ETB_ActiveDemand_Union_FG_MO
-- FIX: Swapped source table from ETB_PAB_MO to ETB_ActiveDemand_Union_FG_MO
-- to resolve invalid column 'FG' errors.
-- ============================================================================
WITH FG_From_MO AS (
    SELECT
        m.ORDERNUMBER,
        m.FG_Item_Number AS FG_Item_Number,
        m.FG_Description AS FG_Description,
        m.Construct AS Construct,
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
    FROM dbo.ETB_ActiveDemand_Union_FG_MO m WITH (NOLOCK)
    WHERE m.FG_Item_Number IS NOT NULL
      AND m.FG_Item_Number <> ''
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
      AND LTRIM(RTRIM(pab.ITEMNMBR)) NOT LIKE 'MO-%'
)

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
    CAST(0 AS BIT) AS Is_Suppressed,
    
    -- FG SOURCE (PAB-style): NULL for PO events (no MO linkage)
    NULL AS FG_Item_Number,
    NULL AS FG_Description,
    -- Construct SOURCE (PAB-style): NULL for PO events (no MO linkage)
    NULL AS Construct
    
FROM dbo.POP10100 p WITH (NOLOCK)
INNER JOIN dbo.POP10110 pd WITH (NOLOCK) ON p.PONUMBER = pd.PONUMBER
LEFT JOIN dbo.IV00102 i WITH (NOLOCK) ON pd.ITEMNMBR = i.ITEMNMBR
WHERE pd.ITEMNMBR IN (
    SELECT Item_Number 
    FROM dbo.ETB2_Demand_Cleaned_Base 
    WHERE client = 'DEFAULT_CLIENT' AND contract = 'DEFAULT_CONTRACT' AND run = 'CURRENT_RUN'
)
  AND pd.ITEMNMBR NOT LIKE 'MO-%'
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
    
    -- Suppression flag
    CAST(0 AS BIT) AS Is_Suppressed,
    
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
