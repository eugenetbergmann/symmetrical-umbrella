SELECT
    -- Core identifiers
    ORDERNUMBER,
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

    -- Date fields
    Date_Expiry,
    Expiry_Dates,
    DUEDATE,
    MRP_IssueDate,

    -- Original quantity fields
    BEG_BAL,
    POs,
    Deductions,
    CleanDeductions,
    Expiry,
    Remaining,
    Running_Balance AS Original_Running_Balance,
    Issued,

    -- Planning parameters
    PURCHASING_LT,
    PLANNING_LT,
    ORDER_POINT_QTY,
    SAFETY_STOCK,

    -- Status flags
    Has_Issued,
    IssueDate_Mismatch,
    Early_Issue_Flag,

    -- WC allocation fields
    Base_Demand,
    allocated AS WC_Inventory_Applied,
    effective_demand AS Effective_Demand,
    wc_allocation_status,
    Client_ID,
    WFQ_QTY,
    RMQTY_QTY,
    RMQTY_Client_ID,
    Released_PO_Qty,
    RMQTY_Eligible_Qty,
    ATP_Suppression_Qty,

    -- Forecast supply event (per item)
    CASE WHEN item_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
    + CASE WHEN item_row_num = 1 THEN COALESCE(POs, 0.0) ELSE 0.0 END
    + CASE WHEN item_row_num = 1 THEN COALESCE(WFQ_QTY, 0.0) ELSE 0.0 END
    + CASE WHEN item_row_num = 1 THEN COALESCE(RMQTY_QTY, 0.0) ELSE 0.0 END
        AS Forecast_Supply_Event,

    -- ATP supply event (per client)
    CASE WHEN client_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
    + CASE WHEN client_row_num = 1 THEN COALESCE(Released_PO_Qty, 0.0) ELSE 0.0 END
    + CASE WHEN client_row_num = 1 THEN COALESCE(RMQTY_Eligible_Qty, 0.0) ELSE 0.0 END
        AS ATP_Supply_Event,

    -- Forecast running balance (potential inventory)
    SUM(
        (CASE WHEN item_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
         + CASE WHEN item_row_num = 1 THEN COALESCE(POs, 0.0) ELSE 0.0 END
         + CASE WHEN item_row_num = 1 THEN COALESCE(WFQ_QTY, 0.0) ELSE 0.0 END
         + CASE WHEN item_row_num = 1 THEN COALESCE(RMQTY_QTY, 0.0) ELSE 0.0 END)
        - Base_Demand
    ) OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS Forecast_Running_Balance,

    -- ATP running balance (consumable now, client-restricted)
    SUM(
        (CASE WHEN client_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
         + CASE WHEN client_row_num = 1 THEN COALESCE(Released_PO_Qty, 0.0) ELSE 0.0 END
         + CASE WHEN client_row_num = 1 THEN COALESCE(RMQTY_Eligible_Qty, 0.0) ELSE 0.0 END)
        - effective_demand
    ) OVER (
        PARTITION BY ITEMNMBR, Client_ID
        ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ATP_Running_Balance,

    -- Backward-compatible running balance (aligned to ATP)
    SUM(
        (CASE WHEN client_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
         + CASE WHEN client_row_num = 1 THEN COALESCE(Released_PO_Qty, 0.0) ELSE 0.0 END
         + CASE WHEN client_row_num = 1 THEN COALESCE(RMQTY_Eligible_Qty, 0.0) ELSE 0.0 END)
        - effective_demand
    ) OVER (
        PARTITION BY ITEMNMBR, Client_ID
        ORDER BY Date_Expiry, SortPriority, ORDERNUMBER
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS Adjusted_Running_Balance,

    -- Row type classification
    CASE
        WHEN BEG_BAL > 0 THEN 'BEGINNING_BALANCE'
        WHEN POs > 0 THEN 'PURCHASE_ORDER'
        WHEN Base_Demand > 0 THEN 'DEMAND_EVENT'
        ELSE 'OTHER'
    END AS Row_Type,

    -- Demand validation status
    CASE
        WHEN allocated >= Base_Demand AND Base_Demand > 0 THEN 'FULLY_SUPPLIED'
        WHEN allocated > 0 THEN 'PARTIALLY_SUPPLIED'
        ELSE 'NO_WC_ALLOCATED'
    END AS Demand_Validation_Status,

    -- Allocation efficiency flag
    CASE
        WHEN allocated = 0 AND Base_Demand > 0 THEN 'NO_ALLOCATION'
        WHEN allocated < Base_Demand THEN 'PARTIAL_ALLOCATION'
        ELSE 'FULL_ALLOCATION'
    END AS Allocation_Efficiency_Flag,

    -- QC flag for urgent items
    CASE
        WHEN effective_demand > 0 AND Date_Expiry BETWEEN GETDATE() AND DATEADD(DAY, 3, GETDATE())
            THEN 'URGENT_UNMET_DEMAND'
        WHEN wc_allocation_status IN ('No_Allocation', 'No_WC_Allocation') AND Base_Demand > 0
            THEN 'REVIEW_NO_WC_AVAILABLE'
        ELSE 'NORMAL'
    END AS QC_Flag

FROM dbo.Rolyat_WC_Allocation_Effective_2
