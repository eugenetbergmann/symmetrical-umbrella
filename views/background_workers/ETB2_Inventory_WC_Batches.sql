-- ============================================================================
-- VIEW 1 of 6: ETB2_Inventory_WC_Batches
-- PURPOSE: Work Center batch inventory with FEFO ordering
-- PLANNER QUESTION: "What WC inventory do I have and when does it expire?"
-- SCREEN COLUMNS: 14 (fits 1920px)
-- ============================================================================

WITH GlobalShelfLife AS (
    SELECT 180 AS Default_WC_Shelf_Life_Days
),

RawWCInventory AS (
    SELECT
        pib.Item_Number AS ITEMNMBR,
        pib.LOT_NUMBER,
        pib.Bin AS BIN,
        pib.SITE AS LOCNCODE,
        pib.QTY_Available,
        pib.DATERECD,
        pib.EXPNDATE,
        ext.BINTYPE AS Bin_Type_Raw
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib
    LEFT JOIN dbo.EXT_BINTYPE ext ON pib.[QTY TYPE] = ext.BINTYPE
    WHERE pib.SITE LIKE 'WC[_-]%'
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
    WHERE COALESCE(
            TRY_CONVERT(DATE, ri.EXPNDATE),
            DATEADD(DAY, gsl.Default_WC_Shelf_Life_Days, CAST(ri.DATERECD AS DATE))
          ) >= CAST(GETDATE() AS DATE)  -- Exclude expired
)

-- ============================================================
-- FINAL OUTPUT: 14 columns, planner-optimized order
-- LEFT → RIGHT = IDENTIFY → LOCATE → QUANTIFY → TIME → DECIDE
-- ============================================================
SELECT
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
    
    -- DECIDE (what action?) - 2 columns
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Expiry_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence,
    'WC_BATCH'              AS Batch_Type
    
FROM ParsedInventory
ORDER BY
    Item_Number ASC,
    Use_Sequence ASC;


/*
-- Verify item descriptions populated
SELECT COUNT(*) AS Total_Batches,
       SUM(CASE WHEN Item_Description IS NOT NULL THEN 1 ELSE 0 END) AS With_Description,
       SUM(CASE WHEN Unit_Of_Measure IS NOT NULL THEN 1 ELSE 0 END) AS With_UOM
FROM dbo.ETB2_Inventory_WC_Batches;

-- Check expiry distribution
SELECT 
    CASE 
        WHEN Days_To_Expiry <= 30 THEN '0-30 days'
        WHEN Days_To_Expiry <= 60 THEN '31-60 days'
        WHEN Days_To_Expiry <= 90 THEN '61-90 days'
        ELSE '90+ days'
    END AS Expiry_Window,
    COUNT(*) AS Batch_Count,
    SUM(Quantity) AS Total_Quantity
FROM dbo.ETB2_Inventory_WC_Batches
GROUP BY 
    CASE 
        WHEN Days_To_Expiry <= 30 THEN '0-30 days'
        WHEN Days_To_Expiry <= 60 THEN '31-60 days'
        WHEN Days_To_Expiry <= 90 THEN '61-90 days'
        ELSE '90+ days'
    END
ORDER BY 1;

-- Sample output for planner review
SELECT TOP 20 * FROM dbo.ETB2_Inventory_WC_Batches 
ORDER BY Days_To_Expiry ASC;
*/