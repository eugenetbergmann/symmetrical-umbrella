-- ============================================================================
-- VIEW 04: dbo.ETB2_Demand_Cleaned_Base (REFACTORED - ETB2)
-- ============================================================================
-- Purpose: Cleaned base demand excluding partial/invalid orders
-- Grain: Order Line
--   - Excludes: 60.x/70.x order types, partial receives
--   - Priority: Remaining > Deductions > Expiry
-- Dependencies:
--   - dbo.ETB_PAB_AUTO (external table)
--   - Prosenthal_Vendor_Items (external table)
--   - dbo.ETB2_Config_Items (view 02B) - for Item_Description, UOM_Schedule
-- Refactoring Applied:
--   - Added context columns: client, contract, run
--   - Preserve context in all GROUP BY clauses
--   - Added Is_Suppressed flag with filter
--   - Filter out ITEMNMBR LIKE 'MO-%'
--   - Date window expanded to ±90 days
--   - Added context to ROW_NUMBER PARTITION BY
--   - Context preserved in subqueries
-- Last Updated: 2026-01-29
-- ============================================================================

WITH RawDemand AS (
    SELECT
        -- Context columns
        'DEFAULT_CLIENT' AS client,
        'DEFAULT_CONTRACT' AS contract,
        'CURRENT_RUN' AS run,
        
        ORDERNUMBER,
        ITEMNMBR,
        DUEDATE,
        REMAINING,
        DEDUCTIONS,
        EXPIRY,
        STSDESCR,
        [Date + Expiry] AS Date_Expiry_String,
        MRP_IssueDate,
        TRY_CONVERT(DATE, DUEDATE) AS Due_Date_Clean,
        TRY_CONVERT(DATE, [Date + Expiry]) AS Expiry_Date_Clean,
        pvi.ITEMDESC AS Item_Description,
        pvi.UOMSCHDL,
        'MAIN' AS Site  -- Default site for demand
    FROM dbo.ETB_PAB_AUTO pa WITH (NOLOCK)
    INNER JOIN Prosenthal_Vendor_Items pvi WITH (NOLOCK)
      ON LTRIM(RTRIM(pa.ITEMNMBR)) = LTRIM(RTRIM(pvi.[Item Number]))
    WHERE pa.ITEMNMBR NOT LIKE '60.%'
      AND pa.ITEMNMBR NOT LIKE '70.%'
      AND pa.ITEMNMBR NOT LIKE 'MO-%'  -- Filter out MO- conflated items
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
        TRIM(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(ORDERNUMBER, 'MO-', ''),
                        '-', ''
                    ),
                    '/', ''
                ),
                '#', ''
            )
        ) AS Clean_Order_Number,
        
        -- Suppression flag
        CAST(0 AS BIT) AS Is_Suppressed
        
    FROM RawDemand
    WHERE Due_Date_Clean IS NOT NULL
      AND (COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0)) > 0
)

SELECT
    -- Context columns preserved
    client,
    contract,
    run,
    
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
        ORDER BY Due_Date ASC, Event_Sort_Priority ASC
    ) AS Demand_Sequence
    
FROM CleanedDemand cd
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON cd.ITEMNMBR = ci.Item_Number
    AND cd.client = ci.client
    AND cd.contract = ci.contract
    AND cd.run = ci.run
WHERE CAST(cd.Is_Suppressed | COALESCE(ci.Is_Suppressed, 0) AS BIT) = 0;  -- Is_Suppressed filter

-- ============================================================================
-- END OF VIEW 04 (REFACTORED)
-- ============================================================================