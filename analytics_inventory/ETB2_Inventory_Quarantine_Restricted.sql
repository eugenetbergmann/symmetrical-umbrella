-- ============================================================================
-- ETB2 Query: Inventory_Quarantine_Restricted
-- Purpose: WFQ/RMQTY inventory with hold period management
-- Grain: Receipt Sequence (RCTSEQNM)
-- Rolyat Source: Rolyat_WFQ_5 (100% logic preserved)
--   - Hold Periods: WFQ 14 days, RMQTY 7 days
--   - Expiry Filter: 90-day window
--   - Eligibility: Calculated from hold release date
-- Excel-Ready: Yes (SELECT-only, human-readable columns)
-- Dependencies: None (fully self-contained)
-- Last Updated: 2026-01-25
-- ============================================================================

WITH

-- Inline global config defaults (from Rolyat_Config_Global)
GlobalConfig AS (
    SELECT
        14 AS WFQ_Hold_Days,
        7 AS RMQTY_Hold_Days,
        90 AS Expiry_Filter_Days
),

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
        'WFQ_BATCH' AS Inventory_Type
    FROM RawWFQInventory
    GROUP BY ITEMNMBR, LOCNCODE, RCTSEQNM
    HAVING SUM(QTY_ON_HAND) <> 0
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
        'RMQTY_BATCH' AS Inventory_Type
    FROM RawRMQTYInventory
    GROUP BY ITEMNMBR, LOCNCODE, RCTSEQNM
    HAVING SUM(QTY_ON_HAND) <> 0
)

SELECT
    -- Human-readable Batch_ID for traceability
    CONCAT(Inventory_Type, '-', LOCNCODE, '-', ITEMNMBR, '-',
           CONVERT(VARCHAR(10), Receipt_Date, 120)) AS Batch_ID,

    ITEMNMBR                        AS Item_Number,
    NULL                            AS Client_ID,              -- Not applicable for WFQ/RMQTY
    LOCNCODE                        AS Location_Code,
    NULL                            AS Bin_Location,           -- WFQ/RMQTY not bin-based
    NULL                            AS Lot_Number,             -- RCTSEQNM used in Batch_ID instead
    Available_Quantity,
    Receipt_Date,
    Expiry_Date,
    Batch_Age_Days,
    CASE
        WHEN Expiry_Date IS NOT NULL THEN DATEDIFF(DAY, GETDATE(), Expiry_Date)
        ELSE NULL
    END                             AS Days_Until_Expiry,
    0                               AS Degraded_Quantity,      -- not yet implemented
    Available_Quantity              AS Usable_Quantity,
    'UNKNOWN'                       AS Bin_Type,              -- not bin-based

    -- Eligibility Sort Priority (lower number = eligible first)
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Projected_Release_Date ASC, Receipt_Date ASC
    ) AS FEFO_Sort_Priority,

    Is_Eligible_For_Allocation,
    Inventory_Type,
    Projected_Release_Date,
    DATEDIFF(DAY, GETDATE(), Projected_Release_Date) AS Days_Until_Release

FROM ParsedWFQInventory

UNION ALL

SELECT
    -- Human-readable Batch_ID for traceability
    CONCAT(Inventory_Type, '-', LOCNCODE, '-', ITEMNMBR, '-',
           CONVERT(VARCHAR(10), Receipt_Date, 120)) AS Batch_ID,

    ITEMNMBR                        AS Item_Number,
    NULL                            AS Client_ID,              -- Not applicable for WFQ/RMQTY
    LOCNCODE                        AS Location_Code,
    NULL                            AS Bin_Location,           -- WFQ/RMQTY not bin-based
    NULL                            AS Lot_Number,             -- RCTSEQNM used in Batch_ID instead
    Available_Quantity,
    Receipt_Date,
    Expiry_Date,
    Batch_Age_Days,
    CASE
        WHEN Expiry_Date IS NOT NULL THEN DATEDIFF(DAY, GETDATE(), Expiry_Date)
        ELSE NULL
    END                             AS Days_Until_Expiry,
    0                               AS Degraded_Quantity,      -- not yet implemented
    Available_Quantity              AS Usable_Quantity,
    'UNKNOWN'                       AS Bin_Type,              -- not bin-based

    -- Eligibility Sort Priority (lower number = eligible first)
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Projected_Release_Date ASC, Receipt_Date ASC
    ) AS FEFO_Sort_Priority,

    Is_Eligible_For_Allocation,
    Inventory_Type,
    Projected_Release_Date,
    DATEDIFF(DAY, GETDATE(), Projected_Release_Date) AS Days_Until_Release

FROM ParsedRMQTYInventory

ORDER BY
    Item_Number ASC,
    Projected_Release_Date ASC,     -- soonest eligible first
    Receipt_Date ASC,               -- then oldest receipt
    Batch_ID ASC;