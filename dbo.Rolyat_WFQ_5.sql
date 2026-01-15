CREATE VIEW dbo.Rolyat_WFQ_5
AS
WITH WFQ_Data AS (
    -- WFQ (Quarantine) inventory from IV00300
    SELECT
        TRIM(inv.ITEMNMBR) AS ITEMNMBR,
        TRIM(inv.LOCNCODE) AS Site_ID,
        'WFQ' AS Inventory_Type,
        TRIM(inv.RCTSEQNM) AS Batch_ID,
        SUM(inv.QTYRECVD - inv.QTYSOLD) AS QTY_ON_HAND,
        MAX(CAST(inv.DATERECD AS date)) AS Receipt_Date,
        MAX(CAST(inv.EXPNDATE AS date)) AS Expiry_Date,
        TRIM(itm.UOMSCHDL) AS UOM,

        -- Calculate projected release date based on config
        DATEADD(day,
            CAST(dbo.fn_GetConfig(TRIM(inv.ITEMNMBR), NULL, 'WFQ_Hold_Days', GETDATE()) AS int),
            MAX(CAST(inv.DATERECD AS date))
        ) AS Projected_Release_Date,

        -- Age calculation
        DATEDIFF(day, MAX(CAST(inv.DATERECD AS date)), GETDATE()) AS Age_Days

    FROM dbo.IV00300 AS inv
    LEFT OUTER JOIN dbo.IV00101 AS itm
        ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE
        (inv.QTYRECVD - inv.QTYSOLD <> 0)
        AND TRIM(inv.LOCNCODE) IN (
            SELECT LOCNCODE
            FROM dbo.Rolyat_Site_Config
            WHERE Site_Type = 'WFQ' AND Active = 1
        )
        AND (inv.EXPNDATE IS NULL
             OR inv.EXPNDATE > DATEADD(DAY,
                 CAST(dbo.fn_GetConfig(TRIM(inv.ITEMNMBR), NULL, 'WFQ_Expiry_Filter_Days', GETDATE()) AS int),
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

RMQTY_Data AS (
    -- RMQTY (Restricted Material) inventory from IV00300
    SELECT
        TRIM(inv.ITEMNMBR) AS ITEMNMBR,
        TRIM(inv.LOCNCODE) AS Site_ID,
        'RMQTY' AS Inventory_Type,
        TRIM(inv.RCTSEQNM) AS Batch_ID,
        SUM(inv.QTYRECVD - inv.QTYSOLD) AS QTY_ON_HAND,
        MAX(CAST(inv.DATERECD AS date)) AS Receipt_Date,
        MAX(CAST(inv.EXPNDATE AS date)) AS Expiry_Date,
        TRIM(itm.UOMSCHDL) AS UOM,

        -- RMQTY eligibility date (different hold period than WFQ)
        DATEADD(day,
            CAST(dbo.fn_GetConfig(TRIM(inv.ITEMNMBR), NULL, 'RMQTY_Hold_Days', GETDATE()) AS int),
            MAX(CAST(inv.DATERECD AS date))
        ) AS Projected_Release_Date,

        DATEDIFF(day, MAX(CAST(inv.DATERECD AS date)), GETDATE()) AS Age_Days

    FROM dbo.IV00300 AS inv
    LEFT OUTER JOIN dbo.IV00101 AS itm
        ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE
        (inv.QTYRECVD - inv.QTYSOLD <> 0)
        AND TRIM(inv.LOCNCODE) IN (
            SELECT LOCNCODE
            FROM dbo.Rolyat_Site_Config
            WHERE Site_Type = 'RMQTY' AND Active = 1
        )
        AND (inv.EXPNDATE IS NULL
             OR inv.EXPNDATE > DATEADD(DAY,
                 CAST(dbo.fn_GetConfig(TRIM(inv.ITEMNMBR), NULL, 'RMQTY_Expiry_Filter_Days', GETDATE()) AS int),
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

-- Union and output
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
    DATEDIFF(day, GETDATE(), Projected_Release_Date) AS Days_Until_Release,

    -- Flag if eligible for release now
    CASE
        WHEN Projected_Release_Date <= GETDATE() THEN 1
        ELSE 0
    END AS Is_Eligible_For_Release,

    Age_Days,
    UOM,

    -- Row type
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
