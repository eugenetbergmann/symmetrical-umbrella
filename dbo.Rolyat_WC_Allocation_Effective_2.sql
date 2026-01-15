WITH AlternateStock AS (
    SELECT
        Item_Number,
        Client_ID,
        SUM(CASE WHEN SITE = 'WF-Q' THEN QTY_ON_HAND ELSE 0 END) AS WFQ_QTY,
        SUM(CASE WHEN SITE = 'RMQTY' THEN QTY_ON_HAND ELSE 0 END) AS RMQTY_QTY
    FROM dbo.Rolyat_WFQ_5
    GROUP BY Item_Number, Client_ID
),
AltStock_Item AS (
    SELECT
        Item_Number,
        SUM(CASE WHEN SITE = 'WF-Q' THEN QTY_ON_HAND ELSE 0 END) AS WFQ_QTY
    FROM dbo.Rolyat_WFQ_5
    GROUP BY Item_Number
),
PrioritizedInventory AS (
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
        'UNASSIGNED' AS Client_ID,
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

        -- Alternate stock (WFQ/RMQTY)
        COALESCE(asi.WFQ_QTY, 0.0) AS WFQ_QTY,
        COALESCE(ascq.RMQTY_QTY, 0.0) AS RMQTY_QTY,
        COALESCE(ascq.Client_ID, 'UNASSIGNED') AS RMQTY_Client_ID,

        -- PO released to ATP only when issue date or due date is in the past
        CASE
            WHEN bd.POs > 0
             AND COALESCE(bd.MRP_IssueDate, bd.DUEDATE) <= CAST(GETDATE() AS DATE)
                THEN bd.POs
            ELSE 0.0
        END AS Released_PO_Qty,

        -- RMQTY is client-restricted (only eligible when client matches)
        CASE
            WHEN COALESCE(ascq.Client_ID, 'UNASSIGNED') = 'UNASSIGNED'
                THEN COALESCE(ascq.RMQTY_QTY, 0.0)
            ELSE 0.0
        END AS RMQTY_Eligible_Qty,

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
        ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) AS pri_temporal_proximity,

        -- Include SortPriority for deterministic ordering
        bd.SortPriority,
        bd.IsActiveWindow

    FROM dbo.Rolyat_Cleaned_Base_Demand_1 AS bd
    LEFT JOIN AltStock_Item AS asi
        ON bd.CleanItem = asi.Item_Number
    LEFT JOIN AlternateStock AS ascq
        ON bd.CleanItem = ascq.Item_Number
       AND ascq.Client_ID = 'UNASSIGNED'
    LEFT JOIN dbo.ETB_WC_INV AS w
        ON LTRIM(RTRIM(w.Item_Number)) = bd.CleanItem
        AND w.SITE LIKE 'WC-W%'
        AND w.QTY_Available > 0
        AND bd.IsActiveWindow = 1
        AND ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) <= 21
        AND DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90
),
PriorClaimed AS (
    -- Layer 4: Calculate cumulative demand claimed by prior rows within each WC batch
    SELECT
        pi.*,
        ROW_NUMBER() OVER (
            PARTITION BY ITEMNMBR, Client_ID
            ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
        ) AS client_row_num,
        CASE
            WHEN WC_Batch_ID IS NULL THEN 0.0
            ELSE COALESCE(
                SUM(Base_Demand) OVER (
                    PARTITION BY WC_Batch_ID
                    ORDER BY Date_Expiry, SortPriority, pri_wcid_match, pri_expiry_proximity, pri_temporal_proximity, ORDERNUMBER
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
),
ATPWindow AS (
    SELECT
        a.*,
        -- ATP supply event (client-restricted)
        CASE WHEN client_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
        + CASE WHEN client_row_num = 1 THEN COALESCE(Released_PO_Qty, 0.0) ELSE 0.0 END
        + CASE WHEN client_row_num = 1 THEN COALESCE(RMQTY_Eligible_Qty, 0.0) ELSE 0.0 END
            AS ATP_Supply_Event,
        -- ATP available before this demand (excludes current row)
        SUM(
            (CASE WHEN client_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
             + CASE WHEN client_row_num = 1 THEN COALESCE(Released_PO_Qty, 0.0) ELSE 0.0 END
             + CASE WHEN client_row_num = 1 THEN COALESCE(RMQTY_Eligible_Qty, 0.0) ELSE 0.0 END)
            - (Base_Demand - allocated)
        ) OVER (
            PARTITION BY ITEMNMBR, Client_ID
            ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS ATP_Available_Prior
    FROM Allocated AS a
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
    Client_ID,
    WFQ_QTY,
    RMQTY_QTY,
    RMQTY_Client_ID,
    Released_PO_Qty,
    RMQTY_Eligible_Qty,
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
    client_row_num,
    ATP_Supply_Event,
    ATP_Available_Prior,

    -- ATP suppression within active window
    CASE
        WHEN IsActiveWindow = 1 THEN
            CASE
                WHEN (Base_Demand - allocated) <= COALESCE(ATP_Available_Prior, 0.0)
                    THEN (Base_Demand - allocated)
                WHEN COALESCE(ATP_Available_Prior, 0.0) > 0
                    THEN COALESCE(ATP_Available_Prior, 0.0)
                ELSE 0.0
            END
        ELSE 0.0
    END AS ATP_Suppression_Qty,

    -- Calculate effective demand based on active window
    CASE
        WHEN Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
        THEN CASE
                WHEN Base_Demand - allocated -
                     (CASE
                        WHEN (Base_Demand - allocated) <= COALESCE(ATP_Available_Prior, 0.0)
                            THEN (Base_Demand - allocated)
                        WHEN COALESCE(ATP_Available_Prior, 0.0) > 0
                            THEN COALESCE(ATP_Available_Prior, 0.0)
                        ELSE 0.0
                      END) > 0
                    THEN Base_Demand - allocated -
                     (CASE
                        WHEN (Base_Demand - allocated) <= COALESCE(ATP_Available_Prior, 0.0)
                            THEN (Base_Demand - allocated)
                        WHEN COALESCE(ATP_Available_Prior, 0.0) > 0
                            THEN COALESCE(ATP_Available_Prior, 0.0)
                        ELSE 0.0
                      END)
                ELSE 0.0
             END
        ELSE Base_Demand
    END AS effective_demand,

    -- Allocation status for reporting
    CASE
        WHEN Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
        THEN CASE
                WHEN allocated > 0 AND ATP_Suppression_Qty > 0 THEN 'WC_ATP_Suppressed'
                WHEN allocated > 0 THEN 'WC_Suppressed'
                WHEN ATP_Suppression_Qty > 0 THEN 'ATP_Suppressed'
                ELSE 'No_Allocation'
             END
        ELSE 'Outside_Active_Window'
    END AS wc_allocation_status,

    -- Include SortPriority and IsActiveWindow
    SortPriority,
    IsActiveWindow,

    -- Row number within each item for deduplication in Final_Ledger
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
    ) AS item_row_num

FROM ATPWindow
