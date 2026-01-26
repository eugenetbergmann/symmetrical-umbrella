-- ============================================================================
-- ETB2 Query: Planning_Stockout_Risk
-- Purpose: ATP balance and shortage risk analysis
-- Grain: Item
-- Excel-Ready: Yes (SELECT-only, human-readable columns)
-- Excel-Ready: Yes (SELECT-only, human-readable columns)
-- Dependencies: None (fully self-contained)
-- Last Updated: 2026-01-25
-- ============================================================================

WITH

-- Configuration defaults (hold periods and WC shelf life)
Config AS (
    SELECT
        14 AS WFQ_Hold_Days,
        7  AS RMQTY_Hold_Days,
        180 AS WC_Shelf_Life_Days
),

-- Active site locations/patterns (expand VALUES with real codes)
SiteLocations AS (
    SELECT LOCNCODE, 'WFQ'   AS Site_Type FROM (VALUES ('WFQ-CA01'), ('WFQ-NY01')) AS s(LOCNCODE)
    UNION ALL
    SELECT LOCNCODE, 'RMQTY' AS Site_Type FROM (VALUES ('RMQTY-CA01'), ('RMQTY-NY01')) AS s(LOCNCODE)
),

-- WC Batches (exact preserved logic from T-003, always eligible)
WCBatches AS (
    SELECT
        CONCAT('WC-', pib.LOCNCODE, '-', pib.BIN, '-', pib.ITEMNMBR, '-', CONVERT(VARCHAR(10), CAST(pib.DATERECD AS DATE), 120)) AS Batch_ID,
        pib.ITEMNMBR AS Item_Number,
        pib.LOCNCODE AS Location_Code,
        'WC_BATCH' AS Inventory_Type,
        pib.QTY_Available AS Quantity_On_Hand,
        CAST(pib.DATERECD AS DATE) AS Receipt_Date,
        COALESCE(TRY_CONVERT(DATE, pib.EXPNDATE),
                 DATEADD(DAY, c.WC_Shelf_Life_Days, CAST(pib.DATERECD AS DATE))) AS Expiry_Date,
        DATEDIFF(DAY, CAST(pib.DATERECD AS DATE), CAST(GETDATE() AS DATE)) AS Age_Days,
        DATEDIFF(DAY, CAST(GETDATE() AS DATE),
                 COALESCE(TRY_CONVERT(DATE, pib.EXPNDATE),
                          DATEADD(DAY, c.WC_Shelf_Life_Days, CAST(pib.DATERECD AS DATE)))) AS Days_Until_Expiry,
        1 AS Is_Eligible_For_Release,
        1 AS Type_Priority  -- WC first
    FROM dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE pib
    CROSS JOIN Config c
    WHERE pib.LOCNCODE LIKE 'WC[_-]%'
      AND pib.QTY_Available > 0
      AND pib.LOT_NUMBER IS NOT NULL
      AND pib.LOT_NUMBER <> ''
),

-- WFQ and RMQTY Eligible Batches (preserved logic from T-004, but only eligible and no expiry filter)
HeldBatches AS (
    SELECT
        CONCAT(sl.Site_Type, '-', iv3.LOCNCODE, '-', iv3.RCTSEQNM, '-', CONVERT(VARCHAR(10), MAX(CAST(iv3.DATERECD AS DATE)), 120)) AS Batch_ID,
        iv3.ITEMNMBR AS Item_Number,
        iv3.LOCNCODE AS Location_Code,
        CASE sl.Site_Type WHEN 'WFQ' THEN 'WFQ_BATCH' ELSE 'RMQTY_BATCH' END AS Inventory_Type,
        CASE sl.Site_Type
            WHEN 'WFQ'   THEN MAX(COALESCE(iv3.ATYALLOC, 0))
            WHEN 'RMQTY' THEN MAX(COALESCE(iv3.QTY_RM_I, 0))
        END AS Quantity_On_Hand,
        MAX(CAST(iv3.DATERECD AS DATE)) AS Receipt_Date,
        MAX(TRY_CONVERT(DATE, iv3.EXPNDATE)) AS Expiry_Date,
        DATEDIFF(DAY, MAX(CAST(iv3.DATERECD AS DATE)), CAST(GETDATE() AS DATE)) AS Age_Days,
        DATEDIFF(DAY, CAST(GETDATE() AS DATE), MAX(TRY_CONVERT(DATE, iv3.EXPNDATE))) AS Days_Until_Expiry,
        CASE sl.Site_Type
            WHEN 'WFQ'   THEN c.WFQ_Hold_Days
            WHEN 'RMQTY' THEN c.RMQTY_Hold_Days
        END AS Hold_Days,
        CASE sl.Site_Type
            WHEN 'WFQ'   THEN 2
            WHEN 'RMQTY' THEN 3
        END AS Type_Priority
    FROM dbo.IV00300 iv3
    INNER JOIN dbo.IV00101 iv1 ON iv3.ITEMNMBR = iv1.ITEMNMBR
    INNER JOIN SiteLocations sl ON iv3.LOCNCODE = sl.LOCNCODE
    CROSS JOIN Config c
    GROUP BY iv3.ITEMNMBR, iv3.LOCNCODE, iv3.RCTSEQNM, sl.Site_Type
    HAVING
        CASE sl.Site_Type
            WHEN 'WFQ'   THEN MAX(COALESCE(iv3.ATYALLOC, 0))
            WHEN 'RMQTY' THEN MAX(COALESCE(iv3.QTY_RM_I, 0))
        END > 0
),

EligibleHeldBatches AS (
    SELECT
        Batch_ID,
        Item_Number,
        itm.ITEMDESC AS Item_Description,
        itm.UOMSCHDL AS Unit_Of_Measure,
        Location_Code,
        Inventory_Type,
        Quantity_On_Hand,
        Receipt_Date,
        Expiry_Date,
        Age_Days,
        Days_Until_Expiry,
        CASE
            WHEN DATEDIFF(DAY, CAST(GETDATE() AS DATE), DATEADD(DAY, Hold_Days, Receipt_Date)) <= 0
            THEN 1 ELSE 0
        END AS Is_Eligible_For_Release,
        Type_Priority
    FROM HeldBatches
    WHERE DATEDIFF(DAY, CAST(GETDATE() AS DATE), DATEADD(DAY, Hold_Days, Receipt_Date)) <= 0  -- only eligible
),

-- Union all eligible inventory
UnifiedEligible AS (
    SELECT * FROM WCBatches
    UNION ALL
    SELECT * FROM EligibleHeldBatches
)

SELECT
    Batch_ID,
    Item_Number,
    Location_Code,
    Inventory_Type,
    Quantity_On_Hand,
    Receipt_Date,
    Expiry_Date,
    Age_Days,
    Days_Until_Expiry,
    Is_Eligible_For_Release,  -- always 1 in this snapshot
    -- Unified FEFO-based sort priority (WC first, then by expiry)
    ROW_NUMBER() OVER (
        PARTITION BY Item_Number
        ORDER BY Type_Priority ASC, Expiry_Date ASC, Receipt_Date ASC
    ) AS Allocation_Sort_Priority
FROM UnifiedEligible
LEFT JOIN dbo.IV00101 itm WITH (NOLOCK)
    ON LTRIM(RTRIM(UnifiedEligible.Item_Number)) = LTRIM(RTRIM(itm.ITEMNMBR))
WHERE Quantity_On_Hand > 0  -- final safety filter
ORDER BY
    Item_Number ASC,
    Allocation_Sort_Priority ASC;