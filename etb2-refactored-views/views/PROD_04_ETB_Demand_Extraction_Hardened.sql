-- ============================================================================
-- SELECT: ETB Production Demand Extraction (Hardened)
-- ============================================================================
-- Purpose: Deterministic demand extraction from TRUE base objects
-- Base Objects: dbo.ETB_PAB, dbo.ETB_CLIENT, dbo.ETB_ActiveDemand_Union_FG_MO
-- Constraints:
--   - Single-pass normalization via CROSS APPLY
--   - OUTER APPLY with TOP (1) for deterministic FG linkage (no ROW_NUMBER)
--   - Strong typing at extraction edge (TRY_CAST, TRY_CONVERT)
--   - Filter order: convert types -> remove NULLs -> remove zero -> filter dates
-- ============================================================================

SELECT
    d.CleanOrder AS Order_Number,
    d.ITEMNMBR AS Item_Number,
    d.Due_Date,
    TRY_CONVERT(date, d.[Date + Expiry]) AS Expiry_Date,
    d.Raw_Demand,
    CASE WHEN d.Is_Suppressed = 1 THEN 0 ELSE d.Raw_Demand END AS Suppressed_Demand_Qty,
    fg.FG_Item_Code,
    fg.FG_Description,
    fg.Construct
FROM
(
    SELECT
        norm.CleanOrder,
        p.ITEMNMBR,
        TRY_CONVERT(date, p.DUEDATE) AS Due_Date,
        TRY_CAST(p.Deductions AS decimal(18,4)) AS Raw_Demand,
        p.[Date + Expiry],

        CASE 
            WHEN p.ITEMNMBR LIKE 'MO-%' THEN 1
            ELSE 0
        END AS Is_Suppressed

    FROM dbo.ETB_PAB p

    CROSS APPLY
    (
        SELECT CleanOrder =
            UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                p.ORDERNUMBER,'MO',''),'-',''),' ',''),'/',''),'.',''))
    ) norm

    WHERE
        p.MRPTYPE = 6
        AND p.STSDESCR <> 'Partially Received'
        AND p.ITEMNMBR NOT LIKE '60.%'
        AND p.ITEMNMBR NOT LIKE '70.%'
) d

OUTER APPLY
(
    SELECT TOP (1)
        u.FG AS FG_Item_Code,
        u.[FG Desc] AS FG_Description,
        u.Customer AS Construct

    FROM dbo.ETB_ActiveDemand_Union_FG_MO u

    CROSS APPLY
    (
        SELECT CleanOrder =
            UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                u.ORDERNUMBER,'MO',''),'-',''),' ',''),'/',''),'.',''))
    ) norm2

    WHERE
        norm2.CleanOrder = d.CleanOrder
        AND u.FG IS NOT NULL
        AND u.FG <> ''

    ORDER BY
        u.Customer,
        u.[FG Desc]
) fg

WHERE
    d.Due_Date IS NOT NULL
    AND d.Raw_Demand IS NOT NULL
    AND d.Raw_Demand <> 0;

-- ============================================================================
-- END OF SELECT
-- ============================================================================
