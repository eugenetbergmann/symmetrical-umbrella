-- ============================================================================
-- VIEW 05: dbo.ETB2_Inventory_WC_Batches (CONSOLIDATED FINAL)
-- ============================================================================
-- Purpose: Work Center batch inventory with FEFO ordering
-- Grain: Batch/Lot
-- Dependencies:
--   - dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (external table)
--   - dbo.EXT_BINTYPE (external table)
--   - dbo.IV00101 (Item master - external table)
--   - dbo.ETB_PAB_MO (external table) - FG SOURCE (PAB-style)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct from ETB_PAB_MO via lot-to-order pattern matching
--   - Is_Suppressed flag
--   - Date window: ±90 days
-- Last Updated: 2026-01-30
-- ============================================================================

WITH GlobalShelfLife AS (
    SELECT 180 AS Default_WC_Shelf_Life_Days
),

-- ============================================================================
-- FG SOURCE (FIXED): Derive FG from ETB_ActiveDemand_Union_FG_MO
-- FIX: Swapped source table from ETB_PAB_MO to ETB_ActiveDemand_Union_FG_MO
-- to resolve invalid column 'FG' errors.
-- ============================================================================
FG_From_MO AS (
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

RawWCInventory AS (
    SELECT
        -- Context columns
        'DEFAULT_CLIENT' AS client,
        'DEFAULT_CONTRACT' AS contract,
        'CURRENT_RUN' AS run,
        
        pib.Item_Number AS ITEMNMBR,
        pib.LOT_NUMBER,
        pib.Bin AS BIN,
        pib.SITE AS LOCNCODE,
        pib.QTY_Available,
        pib.DATERECD,
        pib.EXPNDATE
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib WITH (NOLOCK)
    WHERE pib.SITE LIKE 'WC[_-]%'
      AND pib.QTY_Available > 0
      AND pib.LOT_NUMBER IS NOT NULL
      AND pib.LOT_NUMBER <> ''
      AND pib.Item_Number NOT LIKE 'MO-%'
      AND CAST(GETDATE() AS DATE) BETWEEN 
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
),

-- ============================================================================
-- Link inventory to FG via Lot Number pattern matching
-- ============================================================================
InventoryWithFG AS (
    SELECT
        ri.client,
        ri.contract,
        ri.run,
        ri.ITEMNMBR,
        ri.LOT_NUMBER,
        ri.BIN,
        ri.LOCNCODE,
        ri.QTY_Available,
        ri.DATERECD,
        ri.EXPNDATE,
        -- FG SOURCE (PAB-style): Link via lot/order patterns
        fg.FG_Item_Number,
        fg.FG_Description,
        fg.Construct,
        ROW_NUMBER() OVER (
            PARTITION BY ri.ITEMNMBR, ri.LOT_NUMBER
            ORDER BY 
                CASE WHEN fg.FG_Item_Number IS NOT NULL THEN 0 ELSE 1 END,
                fg.FG_Item_Number
        ) AS FG_Priority
    FROM RawWCInventory ri
    LEFT JOIN FG_From_MO fg
        ON ri.LOT_NUMBER LIKE '%' + fg.CleanOrder + '%'
        OR fg.CleanOrder LIKE '%' + REPLACE(ri.LOT_NUMBER, '-', '') + '%'
),

ParsedInventory AS (
    SELECT
        -- Context columns preserved
        ii.client,
        ii.contract,
        ii.run,
        
        ii.ITEMNMBR,
        ii.LOT_NUMBER,
        ii.BIN,
        ii.LOCNCODE,
        ii.QTY_Available,
        CAST(ii.DATERECD AS DATE) AS Receipt_Date,
        COALESCE(
            TRY_CONVERT(DATE, ii.EXPNDATE),
            DATEADD(DAY, gsl.Default_WC_Shelf_Life_Days, CAST(ii.DATERECD AS DATE))
        ) AS Expiry_Date,
        DATEDIFF(DAY, CAST(ii.DATERECD AS DATE), CAST(GETDATE() AS DATE)) AS Batch_Age_Days,
        LEFT(ii.LOCNCODE, PATINDEX('%[-_]%', ii.LOCNCODE + '-') - 1) AS Client_ID,
        itm.ITEMDESC AS Item_Description,
        itm.UOMSCHDL AS Unit_Of_Measure,
        
        -- Suppression flag
        CAST(0 AS BIT) AS Is_Suppressed,
        
        -- FG SOURCE (PAB-style): Carried through from MO linkage
        ii.FG_Item_Number,
        ii.FG_Description,
        -- Construct SOURCE (PAB-style): Carried through from MO linkage
        ii.Construct
        
    FROM InventoryWithFG ii
    CROSS JOIN GlobalShelfLife gsl
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK)
        ON LTRIM(RTRIM(ii.ITEMNMBR)) = LTRIM(RTRIM(itm.ITEMNMBR))
    WHERE ii.FG_Priority = 1  -- Select best FG match per lot
      AND COALESCE(
            TRY_CONVERT(DATE, ii.EXPNDATE),
            DATEADD(DAY, gsl.Default_WC_Shelf_Life_Days, CAST(ii.DATERECD AS DATE))
          ) >= CAST(GETDATE() AS DATE)  -- Exclude expired
)

-- ============================================================
-- FINAL OUTPUT: 20 columns, planner-optimized order
-- LEFT → RIGHT = IDENTIFY → LOCATE → QUANTIFY → TIME → DECIDE → FG/CONSTRUCT
-- ============================================================
SELECT
    -- Context columns preserved
    client,
    contract,
    run,
    
    -- IDENTIFY (what item?) - 3 columns
    ITEMNMBR                AS Item_Number,
    Item_Description,
    Unit_Of_Measure,

    -- LOCATE (where is it?) - 4 columns
    Client_ID,
    LOCNCODE                AS Site,
    BIN                     AS Bin,
    LOT_NUMBER              AS Lot,

    -- QUANTIFY (how much?) - 2 columns
    QTY_Available           AS Quantity,
    QTY_Available           AS Usable_Qty,

    -- TIME (when relevant?) - 3 columns
    Receipt_Date,
    Expiry_Date,
    DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_To_Expiry,

    -- DECIDE (what action?) - 3 columns
    ROW_NUMBER() OVER (
        PARTITION BY client, contract, run, ITEMNMBR
        ORDER BY Expiry_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence,
    'WC_BATCH'              AS Batch_Type,
    
    -- Suppression flag
    Is_Suppressed,

    -- FG SOURCE (PAB-style): Exposed in final output
    FG_Item_Number,
    FG_Description,
    -- Construct SOURCE (PAB-style): Exposed in final output
    Construct

FROM ParsedInventory
WHERE Is_Suppressed = 0;

-- ============================================================================
-- END OF VIEW 05 (CONSOLIDATED FINAL)
-- ============================================================================
