-- VIEW 04: Fixed FG Source Mapping
-- Mapping: m.Customer -> Construct, m.MakeItem -> FG_Item_Number, m.[Desc] -> FG_Description
CREATE OR ALTER VIEW [dbo].[ETB2_Demand_Cleaned_Base]
AS
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
        ) AS CleanOrder
    FROM dbo.ETB_PAB_AUTO
    WHERE ITEMNMBR NOT LIKE '60.%'
      AND ITEMNMBR NOT LIKE '70.%'
      AND ITEMNMBR NOT LIKE 'MO-%'
      AND STSDESCR <> 'Partially Received'
),

-- ============================================================================
-- FG SOURCE (FIXED): Join to ETB_ActiveDemand_Union_FG_MO for FG + Construct derivation
-- FIX: Swapped source table from ETB_PAB_MO to ETB_ActiveDemand_Union_FG_MO
-- Schema Map: Customer->Construct, FG->FG_Item_Number, [FG Desc]->FG_Description
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
        -- Enforced Schema Map: Customer -> Construct
        m.Customer AS Construct,
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
        Construct
    FROM FG_Source
    WHERE FG_RowNum = 1
),

RawDemand AS (
    SELECT
        -- Context columns
        'DEFAULT_CLIENT' AS client,
        'DEFAULT_CONTRACT' AS contract,
        'CURRENT_RUN' AS run,

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

        -- FG SOURCE (PAB-style): Carried through from deduped FG join
        fd.FG_Item_Number,
        fd.FG_Description,
        -- Construct SOURCE (PAB-style): Carried through from deduped FG join
        fd.Construct

    FROM dbo.ETB_PAB_AUTO pa WITH (NOLOCK)
    INNER JOIN Prosenthal_Vendor_Items pvi WITH (NOLOCK)
      ON LTRIM(RTRIM(pa.ITEMNMBR)) = LTRIM(RTRIM(pvi.[Item Number]))
    -- FG SOURCE (PAB-style): Left join to carry FG/Construct forward
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
        -- Context columns preserved
        client,
        contract,
        run,

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
        ) AS Clean_Order_Number,

        -- Suppression flag
        CAST(0 AS BIT) AS Is_Suppressed,

        -- FG SOURCE (PAB-style): Carried through from base
        FG_Item_Number,
        FG_Description,
        -- Construct SOURCE (PAB-style): Carried through from base
        Construct

    FROM RawDemand
    WHERE Due_Date_Clean IS NOT NULL
      AND (COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0)) > 0
)

-- ============================================================
-- FINAL OUTPUT: Demand with FG + Construct carried through
-- ============================================================
SELECT
    -- Context columns preserved
    cd.client,
    cd.contract,
    cd.run,

    Clean_Order_Number AS Order_Number,
    ITEMNMBR AS Item_Number,
    COALESCE(ci.Item_Description, cd.Item_Description) AS Item_Description,
    ci.UOM_Schedule,
    Site,
    Due_Date,
    STSDESCR AS Status_Description,
    Base_Demand_Qty,
    Expiry_Qty,
    Expiry_Date,
    UOMSCHDL AS Unit_Of_Measure,
    Remaining_Qty,
    Deductions_Qty,
    Demand_Priority_Type,
    Is_Within_Active_Planning_Window,
    Event_Sort_Priority,
    MRP_IssueDate,

    -- Suppression flag
    CAST(cd.Is_Suppressed | COALESCE(ci.Is_Suppressed, 0) AS BIT) AS Is_Suppressed,

    -- ROW_NUMBER with context in PARTITION BY
    ROW_NUMBER() OVER (
        PARTITION BY client, contract, run, ITEMNMBR
        ORDER BY Due_Date ASC, Base_Demand_Qty DESC
    ) AS Demand_Sequence,

    -- FG SOURCE (PAB-style): Exposed in final output
    FG_Item_Number,
    FG_Description,
    -- Construct SOURCE (PAB-style): Exposed in final output
    Construct

FROM CleanedDemand cd
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON cd.ITEMNMBR = ci.Item_Number;
