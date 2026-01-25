-- ============================================================================
-- ETB2 Query: Inventory_WC_Batches
-- Purpose: Work Center batch inventory with FEFO ordering
-- Grain: WC Batch
-- Rolyat Source: Rolyat_WC_Inventory (100% logic preserved)
--   - Site: LOCNCODE LIKE 'WC[_-]%'
--   - FEFO: Expiry_Date ASC → Receipt_Date ASC
--   - Shelf Life: 180-day fallback if no EXPNDATE
--   - Eligibility: Always (no hold period)
--   - Client_ID: Extracted from LOCNCODE
-- Excel-Ready: Yes (SELECT-only, human-readable columns)
-- Dependencies: None (fully self-contained)
-- Last Updated: 2026-01-25
-- ============================================================================

WITH

-- Inline global shelf life default (from Rolyat_Config_Global)
GlobalShelfLife AS (
    SELECT 180 AS Default_WC_Shelf_Life_Days
),

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

ParsedInventory AS (
    SELECT
        ITEMNMBR,
        LOT_NUMBER,
        BIN,
        LOCNCODE,
        QTY_Available,
        CAST(DATERECD AS DATE) AS Receipt_Date,
        TRY_CONVERT(DATE, EXPNDATE) AS Expiry_Date_Raw,
        COALESCE(TRY_CONVERT(DATE, EXPNDATE),
                 DATEADD(DAY, gsl.Default_WC_Shelf_Life_Days, CAST(DATERECD AS DATE)))
            AS Expiry_Date,
        DATEDIFF(DAY, CAST(DATERECD AS DATE), CAST(GETDATE() AS DATE)) AS Batch_Age_Days,
        -- Extract Client_ID: everything before first '-' or '_'
        LEFT(LOCNCODE,
             PATINDEX('%[-_]%', LOCNCODE + '-') - 1) AS Client_ID,
        COALESCE(BINTYPE_Raw, 'UNKNOWN') AS Bin_Type
    FROM RawWCInventory
    CROSS JOIN GlobalShelfLife gsl
)

SELECT
    -- Human-readable Batch_ID for traceability
    CONCAT('WC-', LOCNCODE, '-', BIN, '-', ITEMNMBR, '-',
           CONVERT(VARCHAR(10), Receipt_Date, 120)) AS Batch_ID,

    ITEMNMBR                        AS Item_Number,
    Client_ID,
    LOCNCODE                        AS Location_Code,
    BIN                             AS Bin_Location,
    LOT_NUMBER                      AS Lot_Number,
    QTY_Available                   AS Available_Quantity,
    Receipt_Date,
    Expiry_Date,
    Batch_Age_Days,
    DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_Until_Expiry,
    0                               AS Degraded_Quantity,          -- not yet implemented
    Available_Quantity              AS Usable_Quantity,
    Bin_Type,

    -- FEFO Sort Priority (lower number = use first)
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Expiry_Date ASC, Receipt_Date ASC
    ) AS FEFO_Sort_Priority,

    -- Always eligible for WC
    1                               AS Is_Eligible_For_Allocation,
    'WC_BATCH'                      AS Inventory_Type

FROM ParsedInventory
WHERE Expiry_Date >= CAST(GETDATE() AS DATE)  -- optional: exclude already expired (common planner filter)
ORDER BY
    Item_Number ASC,
    Expiry_Date ASC,          -- soonest expiry first
    Receipt_Date ASC,         -- then oldest receipt
    Batch_ID ASC;