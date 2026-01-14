-- Violation Detection Queries for Existing Data
-- These queries should return NO ROWS if the views are correct
-- Any returned rows indicate failures

USE [MED];
GO

SET NOCOUNT ON;
GO

-- Test 1.1: Demands within window with WC inventory but not suppressed
-- This test uses inline CTE matching dbo.Rolyat_WC_Allocation_Effective_2
;WITH PrioritizedInventory AS (
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
    FROM dbo.Rolyat_Cleaned_Base_Demand_1 AS bd
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
),
WC_Allocation_Effective AS (
    SELECT
        ORDERNUMBER,
        CleanOrder,
        ITEMNMBR,
        CleanItem,
        WCID_From_MO,
        Construct,
        FG,
        FG_Desc,
        ItemDescription,
        UOMSCHDL,
        STSDESCR,
        MRPTYPE,
        VendorItem,
        INCLUDE_MRP,
        SITE,
        PRIME_VNDR,
        Date_Expiry,
        Expiry_Dates,
        DUEDATE,
        MRP_IssueDate,
        BEG_BAL,
        POs,
        Deductions,
        CleanDeductions,
        Expiry,
        Remaining,
        Running_Balance,
        Issued,
        PURCHASING_LT,
        PLANNING_LT,
        ORDER_POINT_QTY,
        SAFETY_STOCK,
        Has_Issued,
        IssueDate_Mismatch,
        Early_Issue_Flag,
        Base_Demand,
        WC_Item,
        WC_Site,
        Available_Qty,
        WC_DateReceived,
        WC_Age_Days,
        WC_Degradation_Factor,
        WC_Effective_Qty,
        WC_Batch_ID,
        pri_wcid_match,
        pri_expiry_proximity,
        pri_temporal_proximity,
        batch_prior_claimed_demand,
        allocated,
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
)
SELECT 'FAILURE: Test 1.1 - Unsuppressed demand within window' AS Failure_Type,
       ORDERNUMBER, ITEMNMBR, Date_Expiry, Base_Demand, effective_demand, WC_Batch_ID
FROM WC_Allocation_Effective
WHERE Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
    AND WC_Batch_ID IS NOT NULL
    AND effective_demand = Base_Demand
    AND Base_Demand > 0;
GO

-- Test 1.2: Demands outside window incorrectly suppressed
;WITH PrioritizedInventory AS (
    SELECT
        bd.ORDERNUMBER,
        bd.ITEMNMBR,
        bd.CleanItem,
        bd.SITE,
        bd.Date_Expiry,
        bd.Expiry_Dates,
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
    FROM dbo.Rolyat_Cleaned_Base_Demand_1 AS bd
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
),
WC_Allocation_Effective AS (
    SELECT
        ORDERNUMBER,
        ITEMNMBR,
        Date_Expiry,
        Base_Demand,
        allocated,
        CASE
            WHEN Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
            THEN CASE
                    WHEN Base_Demand - allocated > 0 THEN Base_Demand - allocated
                    ELSE 0.0
                 END
            ELSE Base_Demand
        END AS effective_demand
    FROM Allocated
)
SELECT 'FAILURE: Test 1.2 - Suppressed demand outside window' AS Failure_Type,
       ORDERNUMBER, ITEMNMBR, Date_Expiry, Base_Demand, effective_demand
FROM WC_Allocation_Effective
WHERE Date_Expiry NOT BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
    AND effective_demand < Base_Demand;
GO

-- Test 3.1: Incorrect degradation factors
;WITH PrioritizedInventory AS (
    SELECT
        bd.ORDERNUMBER,
        bd.ITEMNMBR,
        bd.CleanItem,
        bd.SITE,
        bd.Date_Expiry,
        bd.Expiry_Dates,
        bd.Base_Demand,
        w.DATERECD AS WC_DateReceived,
        DATEDIFF(DAY, w.DATERECD, GETDATE()) AS WC_Age_Days,
        CASE
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 30 THEN 1.00
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 60 THEN 0.75
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90 THEN 0.50
            ELSE 0.00
        END AS WC_Degradation_Factor
    FROM dbo.Rolyat_Cleaned_Base_Demand_1 AS bd
    LEFT JOIN dbo.ETB_WC_INV AS w
        ON LTRIM(RTRIM(w.Item_Number)) = bd.CleanItem
        AND w.SITE LIKE 'WC-W%'
        AND w.QTY_Available > 0
        AND ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) <= 21
        AND DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90
)
SELECT 'FAILURE: Test 3.1 - Wrong degradation factor' AS Failure_Type,
       ORDERNUMBER, ITEMNMBR, WC_Age_Days, WC_Degradation_Factor
FROM PrioritizedInventory
WHERE (WC_Age_Days <= 30 AND WC_Degradation_Factor != 1.00)
   OR (WC_Age_Days BETWEEN 31 AND 60 AND WC_Degradation_Factor != 0.75)
   OR (WC_Age_Days BETWEEN 61 AND 90 AND WC_Degradation_Factor != 0.50)
   OR (WC_Age_Days > 90 AND WC_Degradation_Factor != 0.00);
GO

-- Test 4.1: Double allocation - allocated exceeds batch effective qty
;WITH PrioritizedInventory AS (
    SELECT
        bd.ORDERNUMBER,
        bd.ITEMNMBR,
        bd.CleanItem,
        bd.SITE,
        bd.Date_Expiry,
        bd.Expiry_Dates,
        bd.Base_Demand,
        w.Item_Number AS WC_Item,
        w.SITE AS WC_Site,
        w.QTY_Available AS Available_Qty,
        w.DATERECD AS WC_DateReceived,
        DATEDIFF(DAY, w.DATERECD, GETDATE()) AS WC_Age_Days,
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
    FROM dbo.Rolyat_Cleaned_Base_Demand_1 AS bd
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
SELECT 'FAILURE: Test 4.1 - Double allocation' AS Failure_Type,
       WC_Batch_ID, SUM(allocated) AS Total_Allocated, MAX(WC_Effective_Qty) AS Batch_Effective_Qty
FROM Allocated
WHERE WC_Batch_ID IS NOT NULL
GROUP BY WC_Batch_ID
HAVING SUM(allocated) > MAX(WC_Effective_Qty);
GO

-- Test 5.1: Running balance anomalies (simplified check for sudden increases)
;WITH Final_Ledger AS (
    SELECT
        ORDERNUMBER,
        ITEMNMBR,
        CleanItem,
        Date_Expiry,
        BEG_BAL,
        POs,
        effective_demand,
        item_row_num,
        SUM(
            CASE WHEN item_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
            + CASE WHEN item_row_num = 1 THEN COALESCE(POs, 0.0) ELSE 0.0 END
            - effective_demand
        ) OVER (
            PARTITION BY ITEMNMBR
            ORDER BY Date_Expiry, ORDERNUMBER
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Adjusted_Running_Balance,
        CASE
            WHEN BEG_BAL > 0 THEN 'BEGINNING_BALANCE'
            WHEN POs > 0 THEN 'PURCHASE_ORDER'
            WHEN Base_Demand > 0 THEN 'DEMAND_EVENT'
            ELSE 'OTHER'
        END AS Row_Type
    FROM (
        SELECT
            a.ORDERNUMBER,
            a.ITEMNMBR,
            a.CleanItem,
            a.Date_Expiry,
            a.BEG_BAL,
            a.POs,
            a.Base_Demand,
            a.allocated,
            CASE
                WHEN a.Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
                THEN CASE
                        WHEN a.Base_Demand - a.allocated > 0 THEN a.Base_Demand - a.allocated
                        ELSE 0.0
                     END
                ELSE a.Base_Demand
            END AS effective_demand,
            ROW_NUMBER() OVER (
                PARTITION BY a.ITEMNMBR
                ORDER BY a.Date_Expiry, a.ORDERNUMBER
            ) AS item_row_num
        FROM (
            SELECT
                bd.ORDERNUMBER,
                bd.ITEMNMBR,
                bd.CleanItem,
                bd.SITE,
                bd.Date_Expiry,
                bd.Expiry_Dates,
                bd.BEG_BAL,
                bd.POs,
                bd.Base_Demand,
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
                ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) AS pri_temporal_proximity,
                CASE
                    WHEN ISNULL(w.Item_Number, '') + '|' + ISNULL(w.SITE, '') + '|' + ISNULL(w.LOT_Number, '') + '|' + ISNULL(FORMAT(w.DATERECD, 'yyyy-MM-dd'), '') IS NULL THEN 0.0
                    ELSE COALESCE(
                        SUM(bd.Base_Demand) OVER (
                            PARTITION BY ISNULL(w.Item_Number, '') + '|' + ISNULL(w.SITE, '') + '|' + ISNULL(w.LOT_Number, '') + '|' + ISNULL(FORMAT(w.DATERECD, 'yyyy-MM-dd'), '')
                            ORDER BY CASE WHEN w.SITE = bd.SITE THEN 1 ELSE 999 END, 
                                     ABS(DATEDIFF(DAY, COALESCE(w.EXPNDATE, '9999-12-31'), COALESCE(bd.Expiry_Dates, '9999-12-31'))),
                                     ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)), 
                                     bd.Date_Expiry, bd.ORDERNUMBER
                            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                        ), 0.0)
                END AS batch_prior_claimed_demand
            FROM dbo.Rolyat_Cleaned_Base_Demand_1 AS bd
            LEFT JOIN dbo.ETB_WC_INV AS w
                ON LTRIM(RTRIM(w.Item_Number)) = bd.CleanItem
                AND w.SITE LIKE 'WC-W%'
                AND w.QTY_Available > 0
                AND ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) <= 21
                AND DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90
        ) AS base
        CROSS APPLY (
            SELECT CASE
                WHEN base.WC_Batch_ID IS NULL THEN 0.0
                WHEN base.Base_Demand <= (base.WC_Effective_Qty - base.batch_prior_claimed_demand)
                    THEN base.Base_Demand
                WHEN (base.WC_Effective_Qty - base.batch_prior_claimed_demand) > 0
                    THEN (base.WC_Effective_Qty - base.batch_prior_claimed_demand)
                ELSE 0.0
            END AS allocated
        ) AS a(allocated)
    ) AS alloc
),
balance_check AS (
    SELECT ITEMNMBR, Date_Expiry, ORDERNUMBER, Adjusted_Running_Balance,
           LAG(Adjusted_Running_Balance) OVER (PARTITION BY ITEMNMBR ORDER BY Date_Expiry, ORDERNUMBER) AS Prev_Balance
    FROM Final_Ledger
)
SELECT 'FAILURE: Test 5.1 - Balance anomaly' AS Failure_Type,
       ITEMNMBR, Date_Expiry, Adjusted_Running_Balance, Prev_Balance
FROM balance_check
WHERE Adjusted_Running_Balance > Prev_Balance
    AND Prev_Balance IS NOT NULL;
GO

-- Test 6.1: Invalid stock-out signals
;WITH WFQ_Inventory AS (
    SELECT
        TRIM(inv.ITEMNMBR) AS Item_Number,
        TRIM(inv.LOCNCODE) AS SITE,
        TRIM(itm.UOMSCHDL) AS UOM,
        SUM(inv.QTYRECVD - inv.QTYSOLD) AS QTY_ON_HAND
    FROM dbo.IV00300 AS inv
    LEFT JOIN dbo.IV00101 AS itm
        ON inv.ITEMNMBR = itm.ITEMNMBR
    WHERE
        (inv.QTYRECVD - inv.QTYSOLD) <> 0
        AND TRIM(inv.LOCNCODE) = 'WF-Q'
        AND (inv.EXPNDATE IS NULL OR inv.EXPNDATE > DATEADD(DAY, 90, GETDATE()))
    GROUP BY
        TRIM(inv.ITEMNMBR),
        TRIM(inv.LOCNCODE),
        TRIM(itm.UOMSCHDL)
    HAVING
        SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0
),
Final_Ledger AS (
    SELECT
        ORDERNUMBER,
        ITEMNMBR,
        CleanItem,
        Date_Expiry,
        BEG_BAL,
        POs,
        effective_demand,
        item_row_num,
        SUM(
            CASE WHEN item_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
            + CASE WHEN item_row_num = 1 THEN COALESCE(POs, 0.0) ELSE 0.0 END
            - effective_demand
        ) OVER (
            PARTITION BY ITEMNMBR
            ORDER BY Date_Expiry, ORDERNUMBER
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Adjusted_Running_Balance,
        CASE
            WHEN BEG_BAL > 0 THEN 'BEGINNING_BALANCE'
            WHEN POs > 0 THEN 'PURCHASE_ORDER'
            WHEN Base_Demand > 0 THEN 'DEMAND_EVENT'
            ELSE 'OTHER'
        END AS Row_Type
    FROM (
        SELECT
            a.ORDERNUMBER,
            a.ITEMNMBR,
            a.CleanItem,
            a.Date_Expiry,
            a.BEG_BAL,
            a.POs,
            a.Base_Demand,
            a.allocated,
            CASE
                WHEN a.Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
                THEN CASE
                        WHEN a.Base_Demand - a.allocated > 0 THEN a.Base_Demand - a.allocated
                        ELSE 0.0
                     END
                ELSE a.Base_Demand
            END AS effective_demand,
            ROW_NUMBER() OVER (
                PARTITION BY a.ITEMNMBR
                ORDER BY a.Date_Expiry, a.ORDERNUMBER
            ) AS item_row_num
        FROM (
            SELECT
                bd.ORDERNUMBER,
                bd.ITEMNMBR,
                bd.CleanItem,
                bd.SITE,
                bd.Date_Expiry,
                bd.Expiry_Dates,
                bd.BEG_BAL,
                bd.POs,
                bd.Base_Demand,
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
                ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) AS pri_temporal_proximity,
                CASE
                    WHEN ISNULL(w.Item_Number, '') + '|' + ISNULL(w.SITE, '') + '|' + ISNULL(w.LOT_Number, '') + '|' + ISNULL(FORMAT(w.DATERECD, 'yyyy-MM-dd'), '') IS NULL THEN 0.0
                    ELSE COALESCE(
                        SUM(bd.Base_Demand) OVER (
                            PARTITION BY ISNULL(w.Item_Number, '') + '|' + ISNULL(w.SITE, '') + '|' + ISNULL(w.LOT_Number, '') + '|' + ISNULL(FORMAT(w.DATERECD, 'yyyy-MM-dd'), '')
                            ORDER BY CASE WHEN w.SITE = bd.SITE THEN 1 ELSE 999 END, 
                                     ABS(DATEDIFF(DAY, COALESCE(w.EXPNDATE, '9999-12-31'), COALESCE(bd.Expiry_Dates, '9999-12-31'))),
                                     ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)), 
                                     bd.Date_Expiry, bd.ORDERNUMBER
                            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                        ), 0.0)
                END AS batch_prior_claimed_demand
            FROM dbo.Rolyat_Cleaned_Base_Demand_1 AS bd
            LEFT JOIN dbo.ETB_WC_INV AS w
                ON LTRIM(RTRIM(w.Item_Number)) = bd.CleanItem
                AND w.SITE LIKE 'WC-W%'
                AND w.QTY_Available > 0
                AND ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) <= 21
                AND DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90
        ) AS base
        CROSS APPLY (
            SELECT CASE
                WHEN base.WC_Batch_ID IS NULL THEN 0.0
                WHEN base.Base_Demand <= (base.WC_Effective_Qty - base.batch_prior_claimed_demand)
                    THEN base.Base_Demand
                WHEN (base.WC_Effective_Qty - base.batch_prior_claimed_demand) > 0
                    THEN (base.WC_Effective_Qty - base.batch_prior_claimed_demand)
                ELSE 0.0
            END AS allocated
        ) AS a(allocated)
    ) AS alloc
)
SELECT 'FAILURE: Test 6.1 - False negative balance' AS Failure_Type,
       fl.ITEMNMBR AS Item_Number, fl.Adjusted_Running_Balance, wfq.QTY_ON_HAND
FROM Final_Ledger AS fl
LEFT JOIN WFQ_Inventory AS wfq ON fl.CleanItem = wfq.Item_Number
WHERE fl.Row_Type = 'DEMAND_EVENT'
    AND fl.Adjusted_Running_Balance < 0
    AND wfq.QTY_ON_HAND > 0;
GO
