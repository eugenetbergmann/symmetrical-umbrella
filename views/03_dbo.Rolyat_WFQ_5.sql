/*
================================================================================
View: dbo.Rolyat_WFQ_5
Description: WFQ (Quarantine) and RMQTY (Restricted Material) inventory tracking
Version: 1.0.0
Last Modified: 2026-01-16
Dependencies: 
  - dbo.IV00300 (Inventory Lot Master)
  - dbo.IV00101 (Item Master)
  - dbo.Rolyat_Site_Config (Site configuration)
  - dbo.fn_GetConfig (Configuration function)

Purpose:
  - Tracks WFQ (quarantine) inventory with projected release dates
  - Tracks RMQTY (restricted material) inventory with eligibility dates
  - Calculates age and release eligibility for each batch
  - Provides unified view of alternate stock sources

Business Rules:
  - WFQ batches have configurable hold periods before release
  - RMQTY batches have separate hold period configuration
  - Expiry filtering excludes soon-to-expire inventory
  - Is_Eligible_For_Release flag indicates immediate availability
================================================================================
*/

CREATE VIEW dbo.Rolyat_WFQ_5
AS

-- ============================================================
-- CTE 1: WFQ (Quarantine) Inventory
-- ============================================================
WITH WFQ_Data AS (
    SELECT
        TRIM(inv.ITEMNMBR) AS ITEMNMBR,
        TRIM(inv.LOCNCODE) AS Site_ID,
        'WFQ' AS Inventory_Type,
        TRIM(inv.RCTSEQNM) AS Batch_ID,
        SUM(inv.QTYRECVD - inv.QTYSOLD) AS QTY_ON_HAND,
        MAX(CAST(inv.DATERECD AS DATE)) AS Receipt_Date,
        MAX(CAST(inv.EXPNDATE AS DATE)) AS Expiry_Date,
        TRIM(itm.UOMSCHDL) AS UOM,

        -- Projected release date based on configurable hold period
        DATEADD(DAY,
            CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = TRIM(inv.ITEMNMBR) AND Config_Key = 'WFQ_Hold_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'WFQ_Hold_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS INT),
            MAX(CAST(inv.DATERECD AS DATE))
        ) AS Projected_Release_Date,

        -- Age calculation in days
        DATEDIFF(DAY, MAX(CAST(inv.DATERECD AS DATE)), GETDATE()) AS Age_Days

    FROM dbo.IV00300 AS inv
    LEFT OUTER JOIN dbo.IV00101 AS itm
        ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE
        -- Non-zero quantity
        (inv.QTYRECVD - inv.QTYSOLD <> 0)
        -- WFQ site locations only
        AND TRIM(inv.LOCNCODE) IN (
            SELECT LOCNCODE
            FROM dbo.Rolyat_Site_Config
            WHERE Site_Type = 'WFQ' AND Active = 1
        )
        -- Expiry filter: exclude soon-to-expire inventory
        AND (inv.EXPNDATE IS NULL
             OR inv.EXPNDATE > DATEADD(DAY,
                 CAST(COALESCE(
                     (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = TRIM(inv.ITEMNMBR) AND Config_Key = 'WFQ_Expiry_Filter_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                     (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'WFQ_Expiry_Filter_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                 ) AS INT),
                 GETDATE()
             )
        )
    GROUP BY
        TRIM(inv.ITEMNMBR),
        TRIM(inv.LOCNCODE),
        TRIM(inv.RCTSEQNM),
        TRIM(itm.UOMSCHDL)
    HAVING
        (SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0)
),

-- ============================================================
-- CTE 2: RMQTY (Restricted Material) Inventory
-- ============================================================
RMQTY_Data AS (
    SELECT
        TRIM(inv.ITEMNMBR) AS ITEMNMBR,
        TRIM(inv.LOCNCODE) AS Site_ID,
        'RMQTY' AS Inventory_Type,
        TRIM(inv.RCTSEQNM) AS Batch_ID,
        SUM(inv.QTYRECVD - inv.QTYSOLD) AS QTY_ON_HAND,
        MAX(CAST(inv.DATERECD AS DATE)) AS Receipt_Date,
        MAX(CAST(inv.EXPNDATE AS DATE)) AS Expiry_Date,
        TRIM(itm.UOMSCHDL) AS UOM,

        -- RMQTY eligibility date (different hold period than WFQ)
        DATEADD(DAY,
            CAST(COALESCE(
                (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = TRIM(inv.ITEMNMBR) AND Config_Key = 'RMQTY_Hold_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'RMQTY_Hold_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
            ) AS INT),
            MAX(CAST(inv.DATERECD AS DATE))
        ) AS Projected_Release_Date,

        -- Age calculation in days
        DATEDIFF(DAY, MAX(CAST(inv.DATERECD AS DATE)), GETDATE()) AS Age_Days

    FROM dbo.IV00300 AS inv
    LEFT OUTER JOIN dbo.IV00101 AS itm
        ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE
        -- Non-zero quantity
        (inv.QTYRECVD - inv.QTYSOLD <> 0)
        -- RMQTY site locations only
        AND TRIM(inv.LOCNCODE) IN (
            SELECT LOCNCODE
            FROM dbo.Rolyat_Site_Config
            WHERE Site_Type = 'RMQTY' AND Active = 1
        )
        -- Expiry filter: exclude soon-to-expire inventory
        AND (inv.EXPNDATE IS NULL
             OR inv.EXPNDATE > DATEADD(DAY,
                 CAST(COALESCE(
                     (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = TRIM(inv.ITEMNMBR) AND Config_Key = 'RMQTY_Expiry_Filter_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
                     (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'RMQTY_Expiry_Filter_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
                 ) AS INT),
                 GETDATE()
             )
        )
    GROUP BY
        TRIM(inv.ITEMNMBR),
        TRIM(inv.LOCNCODE),
        TRIM(inv.RCTSEQNM),
        TRIM(itm.UOMSCHDL)
    HAVING
        (SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0)
)

-- ============================================================
-- Final SELECT: Union WFQ and RMQTY with calculated fields
-- ============================================================
SELECT
    ITEMNMBR,
    Site_ID,
    Inventory_Type,
    Batch_ID,
    QTY_ON_HAND,
    Receipt_Date,
    Expiry_Date,
    Projected_Release_Date,

    -- Days until projected release (negative = already eligible)
    DATEDIFF(DAY, GETDATE(), Projected_Release_Date) AS Days_Until_Release,

    -- Flag if eligible for release now
    CASE
        WHEN Projected_Release_Date <= GETDATE() THEN 1
        ELSE 0
    END AS Is_Eligible_For_Release,

    Age_Days,
    UOM,

    -- Row type for identification
    CASE
        WHEN Inventory_Type = 'WFQ' THEN 'WFQ_BATCH'
        WHEN Inventory_Type = 'RMQTY' THEN 'RMQTY_BATCH'
    END AS Row_Type

FROM (
    SELECT * FROM WFQ_Data
    UNION ALL
    SELECT * FROM RMQTY_Data
) combined

GO

-- Add extended property for documentation
EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'WFQ and RMQTY inventory view with projected release dates, eligibility flags, and age tracking. Provides unified alternate stock visibility.',
    @level0type = N'SCHEMA', @level0name = 'dbo',
    @level1type = N'VIEW', @level1name = 'Rolyat_WFQ_5'
GO
