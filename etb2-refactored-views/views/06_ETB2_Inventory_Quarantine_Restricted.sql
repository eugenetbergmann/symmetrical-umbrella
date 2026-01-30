-- ============================================================================
-- VIEW 06: dbo.ETB2_Inventory_Quarantine_Restricted (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: WFQ/RMQTY inventory with hold period management
-- Grain: Item/Lot
-- Dependencies:
--   - dbo.IV00300 (Serial/Lot - external table)
--   - dbo.IV00101 (Item master - external table)
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all GROUP BY clauses
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window: ±90 days
--   - Added context to ROW_NUMBER PARTITION BY
--   - Context preserved in all UNION parts
-- Last Updated: 2026-01-29
-- ============================================================================

WITH GlobalConfig AS (
    SELECT
        14 AS WFQ_Hold_Days,
        7 AS RMQTY_Hold_Days,
        90 AS Expiry_Filter_Days
),

RawWFQInventory AS (
    SELECT
        -- Context columns
        'DEFAULT_CLIENT' AS client,
        'DEFAULT_CONTRACT' AS contract,
        'CURRENT_RUN' AS run,
        
        inv.ITEMNMBR AS item_number,
        NULL AS customer_number,
        inv.LOCNCODE,
        inv.RCTSEQNM,
        COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0) AS QTY_ON_HAND,
        inv.DATERECD,
        inv.EXPNDATE,
        itm.UOMSCHDL,
        itm.ITEMDESC
    FROM dbo.IV00300 inv WITH (NOLOCK)
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK) ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE TRIM(inv.LOCNCODE) = 'WF-Q'
      AND inv.ITEMNMBR NOT LIKE 'MO-%'  -- Filter out MO- conflated items
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
        
        inv.ITEMNMBR AS item_number,
        NULL AS customer_number,
        inv.LOCNCODE,
        inv.RCTSEQNM,
        COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0) AS QTY_ON_HAND,
        inv.DATERECD,
        inv.EXPNDATE,
        itm.UOMSCHDL,
        itm.ITEMDESC
    FROM dbo.IV00300 inv WITH (NOLOCK)
    LEFT JOIN dbo.IV00101 itm WITH (NOLOCK) ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE TRIM(inv.LOCNCODE) = 'RMQTY'
      AND inv.ITEMNMBR NOT LIKE 'MO-%'  -- Filter out MO- conflated items
      AND (COALESCE(TRY_CAST(inv.QTYRECVD AS DECIMAL(18,4)), 0) - COALESCE(TRY_CAST(inv.QTYSOLD AS DECIMAL(18,4)), 0)) <> 0
      AND (inv.EXPNDATE IS NULL
           OR inv.EXPNDATE > DATEADD(DAY, (SELECT Expiry_Filter_Days FROM GlobalConfig), GETDATE()))
      AND CAST(GETDATE() AS DATE) BETWEEN 
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
),

ParsedWFQInventory AS (
    SELECT
        -- Context columns preserved
        client,
        contract,
        run,
        
        item_number,
        customer_number,
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
        
        -- Suppression flag
        CAST(0 AS BIT) AS Is_Suppressed
        
    FROM RawWFQInventory
    GROUP BY client, contract, run, item_number, customer_number, LOCNCODE
    HAVING SUM(QTY_ON_HAND) <> 0
),

ParsedRMQTYInventory AS (
    SELECT
        -- Context columns preserved
        client,
        contract,
        run,
        
        item_number,
        customer_number,
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
        
        -- Suppression flag
        CAST(0 AS BIT) AS Is_Suppressed
        
    FROM RawRMQTYInventory
    GROUP BY client, contract, run, item_number, customer_number, LOCNCODE
    HAVING SUM(QTY_ON_HAND) <> 0
)

-- ============================================================
-- FINAL OUTPUT: 16 columns, planner-optimized order
-- Context preserved in all UNION parts
-- ============================================================
SELECT
    -- Context columns preserved
    client,
    contract,
    run,
    
    -- IDENTIFY (what item?) - 3 columns
    item_number,
    customer_number,
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

    -- DECIDE (what action?) - 3 columns
    Is_Released             AS Can_Allocate,
    ROW_NUMBER() OVER (
        PARTITION BY client, contract, run, item_number, customer_number
        ORDER BY Release_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence,
    
    -- Suppression flag
    Is_Suppressed

FROM ParsedWFQInventory
WHERE Is_Suppressed = 0

UNION ALL

SELECT
    -- Context columns preserved
    client,
    contract,
    run,
    
    item_number,
    customer_number,
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
        PARTITION BY client, contract, run, item_number, customer_number
        ORDER BY Release_Date ASC, Receipt_Date ASC
    ) AS Use_Sequence,
    
    -- Suppression flag
    Is_Suppressed

FROM ParsedRMQTYInventory
WHERE Is_Suppressed = 0;

-- ============================================================================
-- END OF VIEW 06 (REFACTORED)
-- ============================================================================