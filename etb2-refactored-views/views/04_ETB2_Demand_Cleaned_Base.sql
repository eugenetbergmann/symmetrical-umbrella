/* VIEW 04 - STATUS: PRODUCTION STABILIZED */
-- ============================================================================
-- VIEW 04: dbo.ETB2_Demand_Cleaned_Base (PRODUCTION STABILIZED)
-- ============================================================================
-- Purpose: Cleaned and normalized demand data with FG derivation
--          SUPPRESSION-SAFE: Demand only subtracted if it passes suppression filter
-- Grain: One row per demand event (order line)
-- Dependencies:
--   - dbo.ETB_PAB_AUTO (external table)
--   - dbo.Prosenthal_Vendor_Items (external table)
--   - dbo.ETB_ActiveDemand_Union_FG_MO (external table - FG SOURCE)
-- Features:
--   - Context columns: client (from Construct), contract (from FG_Description)
--   - FG derived from ETB_ActiveDemand_Union_FG_MO via MO linkage
--   - Is_Suppressed flag: Items LIKE 'MO-%' are flagged and demand set to 0
--   - Event_Sort_Priority for deterministic ordering
-- Stabilization:
--   - Suppression Integrity: Demand is suppressed if Site is WC-R or specifically flagged
--   - Math Correctness: Suppressed items have Suppressed_Demand_Qty = 0
-- Last Updated: 2026-02-06
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
-- FG SOURCE (FIXED): Join to ETB_ActiveDemand_Union_FG_MO for FG derivation
-- FIX: Uses correct source column names from ETB_ActiveDemand_Union_FG_MO
-- Schema Map: FG->FG_Item_Number, [FG Desc]->FG_Description
-- Uses ROW_NUMBER partitioning by CleanOrder + FG for deterministic selection
-- ============================================================================
FG_Source AS (
    SELECT
        col.ORDERNUMBER,
        col.CleanOrder,
        -- Enforced Schema Map: FG -> FG_Item_Number
        m.FG AS FG_Item_Number,
        -- Enforced Schema Map: [FG Desc] -> FG_Description
        m.[FG Desc] AS FG_Description,
        -- Bring in Customer from ETB_ActiveDemand_Union_FG_MO (renamed to client)
        m.Customer AS client,
        -- Deduplication: Select deterministic FG row per CleanOrder
        ROW_NUMBER() OVER (
            PARTITION BY col.CleanOrder, m.FG
            ORDER BY m.Customer, m.[FG Desc], col.ORDERNUMBER
        ) AS FG_RowNum
    FROM CleanOrderLogic col
    INNER JOIN dbo.ETB_ActiveDemand_Union_FG_MO m WITH (NOLOCK)
        ON col.CleanOrder = UPPER(
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
        )
),

-- ============================================================================
-- Deduplicated FG rows (rn = 1 per CleanOrder + FG)
-- ============================================================================
FG_Deduped AS (
    SELECT
        ORDERNUMBER,
        CleanOrder,
        FG_Item_Number,
        FG_Description,
        client
    FROM FG_Source
    WHERE FG_RowNum = 1
),

-- ============================================================================
-- SUPPRESSION LOGIC: Determine if demand should be suppressed
-- Items are suppressed if:
--   1. ITEMNMBR LIKE 'MO-%' (conflated items)
--   2. Site is WC-R (restricted work center)
-- ============================================================================
SuppressionLogic AS (
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
        pa.MRPTYPE,
        TRY_CONVERT(DATE, pa.DUEDATE) AS Due_Date_Clean,
        TRY_CONVERT(DATE, pa.[Date + Expiry]) AS Expiry_Date_Clean,
        pvi.ITEMDESC AS Item_Description,
        pvi.UOMSCHDL,
        'MAIN' AS Site,

        -- SUPPRESSION FLAG: 1 if item should be suppressed
        CASE
            WHEN pa.ITEMNMBR LIKE 'MO-%' THEN 1
            WHEN pa.ITEMNMBR LIKE 'WC-R%' THEN 1
            ELSE 0
        END AS Is_Suppressed,

        -- FG SOURCE (PAB-style): Carried through from deduped FG join
        fd.FG_Item_Number,
        fd.FG_Description,
        fd.client

    FROM dbo.ETB_PAB_AUTO pa WITH (NOLOCK)
    INNER JOIN Prosenthal_Vendor_Items pvi WITH (NOLOCK)
      ON LTRIM(RTRIM(pa.ITEMNMBR)) = LTRIM(RTRIM(pvi.[Item Number]))
    -- FG SOURCE (PAB-style): Left join to carry FG forward
    LEFT JOIN FG_Deduped fd
        ON pa.ORDERNUMBER = fd.ORDERNUMBER
    WHERE pa.ITEMNMBR NOT LIKE '60.%'
      AND pa.ITEMNMBR NOT LIKE '70.%'
      AND pa.STSDESCR <> 'Partially Received'
      AND pvi.Active = 'Yes'
      AND TRY_CONVERT(DATE, pa.DUEDATE) BETWEEN
          DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
          AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
),

-- ============================================================================
-- CleanedDemand: Apply suppression-safe math
-- SUPPRESSION INTEGRITY: If Is_Suppressed = 1, Suppressed_Demand_Qty = 0
-- This ensures suppressed items don't erode the PAB balance
-- ============================================================================
CleanedDemand AS (
    SELECT
        ORDERNUMBER,
        ITEMNMBR,
        STSDESCR,
        Site,
        Item_Description,
        UOMSCHDL,
        Due_Date_Clean AS Due_Date,

        -- Raw quantities (for audit)
        COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0.0) AS Remaining_Qty,
        COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0.0) AS Deductions_Qty,
        COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0.0) AS Expiry_Qty,

        -- SUPPRESSED QUANTITIES: Set to 0 if item is suppressed
        CASE WHEN Is_Suppressed = 1 THEN 0
             ELSE COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0.0)
        END AS Suppressed_Remaining_Qty,
        CASE WHEN Is_Suppressed = 1 THEN 0
             ELSE COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0.0)
        END AS Suppressed_Deductions_Qty,
        CASE WHEN Is_Suppressed = 1 THEN 0
             ELSE COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0.0)
        END AS Suppressed_Expiry_Qty,

        Expiry_Date_Clean AS Expiry_Date,
        MRP_IssueDate,

        -- Base demand calculation using SUPPRESSED quantities
        CASE
            WHEN Is_Suppressed = 1 THEN 0.0
            WHEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0.0)
            WHEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0.0)
            WHEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0) > 0 THEN COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0.0)
            ELSE 0.0
        END AS Base_Demand_Qty,

        CASE
            WHEN Is_Suppressed = 1 THEN 'Suppressed'
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

        -- EVENT SORT PRIORITY: Prevents balance flipping on same date
        -- Priority 1: BEG BAL (not in this view, handled in PAB ledger)
        -- Priority 2: DEMAND (MRPTYPE 6)
        -- Priority 3: PO (MRPTYPE 7)
        -- Priority 4: EXPIRY (MRPTYPE 11)
        CASE
            WHEN Is_Suppressed = 1 THEN 99  -- Suppressed items last
            WHEN MRPTYPE = 6 THEN 2        -- Demand
            WHEN MRPTYPE = 7 THEN 3        -- PO
            WHEN MRPTYPE = 11 THEN 4       -- Expiry
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

        -- FG SOURCE (PAB-style): Carried through from base
        FG_Item_Number,
        FG_Description,
        client,

        -- SUPPRESSION FLAG: Exposed for downstream filtering
        CAST(Is_Suppressed AS BIT) AS Is_Suppressed

    FROM SuppressionLogic
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
    cd.UOMSCHDL,
    cd.Site,
    cd.Due_Date,
    cd.STSDESCR AS Status_Description,
    cd.Base_Demand_Qty,
    cd.Expiry_Qty,
    cd.Expiry_Date,
    cd.Remaining_Qty,
    cd.Deductions_Qty,

    -- SUPPRESSED QUANTITIES: Use these for PAB calculations
    cd.Suppressed_Remaining_Qty,
    cd.Suppressed_Deductions_Qty,
    cd.Suppressed_Expiry_Qty,

    cd.Demand_Priority_Type,
    cd.Is_Within_Active_Planning_Window,
    cd.Event_Sort_Priority,
    cd.MRP_IssueDate,

    -- ROW_NUMBER
    ROW_NUMBER() OVER (
        PARTITION BY cd.ITEMNMBR
        ORDER BY cd.Due_Date ASC, cd.Base_Demand_Qty DESC
    ) AS Demand_Sequence,

    -- FG from source join
    cd.FG_Item_Number AS FG_Item_Code,
    cd.FG_Description AS contract,
    cd.client,

    -- SUPPRESSION FLAG
    cd.Is_Suppressed,

    -- SUPPRESSED DEMAND QTY: Single column for downstream convenience
    CASE WHEN cd.Is_Suppressed = 1 THEN 0
         ELSE cd.Suppressed_Deductions_Qty + cd.Suppressed_Remaining_Qty
    END AS Suppressed_Demand_Qty

FROM CleanedDemand cd;

-- ============================================================================
-- END OF VIEW 04 (PRODUCTION STABILIZED)
-- ============================================================================
