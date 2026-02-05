/* VIEW 06 - STATUS: VALIDATED */
-- ============================================================================
-- VIEW 06: dbo.ETB2_Inventory_Quarantine_Restricted (CONSOLIDATED FINAL)
-- ============================================================================
-- Purpose: WFQ and RMQTY hold inventory with FG/Construct derivation
-- Grain: One row per item per hold type
-- Dependencies:
--   - dbo.IV00300 (external table)
--   - dbo.IV00101 (external table)
--   - dbo.ETB_ActiveDemand_Union_FG_MO (external table - FG SOURCE)
-- Features:
--   - Context columns: client, contract, run
--   - FG + Construct derived from ETB_ActiveDemand_Union_FG_MO via MO linkage
--   - Is_Suppressed flag
-- Last Updated: 2026-02-05
-- ============================================================================

WITH GlobalConfig AS (
    SELECT
        14 AS WFQ_Hold_Days,
        7 AS RMQTY_Hold_Days,
        90 AS Expiry_Filter_Days
),

-- ============================================================================
-- FG SOURCE (FIXED): Derive FG from ETB_ActiveDemand_Union_FG_MO
-- FIX: Uses correct source column names from ETB_ActiveDemand_Union_FG_MO
-- Schema Map: Customer->Construct, FG->FG_Item_Number, [FG Desc]->FG_Description
-- ============================================================================
FG_From_MO AS (
    SELECT
        m.MONumber AS ORDERNUMBER,
        -- Enforced Schema Map: FG -> FG_Item_Number
        m.FG AS FG_Item_Number,
        -- Enforced Schema Map: [FG Desc] -> FG_Description
        m.[FG Desc] AS FG_Description,
        -- Enforced Schema Map: Customer -> Construct
        m.Customer AS Construct,
        UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(m.MONumber, 'MO', ''),
                            '-', ''
                        ),
                        ' ', ''
                    ),
                    '/', ''
                ),
                '.', ''
            ),
            '#', ''
        ) AS CleanOrder
    FROM dbo.ETB_ActiveDemand_Union_FG_MO m WITH (NOLOCK)
    WHERE m.FG IS NOT NULL
      AND m.FG <> ''
),

RawWFQInventory AS (
    SELECT
        -- Context columns
        'DEFAULT_CLIENT' AS client,
        'DEFAULT_CONTRACT' AS contract,
        'CURRENT_RUN' AS run,

        inv.ITEMNMBR,
        inv.LOCNCODE,
        inv.RCTSEQNM,
        inv.LOTNUMBR,
        COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0) AS QTY_ON_HAND,
        inv.DATERECD,
        inv.EXPNDATE,
        itm.UOMSCHDL,
        itm.ITEMDESC
    FROM dbo.IV00300 inv WITH (NOLOCK)
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK) ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE TRIM(inv.LOCNCODE) = 'WF-Q'
      AND inv.ITEMNMBR NOT LIKE 'MO-%'
      AND (COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0)) <> 0
      AND (inv.EXPNDATE IS NULL
           OR inv.EXPNDATE > DATEADD(DAY, (SELECT Expiry_Filter_Days FROM GlobalConfig), GETDATE()))
      AND CAST(GETDATE() AS DATE) BETWEEN
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
),

RawRMQTYInventory AS (
    SELECT
        -- Context columns
        'DEFAULT_CLIENT' AS client,
        'DEFAULT_CONTRACT' AS contract,
        'CURRENT_RUN' AS run,

        inv.ITEMNMBR,
        inv.LOCNCODE,
        inv.RCTSEQNM,
        inv.LOTNUMBR,
        COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0) AS QTY_ON_HAND,
        inv.DATERECD,
        inv.EXPNDATE,
        itm.UOMSCHDL,
        itm.ITEMDESC
    FROM dbo.IV00300 inv WITH (NOLOCK)
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK) ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE TRIM(inv.LOCNCODE) = 'RMQTY'
      AND inv.ITEMNMBR NOT LIKE 'MO-%'
      AND (COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0)) <> 0
      AND (inv.EXPNDATE IS NULL
           OR inv.EXPNDATE > DATEADD(DAY, (SELECT Expiry_Filter_Days FROM GlobalConfig), GETDATE()))
      AND CAST(GETDATE() AS DATE) BETWEEN
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
),

-- ============================================================================
-- Link WFQ inventory to FG via Lot Number
-- ============================================================================
WFQWithFG AS (
    SELECT
        ri.client, ri.contract, ri.run,
        ri.ITEMNMBR, ri.LOCNCODE, ri.RCTSEQNM, ri.QTY_ON_HAND,
        ri.DATERECD, ri.EXPNDATE, ri.UOMSCHDL, ri.ITEMDESC,
        fg.FG_Item_Number, fg.FG_Description, fg.Construct,
        ROW_NUMBER() OVER (
            PARTITION BY ri.ITEMNMBR, ri.RCTSEQNM
            ORDER BY CASE WHEN fg.FG_Item_Number IS NOT NULL THEN 0 ELSE 1 END, fg.FG_Item_Number
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
        ri.client, ri.contract, ri.run,
        ri.ITEMNMBR, ri.LOCNCODE, ri.RCTSEQNM, ri.QTY_ON_HAND,
        ri.DATERECD, ri.EXPNDATE, ri.UOMSCHDL, ri.ITEMDESC,
        fg.FG_Item_Number, fg.FG_Description, fg.Construct,
        ROW_NUMBER() OVER (
            PARTITION BY ri.ITEMNMBR, ri.RCTSEQNM
            ORDER BY CASE WHEN fg.FG_Item_Number IS NOT NULL THEN 0 ELSE 1 END, fg.FG_Item_Number
        ) AS FG_Priority
    FROM RawRMQTYInventory ri
    LEFT JOIN FG_From_MO fg
        ON ri.LOTNUMBR LIKE '%' + fg.CleanOrder + '%'
        OR fg.CleanOrder LIKE '%' + REPLACE(ri.LOTNUMBR, '-', '') + '%'
),

ParsedWFQInventory AS (
    SELECT
        client, contract, run,
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
        CAST(0 AS BIT) AS Is_Suppressed,
        -- FG SOURCE (PAB-style)
        MAX(FG_Item_Number) AS FG_Item_Number,
        MAX(FG_Description) AS FG_Description,
        MAX(Construct) AS Construct
    FROM WFQWithFG
    WHERE FG_Priority = 1
    GROUP BY client, contract, run, ITEMNMBR, LOCNCODE
    HAVING SUM(QTY_ON_HAND) <> 0
),

ParsedRMQTYInventory AS (
    SELECT
        client, contract, run,
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
        CAST(0 AS BIT) AS Is_Suppressed,
        -- FG SOURCE (PAB-style)
        MAX(FG_Item_Number) AS FG_Item_Number,
        MAX(FG_Description) AS FG_Description,
        MAX(Construct) AS Construct
    FROM RMQTYWithFG
    WHERE FG_Priority = 1
    GROUP BY client, contract, run, ITEMNMBR, LOCNCODE
    HAVING SUM(QTY_ON_HAND) <> 0
)

-- ============================================================
-- FINAL OUTPUT: 19 columns with FG/Construct
-- ============================================================
SELECT
    client, contract, run,
    ITEMNMBR AS Item_Number,
    Item_Description,
    Unit_Of_Measure,
    LOCNCODE AS Site,
    Hold_Type,
    Available_Quantity AS Quantity,
    Available_Quantity AS Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    Age_Days,
    Release_Date,
    DATEDIFF(DAY, GETDATE(), Release_Date) AS Days_To_Release,
    Is_Released AS Can_Allocate,
    ROW_NUMBER() OVER (
        PARTITION BY client, contract, run, ITEMNMBR
        ORDER BY Release_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence,
    Is_Suppressed,
    -- FG SOURCE (PAB-style)
    FG_Item_Number,
    FG_Description,
    Construct
FROM ParsedWFQInventory
WHERE Is_Suppressed = 0

UNION ALL

SELECT
    client, contract, run,
    ITEMNMBR AS Item_Number,
    Item_Description,
    Unit_Of_Measure,
    LOCNCODE AS Site,
    Hold_Type,
    Available_Quantity AS Quantity,
    Available_Quantity AS Usable_Qty,
    Receipt_Date,
    Expiry_Date,
    Age_Days,
    Release_Date,
    DATEDIFF(DAY, GETDATE(), Release_Date) AS Days_To_Release,
    Is_Released AS Can_Allocate,
    ROW_NUMBER() OVER (
        PARTITION BY client, contract, run, ITEMNMBR
        ORDER BY Release_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence,
    Is_Suppressed,
    -- FG SOURCE (PAB-style)
    FG_Item_Number,
    FG_Description,
    Construct
FROM ParsedRMQTYInventory
WHERE Is_Suppressed = 0;

-- ============================================================================
-- END OF VIEW 06 (CONSOLIDATED FINAL)
-- ============================================================================
