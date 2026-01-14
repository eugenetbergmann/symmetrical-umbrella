;WITH PrioritizedInventory AS (
    -- Layer 3: Join demand with WC inventory and calculate priorities
    SELECT
        -- Pass through all demand columns
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

        -- WC Inventory columns
        w.Item_Number AS WC_Item,
        w.SITE AS WC_Site,
        w.QTY_Available AS Available_Qty,
        w.DATERECD AS WC_DateReceived,

        -- WC Age calculation
        DATEDIFF(DAY, w.DATERECD, GETDATE()) AS WC_Age_Days,

        -- Degradation factor based on inventory age
        CASE
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 30 THEN 1.00
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 60 THEN 0.75
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90 THEN 0.50
            ELSE 0.00
        END AS WC_Degradation_Factor,

        -- Effective quantity after degradation
        w.QTY_Available * CASE
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 30 THEN 1.00
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 60 THEN 0.75
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90 THEN 0.50
            ELSE 0.00
        END AS WC_Effective_Qty,

        -- Unique batch identifier for allocation partitioning
        ISNULL(w.Item_Number, '') + '|' +
        ISNULL(w.SITE, '') + '|' +
        ISNULL(w.LOT_Number, '') + '|' +
        ISNULL(FORMAT(w.DATERECD, 'yyyy-MM-dd'), '') AS WC_Batch_ID,

        -- Priority scores for FEFO allocation (lower = higher priority)
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
    -- Layer 4: Calculate cumulative demand claimed by prior rows within each WC batch
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
    -- Calculate allocation for each row
    SELECT
        pc.*,

        -- Calculate allocation
        CASE
            WHEN WC_Batch_ID IS NULL THEN 0.0
            WHEN Base_Demand <= (WC_Effective_Qty - batch_prior_claimed_demand)
                THEN Base_Demand  -- Full demand can be satisfied
            WHEN (WC_Effective_Qty - batch_prior_claimed_demand) > 0
                THEN (WC_Effective_Qty - batch_prior_claimed_demand)  -- Partial allocation
            ELSE 0.0  -- No remaining inventory in batch
        END AS allocated

    FROM PriorClaimed AS pc
)
-- Layer 5: Calculate effective demand and allocation status
SELECT
    -- Pass through all columns from allocation layer
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

    -- Calculate effective demand based on active window
    CASE
        WHEN Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
        THEN CASE
                WHEN Base_Demand - allocated > 0 THEN Base_Demand - allocated
                ELSE 0.0
             END
        ELSE Base_Demand
    END AS effective_demand,

    -- Allocation status for reporting
    CASE
        WHEN Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
        THEN CASE
                WHEN allocated > 0 THEN 'WC_Suppressed'
                ELSE 'No_WC_Allocation'
             END
        ELSE 'Outside_Active_Window'
    END AS wc_allocation_status,

    -- Row number within each item for deduplication in Final_Ledger
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Date_Expiry, ORDERNUMBER
    ) AS item_row_num

FROM Allocated;