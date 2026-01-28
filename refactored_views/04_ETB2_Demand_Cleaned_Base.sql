-- ============================================================================
-- VIEW 04: dbo.ETB2_Demand_Cleaned_Base
-- ============================================================================
-- DEPLOYMENT INSTRUCTIONS:
-- 1. Copy this entire WITH...SELECT statement
-- 2. Open SSMS → New Query window
-- 3. Paste the statement
-- 4. Execute (F5) to test
-- 5. Highlight all (Ctrl+A)
-- 6. Right-click → Create View
-- 7. Save as: dbo.ETB2_Demand_Cleaned_Base
-- ============================================================================
-- Purpose: Cleaned base demand excluding partial/invalid orders
-- Grain: Order Line
--   - Excludes: 60.x/70.x order types, partial receives
--   - Priority: Remaining > Deductions > Expiry
--   - Window: ±21 days from GETDATE()
-- Dependencies:
--   - dbo.ETB_PAB_AUTO (external table)
--   - Prosenthal_Vendor_Items (external table)
--   - dbo.ETB2_Config_Items (view 02B) - for Item_Description, UOM_Schedule
-- Last Updated: 2026-01-28
-- ============================================================================

WITH RawDemand AS (
    SELECT
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
      AND pa.STSDESCR <> 'Partially Received'
      AND pvi.Active = 'Yes'
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
                DATEADD(DAY, -21, CAST(GETDATE() AS DATE))
                AND DATEADD(DAY, 21, CAST(GETDATE() AS DATE))
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
        ) AS Clean_Order_Number
    FROM RawDemand
    WHERE Due_Date_Clean IS NOT NULL
      AND (COALESCE(TRY_CAST(REMAINING AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(DEDUCTIONS AS DECIMAL(18,4)), 0) + COALESCE(TRY_CAST(EXPIRY AS DECIMAL(18,4)), 0)) > 0
)

SELECT
    Clean_Order_Number AS Order_Number,
    ITEMNMBR AS Item_Number,
    COALESCE(ci.Item_Description, cd.ItemDescription) AS Item_Description,
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
    MRP_IssueDate
FROM CleanedDemand cd
LEFT JOIN dbo.ETB2_Config_Items ci WITH (NOLOCK)
    ON cd.ITEMNMBR = ci.Item_Number;

-- ============================================================================
-- END OF VIEW 04
-- ============================================================================
