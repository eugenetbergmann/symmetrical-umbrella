/*******************************************************************************
* View Name:    ETB2_Demand_Cleaned_Base
* Deploy Order: 04 of 17
* Status:       🔴 NOT YET DEPLOYED
* 
* Purpose:      Cleaned demand data excluding partial/invalid/cancelled orders
* Grain:        One row per item per demand date (aggregated)
* 
* Dependencies (MUST exist - verify first):
*   ✅ ETB2_Config_Lead_Times (deployed)
*   ✅ ETB2_Config_Part_Pooling (deployed)
*   ✅ ETB2_Config_Active (deployed)
*   ✓ dbo.ETB_PAB_AUTO (demand data - external table)
*   ✓ dbo.Prosenthal_Vendor_Items (vendor mapping - external table)
*
* ⚠️ DEPLOYMENT METHOD (Same as views 1-3):
* 1. Object Explorer → Right-click "Views" → "New View..."
* 2. IMMEDIATELY: Menu → Query Designer → Pane → SQL
* 3. Delete default SQL
* 4. Copy SELECT below (between markers)
* 5. Paste into SQL pane
* 6. Execute (!) to test
* 7. Save as: dbo.ETB2_Demand_Cleaned_Base
* 8. Refresh Views folder
*
* Validation: 
*   SELECT COUNT(*) FROM dbo.ETB2_Demand_Cleaned_Base
*   Expected: Rows matching orders in ETB_PAB_AUTO (excluding cancelled, 60.x, 70.x)
*******************************************************************************/

-- ============================================================================
-- COPY FROM HERE
-- ============================================================================

-- ============================================================================
-- View: dbo.ETB2_Demand_Cleaned_Base
-- Purpose: Cleaned base demand excluding partial/invalid orders
-- Grain: Order Line
--   - Excludes: 60.x/70.x order types, partial receives
--   - Priority: Remaining > Deductions > Expiry
--   - Window: ±21 days from GETDATE()
-- Excel-Ready: Yes (SELECT-only, human-readable columns)
-- Dependencies: dbo.ETB_PAB_AUTO, Prosenthal_Vendor_Items
-- Last Updated: 2026-01-27
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
        pvi.ITEMDESC AS ItemDescription,
        pvi.UOMSCHDL,
        'MAIN' AS SITE  -- Default site for demand
    FROM dbo.ETB_PAB_AUTO pa
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
        SITE,
        ItemDescription,
        UOMSCHDL,
        Due_Date_Clean AS Due_Date,
        COALESCE(REMAINING, 0.0) AS Remaining_Qty,
        COALESCE(DEDUCTIONS, 0.0) AS Deductions_Qty,
        COALESCE(EXPIRY, 0.0) AS Expiry_Qty,
        Expiry_Date_Clean AS Expiry_Date,
        MRP_IssueDate,
        CASE
            WHEN COALESCE(REMAINING, 0) > 0 THEN COALESCE(REMAINING, 0.0)
            WHEN COALESCE(DEDUCTIONS, 0) > 0 THEN COALESCE(DEDUCTIONS, 0.0)
            WHEN COALESCE(EXPIRY, 0) > 0 THEN COALESCE(EXPIRY, 0.0)
            ELSE 0.0
        END AS Base_Demand_Qty,
        CASE
            WHEN COALESCE(REMAINING, 0) > 0 THEN 'Remaining'
            WHEN COALESCE(DEDUCTIONS, 0) > 0 THEN 'Deductions'
            WHEN COALESCE(EXPIRY, 0) > 0 THEN 'Expiry'
            ELSE 'Zero'
        END AS Demand_Priority_Type,
        CASE
            WHEN Due_Date_Clean BETWEEN
                DATEADD(DAY, -21, CAST(GETDATE() AS DATE))
                AND DATEADD(DAY, 21, CAST(GETDATE() AS DATE))
            THEN 1 ELSE 0
        END AS Is_Within_Active_Planning_Window,
        -- Sort priority matches original: 1=BEG_BAL (not here), 2=POs, 3=Demand, 4=Expiry, 5=Other
        CASE 
            WHEN COALESCE(REMAINING, 0) > 0 THEN 3
            WHEN COALESCE(DEDUCTIONS, 0) > 0 THEN 3
            WHEN COALESCE(EXPIRY, 0) > 0 THEN 4
            ELSE 5
        END AS Event_Sort_Priority,
        -- Clean order number: remove MO-, -, /, ., # and trim
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
    WHERE Due_Date_Clean IS NOT NULL  -- only valid dates
      AND (COALESCE(REMAINING, 0) + COALESCE(DEDUCTIONS, 0) + COALESCE(EXPIRY, 0)) > 0  -- exclude zero-impact rows
)

SELECT
    ORDERNUMBER,
    ITEMNMBR,
    ItemDescription,
    SITE,
    Due_Date AS DUEDATE,
    STSDESCR,
    Base_Demand_Qty,  -- Keep original column name
    Expiry_Qty AS Expiry,
    Expiry_Date AS Expiry_Dates,
    UOMSCHDL,
    Remaining_Qty,
    Deductions_Qty,
    Demand_Priority_Type,
    Is_Within_Active_Planning_Window,  -- Ensure this column is exposed
    Event_Sort_Priority,
    MRP_IssueDate,
    Clean_Order_Number AS Order_Number
FROM CleanedDemand
ORDER BY
    Due_Date ASC,
    Base_Demand_Qty DESC,
    Event_Sort_Priority ASC,
    ITEMNMBR ASC;

-- ============================================================================
-- COPY TO HERE
-- ============================================================================

/*
Post-Deployment Validation:

1. Row count check:
   SELECT COUNT(*) FROM dbo.ETB2_Demand_Cleaned_Base
   -- Should be less than ETB_PAB_AUTO (due to filtering)

2. Data quality check:
   SELECT TOP 10 
       ITEMNMBR,
       Demand_Date,
       Quantity,
       Campaign_ID
   FROM dbo.ETB2_Demand_Cleaned_Base
   ORDER BY Demand_Date DESC
   -- Should show no cancelled orders, no 60.x/70.x items

3. Campaign coverage:
   SELECT 
       COUNT(*) AS Total_Items,
       COUNT(DISTINCT Campaign_ID) AS Unique_Campaigns
   FROM dbo.ETB2_Demand_Cleaned_Base
   WHERE Campaign_ID <> 'UNKNOWN'
*/
