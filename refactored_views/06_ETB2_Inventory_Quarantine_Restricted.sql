-- ============================================================================
-- VIEW 06: dbo.ETB2_Inventory_Quarantine_Restricted
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire WITH...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Inventory_Quarantine_Restricted
-- ============================================================================
-- Purpose: WFQ/RMQTY inventory with hold period management
-- Grain: Item/Lot
-- Dependencies:
--   - dbo.IV00300 (Serial/Lot - external table)
--   - dbo.IV00101 (Item master - external table)
--   - dbo.ETB_PAB_MO (external table) - FG SOURCE (PAB-style)
-- Last Updated: 2026-01-30
-- ============================================================================

WITH GlobalConfig AS (
    SELECT
        14 AS WFQ_Hold_Days,
        7 AS RMQTY_Hold_Days,
        90 AS Expiry_Filter_Days
),

-- ============================================================================
-- FG SOURCE (PAB-style): Derive FG from ETB_PAB_MO
-- ============================================================================
FG_From_MO AS (
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

RawWFQInventory AS (
    SELECT
        inv.ITEMNMBR,
        inv.LOCNCODE,
        inv.RCTSEQNM,
        inv.LOTNUMBR,  -- Lot number for FG linking
        COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0) AS QTY_ON_HAND,
        inv.DATERECD,
        inv.EXPNDATE,
        itm.UOMSCHDL,
        itm.ITEMDESC
    FROM dbo.IV00300 inv WITH (NOLOCK)
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK) ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE TRIM(inv.LOCNCODE) = 'WF-Q'
      AND (COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0)) <> 0
      AND (inv.EXPNDATE IS NULL
           OR inv.EXPNDATE > DATEADD(DAY, (SELECT Expiry_Filter_Days FROM GlobalConfig), GETDATE()))
),

RawRMQTYInventory AS (
    SELECT
        inv.ITEMNMBR,
        inv.LOCNCODE,
        inv.RCTSEQNM,
        inv.LOTNUMBR,  -- Lot number for FG linking
        COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0) AS QTY_ON_HAND,
        inv.DATERECD,
        inv.EXPNDATE,
        itm.UOMSCHDL,
        itm.ITEMDESC
    FROM dbo.IV00300 inv WITH (NOLOCK)
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK) ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE TRIM(inv.LOCNCODE) = 'RMQTY'
      AND (COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0)) <> 0
      AND (inv.EXPNDATE IS NULL
           OR inv.EXPNDATE > DATEADD(DAY, (SELECT Expiry_Filter_Days FROM GlobalConfig), GETDATE()))
),

-- ============================================================================
-- Link WFQ inventory to FG via Lot Number
-- ============================================================================
WFQWithFG AS (
    SELECT
        ri.ITEMNMBR,
        ri.LOCNCODE,
        ri.RCTSEQNM,
        ri.QTY_ON_HAND,
        ri.DATERECD,
        ri.EXPNDATE,
        ri.UOMSCHDL,
        ri.ITEMDESC,
        fg.FG_Item_Number,
        fg.FG_Description,
        fg.Construct,
        ROW_NUMBER() OVER (
            PARTITION BY ri.ITEMNMBR, ri.RCTSEQNM
            ORDER BY 
                CASE WHEN fg.FG_Item_Number IS NOT NULL THEN 0 ELSE 1 END,
                fg.FG_Item_Number
        ) AS FG_Priority
    FROM RawWFQInventory ri
    LEFT JOIN FG_From_MO fg
        ON ri.LOTNUMBR LIKE '%' + fg.CleanOrder + '%'
        OR fg.CleanOrder LIKE '%' + REPLACE(ri.LOTNUMBR, '-', '') + '%'
),

-- ============================================================================
-- Link RMQTY inventory to FG via Lot Number
-- ============================================================================
RMQTYWithFG AS (
    SELECT
        ri.ITEMNMBR,
        ri.LOCNCODE,
        ri.RCTSEQNM,
        ri.QTY_ON_HAND,
        ri.DATERECD,
        ri.EXPNDATE,
        ri.UOMSCHDL,
        ri.ITEMDESC,
        fg.FG_Item_Number,
        fg.FG_Description,
        fg.Construct,
        ROW_NUMBER() OVER (
            PARTITION BY ri.ITEMNMBR, ri.RCTSEQNM
            ORDER BY 
                CASE WHEN fg.FG_Item_Number IS NOT NULL THEN 0 ELSE 1 END,
                fg.FG_Item_Number
        ) AS FG_Priority
    FROM RawRMQTYInventory ri
    LEFT JOIN FG_From_MO fg
        ON ri.LOTNUMBR LIKE '%' + fg.CleanOrder + '%'
        OR fg.CleanOrder LIKE '%' + REPLACE(ri.LOTNUMBR, '-', '') + '%'
),

ParsedWFQInventory AS (
    SELECT
        ITEMNMBR,
        MAX(ITEMDESC) AS Item_Description,
        MAX(UOMSCHDL) AS Unit_Of_Measure,
        LOCNCODE,
        SUM(QTY_ON_HAND) AS Available_Quantity,
        MAX(CAST(DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, EXPNDATE)) AS Expiry_Date,
        DATEADD(DAY, (SELECT WFQ_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) AS Release_Date,
        DATEDIFF(DAY, MAX(CAST(DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Age_Days,
        CASE
            WHEN DATEADD(DAY, (SELECT WFQ_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) <= GETDATE()
            THEN 1 ELSE 0
        END AS Is_Released,
        'WFQ' AS Hold_Type,
        -- FG SOURCE (PAB-style): Carried through from MO linkage
        MAX(FG_Item_Number) AS FG_Item_Number,
        MAX(FG_Description) AS FG_Description,
        MAX(Construct) AS Construct
    FROM WFQWithFG
    WHERE FG_Priority = 1
    GROUP BY ITEMNMBR, LOCNCODE
    HAVING SUM(QTY_ON_HAND) <> 0
),

ParsedRMQTYInventory AS (
    SELECT
        ITEMNMBR,
        MAX(ITEMDESC) AS Item_Description,
        MAX(UOMSCHDL) AS Unit_Of_Measure,
        LOCNCODE,
        SUM(QTY_ON_HAND) AS Available_Quantity,
        MAX(CAST(DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, EXPNDATE)) AS Expiry_Date,
        DATEADD(DAY, (SELECT RMQTY_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) AS Release_Date,
        DATEDIFF(DAY, MAX(CAST(DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Age_Days,
        CASE
            WHEN DATEADD(DAY, (SELECT RMQTY_Hold_Days FROM GlobalConfig), MAX(CAST(DATERECD AS DATE))) <= GETDATE()
            THEN 1 ELSE 0
        END AS Is_Released,
        'RMQTY' AS Hold_Type,
        -- FG SOURCE (PAB-style): Carried through from MO linkage
        MAX(FG_Item_Number) AS FG_Item_Number,
        MAX(FG_Description) AS FG_Description,
        MAX(Construct) AS Construct
    FROM RMQTYWithFG
    WHERE FG_Priority = 1
    GROUP BY ITEMNMBR, LOCNCODE
    HAVING SUM(QTY_ON_HAND) <> 0
)

-- ============================================================
-- FINAL OUTPUT: 16 columns, planner-optimized order
-- ============================================================
SELECT
    -- IDENTIFY (what item?) - 3 columns
    ITEMNMBR                AS Item_Number,
    Item_Description,
    Unit_Of_Measure,

    -- LOCATE (where is it?) - 2 columns
    LOCNCODE                AS Site,
    Hold_Type,

    -- QUANTIFY (how much?) - 2 columns
    Available_Quantity      AS Quantity,
    Available_Quantity      AS Usable_Qty,

    -- TIME (when relevant?) - 4 columns
    Receipt_Date,
    Expiry_Date,
    Age_Days,
    Release_Date,
    DATEDIFF(DAY, GETDATE(), Release_Date) AS Days_To_Release,

    -- DECIDE (what action?) - 2 columns
    Is_Released             AS Can_Allocate,
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Release_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence,

    -- FG SOURCE (PAB-style): Exposed in final output
    FG_Item_Number,
    FG_Description,
    -- Construct SOURCE (PAB-style): Exposed in final output
    Construct

FROM ParsedWFQInventory

UNION ALL

SELECT
    ITEMNMBR                AS Item_Number,
    Item_Description,
    Unit_Of_Measure,
    LOCNCODE                AS Site,
    Hold_Type,
    Available_Quantity      AS Quantity,
    Available_Quantity      AS Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    Age_Days,
    Release_Date,
    DATEDIFF(DAY, GETDATE(), Release_Date) AS Days_To_Release,
    Is_Released             AS Can_Allocate,
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Release_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence,
    -- FG SOURCE (PAB-style): Exposed in final output
    FG_Item_Number,
    FG_Description,
    -- Construct SOURCE (PAB-style): Exposed in final output
    Construct

FROM ParsedRMQTYInventory;

-- ============================================================================
-- END OF VIEW 06
-- ============================================================================
