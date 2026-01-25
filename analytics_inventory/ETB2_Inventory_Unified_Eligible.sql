-- ============================================================================
-- ETB2 Query: Inventory_Unified_Eligible
-- Purpose: All eligible inventory (WC + released quarantine batches)
-- Grain: Eligible Batch
-- Rolyat Source: Consolidation of ETB2_Inventory_WC_Batches + ETB2_Inventory_Quarantine_Restricted
--   - Allocation Priority: WC first, then FEFO (Expiry → Receipt)
--   - No expiry filter on WFQ/RMQTY (per ETB2 unification)
-- Excel-Ready: Yes (SELECT-only, human-readable columns)
-- Dependencies: None (fully self-contained, logic inlined via UNION ALL)
-- Last Updated: 2026-01-25
-- ============================================================================

WITH

-- Inline global config defaults
GlobalConfig AS (
    SELECT
        180 AS WC_Shelf_Life_Days,
        14 AS WFQ_Hold_Days,
        7 AS RMQTY_Hold_Days,
        90 AS Expiry_Filter_Days
),

-- WC Inventory (from T-003 logic)
RawWCInventory AS (
    SELECT
        pib.ITEMNMBR,
        pib.LOT_NUMBER,
        pib.BIN,
        pib.LOCNCODE,
        pib.QTY_Available,
        pib.DATERECD,
        pib.EXPNDATE,
        ext.BINTYPE AS Bin_Type_Raw
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib
    LEFT JOIN dbo.EXT_BINTYPE ext
        ON pib.BINTYPE = ext.BINTYPE
    WHERE pib.LOCNCODE LIKE 'WC[_-]%'
      AND pib.QTY_Available > 0
      AND pib.LOT_NUMBER IS NOT NULL
      AND pib.LOT_NUMBER <> ''
),

ParsedWCInventory AS (
    SELECT
        ITEMNMBR,
        LOT_NUMBER,
        BIN,
        LOCNCODE,
        QTY_Available,
        CAST(DATERECD AS DATE) AS Receipt_Date,
        TRY_CONVERT(DATE, EXPNDATE) AS Expiry_Date_Raw,
        COALESCE(TRY_CONVERT(DATE, EXPNDATE),
                 DATEADD(DAY, (SELECT WC_Shelf_Life_Days FROM GlobalConfig), CAST(DATERECD AS DATE)))
            AS Expiry_Date,
        DATEDIFF(DAY, CAST(DATERECD AS DATE), CAST(GETDATE() AS DATE)) AS Batch_Age_Days,
        LEFT(LOCNCODE,
             PATINDEX('%[-_]%', LOCNCODE + '-') - 1) AS Client_ID,
        COALESCE(Bin_Type_Raw, 'UNKNOWN') AS Bin_Type,
        1 AS SortPriority,
        'WC_BATCH' AS Inventory_Type
    FROM RawWCInventory
    WHERE Expiry_Date >= CAST(GETDATE() AS DATE)
),

-- WFQ Inventory (from T-004 logic)
RawWFQInventory AS (
    SELECT
        inv.ITEMNMBR,
        inv.LOCNCODE,
        inv.RCTSEQNM,
        inv.QTYRECVD - inv.QTYSOLD AS QTY_ON_HAND,
        inv.DATERECD,
        inv.EXPNDATE,
        itm.UOMSCHDL
    FROM dbo.IV00300 inv
    LEFT JOIN dbo.IV00101 itm ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE TRIM(inv.LOCNCODE) = 'WF-Q'
      AND (inv.QTYRECVD - inv.QTYSOLD) <> 0
      AND (inv.EXPNDATE IS NULL
           OR inv.EXPNDATE > DATEADD(DAY, (SELECT Expiry_Filter_Days FROM GlobalConfig), GETDATE()))
),

ParsedWFQInventory AS (
    SELECT
        ITEMNMBR,
        LOCNCODE,
        RCTSEQNM,
        SUM(QTY_ON_HAND) AS Available_Quantity,
        MAX(CAST(DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, EXPNDATE)) AS Expiry_Date,
        MAX(UOMSCHDL) AS UOM,
        DATEADD(DAY, (SELECT WFQ_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) AS Projected_Release_Date,
        DATEDIFF(DAY, MAX(CAST(DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Batch_Age_Days,
        CASE
            WHEN DATEADD(DAY, (SELECT WFQ_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) <= GETDATE()
            THEN 1 ELSE 0
        END AS Is_Eligible_For_Allocation,
        NULL AS Client_ID,
        'UNKNOWN' AS Bin_Type,
        2 AS SortPriority,
        'WFQ_BATCH' AS Inventory_Type
    FROM RawWFQInventory
    GROUP BY ITEMNMBR, LOCNCODE, RCTSEQNM
    HAVING SUM(QTY_ON_HAND) <> 0
),

-- RMQTY Inventory (from T-004 logic)
RawRMQTYInventory AS (
    SELECT
        inv.ITEMNMBR,
        inv.LOCNCODE,
        inv.RCTSEQNM,
        inv.QTYRECVD - inv.QTYSOLD AS QTY_ON_HAND,
        inv.DATERECD,
        inv.EXPNDATE,
        itm.UOMSCHDL
    FROM dbo.IV00300 inv
    LEFT JOIN dbo.IV00101 itm ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE TRIM(inv.LOCNCODE) = 'RMQTY'
      AND (inv.QTYRECVD - inv.QTYSOLD) <> 0
      AND (inv.EXPNDATE IS NULL
           OR inv.EXPNDATE > DATEADD(DAY, (SELECT Expiry_Filter_Days FROM GlobalConfig), GETDATE()))
),

ParsedRMQTYInventory AS (
    SELECT
        ITEMNMBR,
        LOCNCODE,
        RCTSEQNM,
        SUM(QTY_ON_HAND) AS Available_Quantity,
        MAX(CAST(DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, EXPNDATE)) AS Expiry_Date,
        MAX(UOMSCHDL) AS UOM,
        DATEADD(DAY, (SELECT RMQTY_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) AS Projected_Release_Date,
        DATEDIFF(DAY, MAX(CAST(DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Batch_Age_Days,
        CASE
            WHEN DATEADD(DAY, (SELECT RMQTY_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) <= GETDATE()
            THEN 1 ELSE 0
        END AS Is_Eligible_For_Allocation,
        NULL AS Client_ID,
        'UNKNOWN' AS Bin_Type,
        3 AS SortPriority,
        'RMQTY_BATCH' AS Inventory_Type
    FROM RawRMQTYInventory
    GROUP BY ITEMNMBR, LOCNCODE, RCTSEQNM
    HAVING SUM(QTY_ON_HAND) <> 0
)

SELECT
    -- Human-readable Batch_ID for traceability
    CONCAT(CASE WHEN Inventory_Type = 'WC_BATCH' THEN 'WC' ELSE LEFT(Inventory_Type, LEN(Inventory_Type)-6) END,
           '-', LOCNCODE, '-',
           CASE WHEN Inventory_Type = 'WC_BATCH' THEN BIN ELSE '' END,
           CASE WHEN Inventory_Type = 'WC_BATCH' THEN '-' ELSE '' END,
           ITEMNMBR, '-',
           CONVERT(VARCHAR(10), Receipt_Date, 120)) AS Batch_ID,

    ITEMNMBR                        AS Item_Number,
    Client_ID,
    LOCNCODE                        AS Location_Code,
    CASE WHEN Inventory_Type = 'WC_BATCH' THEN BIN ELSE NULL END AS Bin_Location,
    CASE WHEN Inventory_Type = 'WC_BATCH' THEN LOT_NUMBER ELSE NULL END AS Lot_Number,
    QTY_Available                   AS Available_Quantity,
    Receipt_Date,
    Expiry_Date,
    Batch_Age_Days,
    CASE
        WHEN Expiry_Date IS NOT NULL THEN DATEDIFF(DAY, GETDATE(), Expiry_Date)
        ELSE NULL
    END                             AS Days_Until_Expiry,
    0                               AS Degraded_Quantity,
    QTY_Available                   AS Usable_Quantity,
    Bin_Type,

    -- FEFO Sort Priority (within allocation priority)
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR, Inventory_Type
        ORDER BY
            CASE WHEN Inventory_Type = 'WC_BATCH' THEN Expiry_Date ELSE Projected_Release_Date END ASC,
            Receipt_Date ASC
    ) AS FEFO_Sort_Priority,

    Is_Eligible_For_Allocation,
    Inventory_Type,
    SortPriority                    AS Allocation_Priority

FROM ParsedWCInventory

UNION ALL

SELECT
    CONCAT('WFQ-', LOCNCODE, '-', ITEMNMBR, '-', CONVERT(VARCHAR(10), Receipt_Date, 120)) AS Batch_ID,

    ITEMNMBR                        AS Item_Number,
    Client_ID,
    LOCNCODE                        AS Location_Code,
    NULL                            AS Bin_Location,
    NULL                            AS Lot_Number,
    Available_Quantity,
    Receipt_Date,
    Expiry_Date,
    Batch_Age_Days,
    CASE
        WHEN Expiry_Date IS NOT NULL THEN DATEDIFF(DAY, GETDATE(), Expiry_Date)
        ELSE NULL
    END                             AS Days_Until_Expiry,
    0                               AS Degraded_Quantity,
    Available_Quantity              AS Usable_Quantity,
    Bin_Type,

    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR, Inventory_Type
        ORDER BY Projected_Release_Date ASC, Receipt_Date ASC
    ) AS FEFO_Sort_Priority,

    Is_Eligible_For_Allocation,
    Inventory_Type,
    SortPriority                    AS Allocation_Priority

FROM ParsedWFQInventory

UNION ALL

SELECT
    CONCAT('RMQTY-', LOCNCODE, '-', ITEMNMBR, '-', CONVERT(VARCHAR(10), Receipt_Date, 120)) AS Batch_ID,

    ITEMNMBR                        AS Item_Number,
    Client_ID,
    LOCNCODE                        AS Location_Code,
    NULL                            AS Bin_Location,
    NULL                            AS Lot_Number,
    Available_Quantity,
    Receipt_Date,
    Expiry_Date,
    Batch_Age_Days,
    CASE
        WHEN Expiry_Date IS NOT NULL THEN DATEDIFF(DAY, GETDATE(), Expiry_Date)
        ELSE NULL
    END                             AS Days_Until_Expiry,
    0                               AS Degraded_Quantity,
    Available_Quantity              AS Usable_Quantity,
    Bin_Type,

    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR, Inventory_Type
        ORDER BY Projected_Release_Date ASC, Receipt_Date ASC
    ) AS FEFO_Sort_Priority,

    Is_Eligible_For_Allocation,
    Inventory_Type,
    SortPriority                    AS Allocation_Priority

FROM ParsedRMQTYInventory

ORDER BY
    Allocation_Priority ASC,        -- WC first, then WFQ, then RMQTY
    Item_Number ASC,
    FEFO_Sort_Priority ASC,         -- within each, FEFO order
    Batch_ID ASC;