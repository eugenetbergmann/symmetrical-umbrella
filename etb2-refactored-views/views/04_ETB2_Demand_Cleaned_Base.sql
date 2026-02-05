/* VIEW 04 - STATUS: VALIDATED */
-- ============================================================================
-- VIEW 04: dbo.ETB2_Demand_Cleaned_Base (CONSOLIDATED FINAL)
-- ============================================================================
-- Purpose: Cleaned and normalized demand data with FG derivation
-- Grain: One row per demand event (order line)
-- Dependencies:
--   - dbo.ETB_PAB_AUTO (external table)
--   - dbo.Prosenthal_Vendor_Items (external table)
--   - dbo.ETB_CLIENT (view - FG SOURCE)
-- Features:
--   - Context columns: client (from Customer), contract (from [Desc])
--   - FG derived from ETB_CLIENT via CleanOrder/MONumber matching
-- Last Updated: 2026-02-05
-- ============================================================================

WITH GlobalConfig AS (
    SELECT 90 AS Planning_Window_Days
),

-- ============================================================================
-- CleanOrder normalization logic (PAB-style)
-- ============================================================================
CleanOrderLogic AS (
    SELECT
        ORDERNUMBER,
        -- CleanOrder: Strip MO, hyphens, spaces, punctuation, uppercase
        UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(ORDERNUMBER, 'MO', ''),
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
    FROM dbo.ETB_PAB_AUTO
    WHERE ITEMNMBR NOT LIKE '60.%'
      AND ITEMNMBR NOT LIKE '70.%'
      AND ITEMNMBR NOT LIKE 'MO-%'
      AND STSDESCR <> 'Partially Received'
),

-- ============================================================================
-- FG SOURCE: Join to ETB_CLIENT for FG derivation
-- Schema Map: MakeItem->FG_Item_Number, [Desc]->contract, Customer->client
-- Uses ROW_NUMBER partitioning by CleanOrder + MakeItem for deterministic selection
-- ============================================================================
FG_Source AS (
    SELECT
        col.ORDERNUMBER,
        col.CleanOrder,
        -- Schema Map: MakeItem -> FG_Item_Number
        ec.MakeItem AS FG_Item_Number,
        -- Schema Map: [Desc] -> contract
        ec.[Desc] AS contract,
        -- Schema Map: Customer -> client
        ec.Customer AS client,
        -- Deduplication: Select deterministic row per CleanOrder + MakeItem
        ROW_NUMBER() OVER (
            PARTITION BY col.CleanOrder, ec.MakeItem
            ORDER BY ec.Customer, ec.[Desc], col.ORDERNUMBER
        ) AS FG_RowNum
    FROM CleanOrderLogic col
    INNER JOIN dbo.ETB_CLIENT ec WITH (NOLOCK)
        ON col.CleanOrder = UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(ec.MONumber, 'MO', ''),
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
        )
),

-- ============================================================================
-- Deduplicated FG rows (rn = 1 per CleanOrder + MakeItem)
-- ============================================================================
FG_Deduped AS (
    SELECT
        ORDERNUMBER,
        CleanOrder,
        FG_Item_Number,
        contract,
        client
    FROM FG_Source
    WHERE FG_RowNum = 1
),

RawDemand AS (
    SELECT
        pa.ORDERNUMBER,
        pa.ITEMNMBR,
        pa.DUEDATE,
        pa.REMAINING,
        pa.DEDUCTIONS,
        pa.EXPIRY,
        pa.STSDESCR,
        pa.[Date + Expiry] AS Date_Expiry_String,
        pa.MRP_IssueDate,
        TRY_CONVERT(DATE, pa.DUEDATE) AS Due_Date_Clean,
        TRY_CONVERT(DATE, pa.[Date + Expiry]) AS Expiry_Date_Clean,
        pvi.ITEMDESC AS Item_Description,
        pvi.UOMSCHDL,
        'MAIN' AS Site,

        -- FG SOURCE: Carried through from deduped FG join
        fd.FG_Item_Number,
        fd.contract,
        fd.client

    FROM dbo.ETB_PAB_AUTO pa WITH (NOLOCK)
    INNER JOIN Prosenthal_Vendor_Items pvi WITH (NOLOCK)
      ON LTRIM(RTRIM(pa.ITEMNMBR)) = LTRIM(RTRIM(pvi.[Item Number]))
    -- FG SOURCE: Left join to carry FG forward
    LEFT JOIN FG_Deduped fd
        ON pa.ORDERNUMBER = fd.ORDERNUMBER
    WHERE pa.ITEMNMBR NOT LIKE '60.%'
      AND pa.ITEMNMBR NOT LIKE '70.%'
      AND pa.ITEMNMBR NOT LIKE 'MO-%'
      AND pa.STSDESCR <> 'Partially Received'
      AND pvi.Active = 'Yes'
      AND TRY_CONVERT(DATE, pa.DUEDATE) BETWEEN
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
),

CleanedDemand AS (
    SELECT
        ORDERNUMBER,
        ITEMNMBR,
        STSDESCR,
        Site,
        Item_Description,
        UOMSCHDL,
        Due_Date_Clean AS Due_Date,
        COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0.0) AS Remaining_Qty,
        COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0.0) AS Deductions_Qty,
        COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0.0) AS Expiry_Qty,
        Expiry_Date_Clean AS Expiry_Date,
        MRP_IssueDate,
        CASE
            WHEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0.0)
            WHEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0.0)
            WHEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0.0)
            ELSE 0.0
        END AS Base_Demand_Qty,
        CASE
            WHEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) > 0 THEN 'Remaining'
            WHEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) > 0 THEN 'Deductions'
            WHEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0) > 0 THEN 'Expiry'
            ELSE 'Zero'
        END AS Demand_Priority_Type,
        CASE
            WHEN Due_Date_Clean BETWEEN
                DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
                AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
            THEN 1 ELSE 0
        END AS Is_Within_Active_Planning_Window,
        CASE
            WHEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) > 0 THEN 3
            WHEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) > 0 THEN 3
            WHEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0) > 0 THEN 4
            ELSE 5
        END AS Event_Sort_Priority,
        -- CleanOrder: Strip MO, hyphens, spaces, punctuation, uppercase
        UPPER(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(
                            REPLACE(
                                REPLACE(ORDERNUMBER, 'MO', ''),
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
        ) AS Clean_Order_Number,

        -- FG SOURCE: Carried through from base
        FG_Item_Number,
        contract,
        client

    FROM RawDemand
    WHERE Due_Date_Clean IS NOT NULL
      AND (COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0)) > 0
)

-- ============================================================
-- FINAL OUTPUT: Demand with FG carried through
-- ============================================================
SELECT
    cd.Clean_Order_Number AS Order_Number,
    cd.ITEMNMBR AS Item_Number,
    cd.Item_Description,
    cd.UOMSCHDL AS Unit_Of_Measure,
    cd.Site,
    cd.Due_Date,
    cd.STSDESCR AS Status_Description,
    cd.Base_Demand_Qty,
    cd.Expiry_Qty,
    cd.Expiry_Date,
    cd.Remaining_Qty,
    cd.Deductions_Qty,
    cd.Demand_Priority_Type,
    cd.Is_Within_Active_Planning_Window,
    cd.Event_Sort_Priority,
    cd.MRP_IssueDate,

    -- ROW_NUMBER with client for stability
    ROW_NUMBER() OVER (
        PARTITION BY cd.ITEMNMBR, cd.client
        ORDER BY cd.Due_Date ASC, cd.Base_Demand_Qty DESC
    ) AS Demand_Sequence,

    -- FG from source join
    cd.FG_Item_Number AS FG_Item_Code,
    cd.contract,
    cd.client

FROM CleanedDemand cd;

-- ============================================================================
-- END OF VIEW 04 (CONSOLIDATED FINAL)
-- ============================================================================
