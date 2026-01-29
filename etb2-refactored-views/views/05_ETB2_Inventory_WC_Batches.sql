-- ============================================================================
-- VIEW 05: dbo.ETB2_Inventory_WC_Batches (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Work Center batch inventory with FEFO ordering
-- Grain: Batch/Lot
-- Dependencies:
--   - dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (external table)
--   - dbo.EXT_BINTYPE (external table)
--   - dbo.IV00101 (Item master - external table)
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all GROUP BY clauses
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window: ±90 days
--   - Added context to ROW_NUMBER PARTITION BY
-- Last Updated: 2026-01-29
-- ============================================================================

WITH GlobalShelfLife AS (
    SELECT 180 AS Default_WC_Shelf_Life_Days
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
      AND pib.Item_Number NOT LIKE 'MO-%'  -- Filter out MO- conflated items
      AND CAST(GETDATE() AS DATE) BETWEEN 
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
),

ParsedInventory AS (
    SELECT
        -- Context columns preserved
        ri.client,
        ri.contract,
        ri.run,
        
        ri.ITEMNMBR,
        ri.LOT_NUMBER,
        ri.BIN,
        ri.LOCNCODE,
        ri.QTY_Available,
        CAST(ri.DATERECD AS DATE) AS Receipt_Date,
        COALESCE(
            TRY_CONVERT(DATE, ri.EXPNDATE),
            DATEADD(DAY, gsl.Default_WC_Shelf_Life_Days, CAST(ri.DATERECD AS DATE))
        ) AS Expiry_Date,
        DATEDIFF(DAY, CAST(ri.DATERECD AS DATE), CAST(GETDATE() AS DATE)) AS Batch_Age_Days,
        LEFT(ri.LOCNCODE, PATINDEX('%[-_]%', ri.LOCNCODE + '-') - 1) AS Client_ID,
        itm.ITEMDESC AS Item_Description,
        itm.UOMSCHDL AS Unit_Of_Measure,
        
        -- Suppression flag
        CAST(0 AS BIT) AS Is_Suppressed
        
    FROM RawWCInventory ri
    CROSS JOIN GlobalShelfLife gsl
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK)
        ON LTRIM(RTRIM(ri.ITEMNMBR)) = LTRIM(RTRIM(itm.ITEMNMBR))
    WHERE COALESCE(
            TRY_CONVERT(DATE, ri.EXPNDATE),
            DATEADD(DAY, gsl.Default_WC_Shelf_Life_Days, CAST(ri.DATERECD AS DATE))
          ) >= CAST(GETDATE() AS DATE)  -- Exclude expired
)

-- ============================================================
-- FINAL OUTPUT: 17 columns, planner-optimized order
-- LEFT → RIGHT = IDENTIFY → LOCATE → QUANTIFY → TIME → DECIDE
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
    QTY_Available           AS Usable_Qty,  -- Same for WC (no degradation yet)

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
    Is_Suppressed

FROM ParsedInventory
WHERE Is_Suppressed = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 05 (REFACTORED)
-- ============================================================================