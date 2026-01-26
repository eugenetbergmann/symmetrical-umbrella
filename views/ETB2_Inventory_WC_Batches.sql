-- ============================================================================
-- VIEW 2 of 6: ETB2_Inventory_WC_Batches
-- ENHANCEMENT: Add Item_Description and Unit_Of_Measure from IV00101
-- ============================================================================

CREATE OR ALTER VIEW dbo.ETB2_Inventory_WC_Batches AS

WITH GlobalShelfLife AS (
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
    LEFT JOIN dbo.EXT_BINTYPE ext ON pib.BINTYPE = ext.BINTYPE
    WHERE pib.LOCNCODE LIKE 'WC[_-]%'
      AND pib.QTY_Available > 0
      AND pib.LOT_NUMBER IS NOT NULL
      AND pib.LOT_NUMBER <> ''
),

ParsedInventory AS (
    SELECT
        ri.ITEMNMBR,
        ri.LOT_NUMBER,
        ri.BIN,
        ri.LOCNCODE,
        ri.QTY_Available,
        CAST(ri.DATERECD AS DATE) AS Receipt_Date,
        TRY_CONVERT(DATE, ri.EXPNDATE) AS Expiry_Date_Raw,
        COALESCE(
            TRY_CONVERT(DATE, ri.EXPNDATE),
            DATEADD(DAY, gsl.Default_WC_Shelf_Life_Days, CAST(ri.DATERECD AS DATE))
        ) AS Expiry_Date,
        DATEDIFF(DAY, CAST(ri.DATERECD AS DATE), CAST(GETDATE() AS DATE)) AS Batch_Age_Days,
        LEFT(ri.LOCNCODE, PATINDEX('%[-_]%', ri.LOCNCODE + '-') - 1) AS Client_ID,
        COALESCE(ri.Bin_Type_Raw, 'UNKNOWN') AS Bin_Type,
        itm.ITEMDESC AS Item_Description,
        itm.UOMSCHDL AS Unit_Of_Measure
    FROM RawWCInventory ri
    CROSS JOIN GlobalShelfLife gsl
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK)
        ON LTRIM(RTRIM(ri.ITEMNMBR)) = LTRIM(RTRIM(itm.ITEMNMBR))
)

-- ============================================================
-- FINAL OUTPUT: Planner-optimized column order
-- ============================================================
SELECT
    -- IDENTIFICATION (leftmost - what batch am I looking at?)
    CONCAT('WC-', LOCNCODE, '-', BIN, '-', ITEMNMBR, '-',
           CONVERT(VARCHAR(10), Receipt_Date, 120)) AS Batch_ID,
    ITEMNMBR                AS Item_Number,
    Item_Description,
    Unit_Of_Measure,
    
    -- LOCATION HIERARCHY (where is it?)
    Client_ID,
    LOCNCODE                AS Location_Code,
    BIN                     AS Bin_Location,
    Bin_Type,
    LOT_NUMBER              AS Lot_Number,
    
    -- QUANTITIES (how much?)
    QTY_Available           AS Available_Quantity,
    0                       AS Degraded_Quantity,
    QTY_Available           AS Usable_Quantity,
    
    -- TIME DIMENSIONS (when did it arrive, when expires?)
    Receipt_Date,
    Batch_Age_Days,
    Expiry_Date,
    DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_Until_Expiry,
    
    -- ALLOCATION LOGIC (use order)
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Expiry_Date ASC, Receipt_Date ASC
    ) AS FEFO_Sort_Priority,
    1                       AS Is_Eligible_For_Allocation,
    'WC_BATCH'              AS Inventory_Type
    
FROM ParsedInventory
WHERE Expiry_Date >= CAST(GETDATE() AS DATE)
ORDER BY
    Item_Number ASC,
    Expiry_Date ASC,
    Receipt_Date ASC,
    Batch_ID ASC;

GO

-- ============================================================================
-- TEST QUERY: Verify enhancement
-- ============================================================================
-- SELECT TOP 100 * FROM dbo.ETB2_Inventory_WC_Batches
-- WHERE Item_Description IS NOT NULL
-- ORDER BY Item_Number, FEFO_Sort_Priority;