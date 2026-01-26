-- ============================================================================
-- VIEW 3 of 6: ETB2_Inventory_Unified_Eligible
-- PURPOSE: All eligible inventory consolidated (WC + released holds)
-- PLANNER QUESTION: "What can I allocate right now across all sites?"
-- SCREEN COLUMNS: 12 (fits 1920px)
-- ============================================================================

CREATE OR ALTER VIEW dbo.ETB2_Inventory_Unified_Eligible AS

WITH GlobalConfig AS (
    SELECT
        180 AS WC_Shelf_Life_Days,
        14 AS WFQ_Hold_Days,
        7 AS RMQTY_Hold_Days
),

-- WC Batches (always eligible)
WCInventory AS (
    SELECT
        pib.ITEMNMBR            AS Item_Number,
        itm.ITEMDESC            AS Item_Description,
        itm.UOMSCHDL            AS Unit_Of_Measure,
        pib.LOCNCODE            AS Site,
        'WC'                    AS Site_Type,
        pib.QTY_Available       AS Quantity,
        CAST(pib.DATERECD AS DATE) AS Receipt_Date,
        COALESCE(
            TRY_CONVERT(DATE, pib.EXPNDATE),
            DATEADD(DAY, (SELECT WC_Shelf_Life_Days FROM GlobalConfig), CAST(pib.DATERECD AS DATE))
        ) AS Expiry_Date,
        1 AS Allocation_Priority  -- WC first
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK)
        ON LTRIM(RTRIM(pib.ITEMNMBR)) = LTRIM(RTRIM(itm.ITEMNMBR))
    WHERE pib.LOCNCODE LIKE 'WC[_-]%'
      AND pib.QTY_Available > 0
      AND pib.LOT_NUMBER IS NOT NULL
      AND pib.LOT_NUMBER <> ''
      AND COALESCE(
            TRY_CONVERT(DATE, pib.EXPNDATE),
            DATEADD(DAY, (SELECT WC_Shelf_Life_Days FROM GlobalConfig), CAST(pib.DATERECD AS DATE))
          ) >= CAST(GETDATE() AS DATE)
),

-- WFQ Batches (released only)
WFQInventory AS (
    SELECT
        inv.ITEMNMBR            AS Item_Number,
        itm.ITEMDESC            AS Item_Description,
        itm.UOMSCHDL            AS Unit_Of_Measure,
        inv.LOCNCODE            AS Site,
        'WFQ'                   AS Site_Type,
        SUM(inv.QTYRECVD - inv.QTYSOLD) AS Quantity,
        MAX(CAST(inv.DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, inv.EXPNDATE)) AS Expiry_Date,
        2 AS Allocation_Priority  -- After WC
    FROM dbo.IV00300 inv
    LEFT JOIN dbo.IV00101 itm ON inv.ITEMNMBR = itm.ITEMNMBR
    CROSS JOIN GlobalConfig cfg
    WHERE TRIM(inv.LOCNCODE) = 'WF-Q'
      AND (inv.QTYRECVD - inv.QTYSOLD) > 0
    GROUP BY inv.ITEMNMBR, inv.LOCNCODE, itm.ITEMDESC, itm.UOMSCHDL
    HAVING DATEADD(DAY, cfg.WFQ_Hold_Days, MAX(CAST(inv.DATERECD AS DATE))) <= GETDATE()
),

-- RMQTY Batches (released only)
RMQTYInventory AS (
    SELECT
        inv.ITEMNMBR            AS Item_Number,
        itm.ITEMDESC            AS Item_Description,
        itm.UOMSCHDL            AS Unit_Of_Measure,
        inv.LOCNCODE            AS Site,
        'RMQTY'                 AS Site_Type,
        SUM(inv.QTYRECVD - inv.QTYSOLD) AS Quantity,
        MAX(CAST(inv.DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, inv.EXPNDATE)) AS Expiry_Date,
        3 AS Allocation_Priority  -- After WFQ
    FROM dbo.IV00300 inv
    LEFT JOIN dbo.IV00101 itm ON inv.ITEMNMBR = itm.ITEMNMBR
    CROSS JOIN GlobalConfig cfg
    WHERE TRIM(inv.LOCNCODE) = 'RMQTY'
      AND (inv.QTYRECVD - inv.QTYSOLD) > 0
    GROUP BY inv.ITEMNMBR, inv.LOCNCODE, itm.ITEMDESC, itm.UOMSCHDL
    HAVING DATEADD(DAY, cfg.RMQTY_Hold_Days, MAX(CAST(inv.DATERECD AS DATE))) <= GETDATE()
)

-- ============================================================
-- FINAL OUTPUT: 12 columns, planner-optimized order
-- ============================================================
SELECT
    -- IDENTIFY (what item?) - 3 columns
    Item_Number,
    Item_Description,
    Unit_Of_Measure,
    
    -- LOCATE (where is it?) - 2 columns
    Site,
    Site_Type,
    
    -- QUANTIFY (how much?) - 2 columns
    Quantity,
    Quantity                AS Usable_Qty,
    
    -- TIME (when relevant?) - 3 columns
    Receipt_Date,
    Expiry_Date,
    DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_To_Expiry,
    
    -- DECIDE (what action?) - 2 columns
    Allocation_Priority,
    ROW_NUMBER() OVER (
        PARTITION BY Item_Number
        ORDER BY Allocation_Priority ASC, Expiry_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence

FROM WCInventory

UNION ALL

SELECT
    Item_Number,
    Item_Description,
    Unit_Of_Measure,
    Site,
    Site_Type,
    Quantity,
    Quantity                AS Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_To_Expiry,
    Allocation_Priority,
    ROW_NUMBER() OVER (
        PARTITION BY Item_Number
        ORDER BY Allocation_Priority ASC, Expiry_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence

FROM WFQInventory

UNION ALL

SELECT
    Item_Number,
    Item_Description,
    Unit_Of_Measure,
    Site,
    Site_Type,
    Quantity,
    Quantity                AS Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    DATEDIFF(DAY, GETDATE(), Expiry_Date) AS Days_To_Expiry,
    Allocation_Priority,
    ROW_NUMBER() OVER (
        PARTITION BY Item_Number
        ORDER BY Allocation_Priority ASC, Expiry_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence

FROM RMQTYInventory

ORDER BY
    Item_Number ASC,
    Allocation_Priority ASC,
    Use_Sequence ASC;

GO

-- ============================================================
-- TEST QUERIES
-- ============================================================
/*
-- Inventory distribution by site type
SELECT Site_Type,
       COUNT(DISTINCT Item_Number) AS Unique_Items,
       SUM(Quantity) AS Total_Quantity
FROM dbo.ETB2_Inventory_Unified_Eligible
GROUP BY Site_Type
ORDER BY Allocation_Priority;

-- Items with multi-site inventory
SELECT Item_Number, Item_Description,
       COUNT(DISTINCT Site_Type) AS Site_Types,
       SUM(Quantity) AS Total_Available
FROM dbo.ETB2_Inventory_Unified_Eligible
GROUP BY Item_Number, Item_Description
HAVING COUNT(DISTINCT Site_Type) > 1;
*/