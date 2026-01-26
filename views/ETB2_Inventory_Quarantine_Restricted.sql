-- ============================================================================
-- VIEW 3 of 6: ETB2_Inventory_Quarantine_Restricted
-- ENHANCEMENT: Add Item_Description from IV00101
-- ============================================================================

CREATE OR ALTER VIEW dbo.ETB2_Inventory_Quarantine_Restricted AS

WITH GlobalConfig AS (
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
        itm.UOMSCHDL,
        itm.ITEMDESC
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
        itm.UOMSCHDL,
        itm.ITEMDESC
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
        MAX(ITEMDESC) AS Item_Description,
        MAX(UOMSCHDL) AS Unit_Of_Measure,
        LOCNCODE,
        RCTSEQNM,
        SUM(QTY_ON_HAND) AS Available_Quantity,
        MAX(CAST(DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, EXPNDATE)) AS Expiry_Date,
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
        MAX(ITEMDESC) AS Item_Description,
        MAX(UOMSCHDL) AS Unit_Of_Measure,
        LOCNCODE,
        RCTSEQNM,
        SUM(QTY_ON_HAND) AS Available_Quantity,
        MAX(CAST(DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, EXPNDATE)) AS Expiry_Date,
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

-- ============================================================
-- FINAL OUTPUT: Planner-optimized column order
-- ============================================================
SELECT
    -- IDENTIFICATION (leftmost - what batch?)
    CONCAT(Inventory_Type, '-', LOCNCODE, '-', ITEMNMBR, '-',
           CONVERT(VARCHAR(10), Receipt_Date, 120)) AS Batch_ID,
    ITEMNMBR                        AS Item_Number,
    Item_Description,
    Unit_Of_Measure,
    
    -- LOCATION (where is it held?)
    NULL                            AS Client_ID,
    LOCNCODE                        AS Location_Code,
    NULL                            AS Bin_Location,
    NULL                            AS Lot_Number,
    'UNKNOWN'                       AS Bin_Type,
    
    -- QUANTITIES (how much?)
    Available_Quantity,
    0                               AS Degraded_Quantity,
    Available_Quantity              AS Usable_Quantity,
    
    -- TIME DIMENSIONS (quarantine timing)
    Receipt_Date,
    Batch_Age_Days,
    Projected_Release_Date,
    DATEDIFF(DAY, GETDATE(), Projected_Release_Date) AS Days_Until_Release,
    Expiry_Date,
    CASE
        WHEN Expiry_Date IS NOT NULL THEN DATEDIFF(DAY, GETDATE(), Expiry_Date)
        ELSE NULL
    END                             AS Days_Until_Expiry,
    
    -- ALLOCATION LOGIC (eligibility and sort)
    Is_Eligible_For_Allocation,
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Projected_Release_Date ASC, Receipt_Date ASC
    ) AS FEFO_Sort_Priority,
    Inventory_Type

FROM ParsedWFQInventory

UNION ALL

SELECT
    CONCAT(Inventory_Type, '-', LOCNCODE, '-', ITEMNMBR, '-',
           CONVERT(VARCHAR(10), Receipt_Date, 120)) AS Batch_ID,
    ITEMNMBR                        AS Item_Number,
    Item_Description,
    Unit_Of_Measure,
    NULL                            AS Client_ID,
    LOCNCODE                        AS Location_Code,
    NULL                            AS Bin_Location,
    NULL                            AS Lot_Number,
    'UNKNOWN'                       AS Bin_Type,
    Available_Quantity,
    0                               AS Degraded_Quantity,
    Available_Quantity              AS Usable_Quantity,
    Receipt_Date,
    Batch_Age_Days,
    Projected_Release_Date,
    DATEDIFF(DAY, GETDATE(), Projected_Release_Date) AS Days_Until_Release,
    Expiry_Date,
    CASE
        WHEN Expiry_Date IS NOT NULL THEN DATEDIFF(DAY, GETDATE(), Expiry_Date)
        ELSE NULL
    END                             AS Days_Until_Expiry,
    Is_Eligible_For_Allocation,
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Projected_Release_Date ASC, Receipt_Date ASC
    ) AS FEFO_Sort_Priority,
    Inventory_Type

FROM ParsedRMQTYInventory

ORDER BY
    Item_Number ASC,
    Projected_Release_Date ASC,
    Receipt_Date ASC,
    Batch_ID ASC;

GO

-- ============================================================================
-- TEST QUERY: Verify enhancement
-- ============================================================================
-- SELECT TOP 100 * FROM dbo.ETB2_Inventory_Quarantine_Restricted
-- WHERE Item_Description IS NOT NULL
-- ORDER BY Item_Number, FEFO_Sort_Priority;