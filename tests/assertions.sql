-- Violation Detection Queries for Existing Data
-- These queries should return NO ROWS if the views are correct
-- Any returned rows indicate failures

USE [MED];
GO

SET NOCOUNT ON;
GO

-- Test 1.1: Demands within window with WC inventory but not suppressed
-- This test uses the deployed view dbo.Rolyat_WC_Allocation_Effective_2
SELECT 'FAILURE: Test 1.1 - Unsuppressed demand within window' AS Failure_Type,
       ORDERNUMBER, ITEMNMBR, Date_Expiry, Base_Demand, effective_demand, WC_Batch_ID
FROM dbo.Rolyat_WC_Allocation_Effective_2
FROM (
-- Inline Rolyat_WC_Allocation_Effective_2.sql
WITH PrioritizedInventory AS (
    SELECT
        bd.ORDERNUMBER,
        bd.CleanOrder,
        bd.ITEMNMBR,
        bd.CleanItem,
        bd.WCID_From_MO,
        bd.Construct,
        bd.FG,
        bd.FG_Desc,
        bd.ItemDescription,
        bd.UOMSCHDL,
        bd.STSDESCR,
        bd.MRPTYPE,
        bd.VendorItem,
        bd.INCLUDE_MRP,
        bd.SITE,
        bd.PRIME_VNDR,
        bd.Date_Expiry,
        bd.Expiry_Dates,
        bd.DUEDATE,
        bd.MRP_IssueDate,
        bd.BEG_BAL,
        bd.POs,
        bd.Deductions,
        bd.CleanDeductions,
        bd.Expiry,
        bd.Remaining,
        bd.Running_Balance,
        bd.Issued,
        bd.PURCHASING_LT,
        bd.PLANNING_LT,
        bd.ORDER_POINT_QTY,
        bd.SAFETY_STOCK,
        bd.Has_Issued,
        bd.IssueDate_Mismatch,
        bd.Early_Issue_Flag,
        bd.Base_Demand,
        w.Item_Number AS WC_Item,
        w.SITE AS WC_Site,
        w.QTY_Available AS Available_Qty,
        w.DATERECD AS WC_DateReceived,
        DATEDIFF(DAY, w.DATERECD, GETDATE()) AS WC_Age_Days,
        CASE
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 30 THEN 1.00
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 60 THEN 0.75
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90 THEN 0.50
            ELSE 0.00
        END AS WC_Degradation_Factor,
        w.QTY_Available * CASE
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 30 THEN 1.00
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 60 THEN 0.75
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90 THEN 0.50
            ELSE 0.00
        END AS WC_Effective_Qty,
        ISNULL(w.Item_Number, '') + '|' +
        ISNULL(w.SITE, '') + '|' +
        ISNULL(w.LOT_Number, '') + '|' +
        ISNULL(FORMAT(w.DATERECD, 'yyyy-MM-dd'), '') AS WC_Batch_ID,
        CASE WHEN w.SITE = bd.SITE THEN 1 ELSE 999 END AS pri_wcid_match,
        ABS(DATEDIFF(DAY,
            COALESCE(w.EXPNDATE, '9999-12-31'),
            COALESCE(bd.Expiry_Dates, '9999-12-31')
        )) AS pri_expiry_proximity,
        ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) AS pri_temporal_proximity
    FROM (
        -- Inline Rolyat_Cleaned_Base_Demand_1.sql
        SELECT
            UPPER(TRIM(ORDERNUMBER)) AS ORDERNUMBER,
            UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                TRIM(REPLACE(ORDERNUMBER, 'MO', '')),
                '-', ''), ' ', ''), '/', ''), '.', ''), '#', '')) AS CleanOrder,
            TRIM(ITEMNMBR) AS ITEMNMBR,
            TRIM(ITEMNMBR) AS CleanItem,
            TRIM(COALESCE(WCID_From_MO, '')) AS WCID_From_MO,
            TRIM(COALESCE(Construct, '')) AS Construct,
            TRIM(COALESCE(FG, '')) AS FG,
            TRIM(COALESCE([FG Desc], '')) AS FG_Desc,
            TRIM(COALESCE(ItemDescription, '')) AS ItemDescription,
            TRIM(COALESCE(UOMSCHDL, '')) AS UOMSCHDL,
            TRIM(COALESCE(STSDESCR, '')) AS STSDESCR,
            TRIM(COALESCE(MRPTYPE, '')) AS MRPTYPE,
            TRIM(COALESCE(VendorItem, '')) AS VendorItem,
            TRIM(COALESCE(INCLUDE_MRP, '')) AS INCLUDE_MRP,
            TRIM(COALESCE(SITE, '')) AS SITE,
            TRIM(COALESCE(PRIME_VNDR, '')) AS PRIME_VNDR,
            TRY_CONVERT(DATE, [Date + Expiry]) AS Date_Expiry,
            TRY_CONVERT(DATE, [Expiry Dates]) AS Expiry_Dates,
            TRY_CONVERT(DATE, DUEDATE) AS DUEDATE,
            TRY_CONVERT(DATE, MRP_IssueDate) AS MRP_IssueDate,
            COALESCE(TRY_CAST(BEG_BAL AS DECIMAL(18, 5)), 0.0) AS BEG_BAL,
            COALESCE(TRY_CAST([PO's] AS DECIMAL(18, 5)), 0.0) AS POs,
            COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) AS Deductions,
            COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) AS CleanDeductions,
            COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0) AS Expiry,
            COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0) AS Remaining,
            COALESCE(TRY_CAST(Running_Balance AS DECIMAL(18, 5)), 0.0) AS Running_Balance,
            COALESCE(TRY_CAST(Issued AS DECIMAL(18, 5)), 0.0) AS Issued,
            COALESCE(TRY_CAST(PURCHASING_LT AS DECIMAL(18, 5)), 0.0) AS PURCHASING_LT,
            COALESCE(TRY_CAST(PLANNING_LT AS DECIMAL(18, 5)), 0.0) AS PLANNING_LT,
            COALESCE(TRY_CAST(ORDER_POINT_QTY AS DECIMAL(18, 5)), 0.0) AS ORDER_POINT_QTY,
            COALESCE(TRY_CAST(SAFETY_STOCK AS DECIMAL(18, 5)), 0.0) AS SAFETY_STOCK,
            UPPER(TRIM(COALESCE(Has_Issued, 'NO'))) AS Has_Issued,
            UPPER(TRIM(COALESCE(IssueDate_Mismatch, 'NO'))) AS IssueDate_Mismatch,
            UPPER(TRIM(COALESCE(Early_Issue_Flag, 'NO'))) AS Early_Issue_Flag,
            CASE
                WHEN COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0) > 0 THEN COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0)
                WHEN COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) > 0 THEN COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0)
                WHEN COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0) > 0 THEN COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0)
                ELSE 0.0
            END AS Base_Demand
        FROM dbo.ETB_PAB_AUTO
        WHERE TRY_CONVERT(DATE, [Date + Expiry]) IS NOT NULL
            AND TRIM(ITEMNMBR) NOT LIKE '60.%'
            AND TRIM(ITEMNMBR) NOT LIKE '70.%'
            AND TRIM(COALESCE(STSDESCR, '')) <> 'Partially Received'
    ) AS bd
    LEFT JOIN dbo.ETB_WC_INV AS w
        ON LTRIM(RTRIM(w.Item_Number)) = bd.CleanItem
        AND w.SITE LIKE 'WC-W%'
        AND w.QTY_Available > 0
        AND ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) <= 21
        AND DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90
),
PriorClaimed AS (
    SELECT
        pi.*,
        CASE
            WHEN WC_Batch_ID IS NULL THEN 0.0
            ELSE COALESCE(
                SUM(Base_Demand) OVER (
                    PARTITION BY WC_Batch_ID
                    ORDER BY pri_wcid_match, pri_expiry_proximity, pri_temporal_proximity, Date_Expiry, ORDERNUMBER
                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                ), 0.0)
        END AS batch_prior_claimed_demand
    FROM PrioritizedInventory AS pi
),
Allocated AS (
    SELECT
        pc.*,
        CASE
            WHEN WC_Batch_ID IS NULL THEN 0.0
            WHEN Base_Demand <= (WC_Effective_Qty - batch_prior_claimed_demand)
                THEN Base_Demand
            WHEN (WC_Effective_Qty - batch_prior_claimed_demand) > 0
                THEN (WC_Effective_Qty - batch_prior_claimed_demand)
            ELSE 0.0
        END AS allocated
    FROM PriorClaimed AS pc
)
SELECT
    ORDERNUMBER, CleanOrder, ITEMNMBR, CleanItem, WCID_From_MO, Construct, FG, FG_Desc, ItemDescription,
    UOMSCHDL, STSDESCR, MRPTYPE, VendorItem, INCLUDE_MRP, SITE, PRIME_VNDR, Date_Expiry, Expiry_Dates,
    DUEDATE, MRP_IssueDate, BEG_BAL, POs, Deductions, CleanDeductions, Expiry, Remaining, Running_Balance,
    Issued, PURCHASING_LT, PLANNING_LT, ORDER_POINT_QTY, SAFETY_STOCK, Has_Issued, IssueDate_Mismatch,
    Early_Issue_Flag, Base_Demand, WC_Item, WC_Site, Available_Qty, WC_DateReceived, WC_Age_Days,
    WC_Degradation_Factor, WC_Effective_Qty, WC_Batch_ID, pri_wcid_match, pri_expiry_proximity,
    pri_temporal_proximity, batch_prior_claimed_demand, allocated,
    CASE
        WHEN Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
        THEN CASE
                WHEN Base_Demand - allocated > 0 THEN Base_Demand - allocated
                ELSE 0.0
             END
        ELSE Base_Demand
    END AS effective_demand,
    CASE
        WHEN Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
        THEN CASE
                WHEN allocated > 0 THEN 'WC_Suppressed'
                ELSE 'No_WC_Allocation'
             END
        ELSE 'Outside_Active_Window'
    END AS wc_allocation_status,
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Date_Expiry, ORDERNUMBER
    ) AS item_row_num
FROM Allocated
) AS effective_demand
WHERE Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
    AND WC_Batch_ID IS NOT NULL
    AND effective_demand = Base_Demand
    AND Base_Demand > 0;
GO

-- Test 1.2: Demands outside window incorrectly suppressed
SELECT 'FAILURE: Test 1.2 - Suppressed demand outside window' AS Failure_Type,
       ORDERNUMBER, ITEMNMBR, Date_Expiry, Base_Demand, effective_demand
FROM dbo.Rolyat_WC_Allocation_Effective_2
WHERE Date_Expiry NOT BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
    AND effective_demand < Base_Demand;
GO

-- Test 3.1: Incorrect degradation factors
SELECT 'FAILURE: Test 3.1 - Wrong degradation factor' AS Failure_Type,
       ORDERNUMBER, ITEMNMBR, WC_Age_Days, WC_Degradation_Factor
FROM dbo.Rolyat_WC_Allocation_Effective_2
WHERE (WC_Age_Days <= 30 AND WC_Degradation_Factor != 1.00)
   OR (WC_Age_Days BETWEEN 31 AND 60 AND WC_Degradation_Factor != 0.75)
   OR (WC_Age_Days BETWEEN 61 AND 90 AND WC_Degradation_Factor != 0.50)
   OR (WC_Age_Days > 90 AND WC_Degradation_Factor != 0.00);
GO

-- Test 4.1: Double allocation - allocated exceeds batch effective qty
SELECT 'FAILURE: Test 4.1 - Double allocation' AS Failure_Type,
       WC_Batch_ID, SUM(allocated) AS Total_Allocated, MAX(WC_Effective_Qty) AS Batch_Effective_Qty
FROM dbo.Rolyat_WC_Allocation_Effective_2
WHERE WC_Batch_ID IS NOT NULL
GROUP BY WC_Batch_ID
HAVING SUM(allocated) > MAX(WC_Effective_Qty);
GO

-- Test 5.1: Running balance anomalies (simplified check for sudden increases)
-- Note: LAG cannot be used in WHERE clause directly; use a subquery
SELECT 'FAILURE: Test 5.1 - Balance anomaly' AS Failure_Type,
       ITEMNMBR, Date_Expiry, Adjusted_Running_Balance, Prev_Balance
FROM (
    SELECT ITEMNMBR, Date_Expiry, ORDERNUMBER, Adjusted_Running_Balance,
           LAG(Adjusted_Running_Balance) OVER (PARTITION BY ITEMNMBR ORDER BY Date_Expiry, ORDERNUMBER) AS Prev_Balance
    FROM dbo.Rolyat_Final_Ledger_3
) AS balance_check
WHERE Adjusted_Running_Balance > Prev_Balance
    AND Prev_Balance IS NOT NULL;
GO

-- Test 6.1: Invalid stock-out signals
-- This test joins Rolyat_Final_Ledger_3 with Rolyat_WFQ_5
SELECT 'FAILURE: Test 6.1 - False negative balance' AS Failure_Type,
       fl.ITEMNMBR AS Item_Number, fl.Adjusted_Running_Balance, wfq.QTY_ON_HAND
FROM dbo.Rolyat_Final_Ledger_3 AS fl
LEFT JOIN dbo.Rolyat_WFQ_5 AS wfq ON fl.CleanItem = wfq.Item_Number
WHERE fl.Row_Type = 'DEMAND_EVENT'
    AND fl.Adjusted_Running_Balance < 0
    AND wfq.QTY_ON_HAND > 0;
    AND wfq.QTY_ON_HAND > 0

GO
