/*
================================================================================
View: dbo.Rolyat_StockOut_Analysis_v2
Description: Stock-out intelligence with action tags and alternate stock awareness
Version: 2.0.0
Last Modified: 2026-01-16
Dependencies: 
  - dbo.Rolyat_Final_Ledger_3
  - dbo.Rolyat_WFQ_5

Purpose:
  - Identifies stock-out conditions from ATP and Forecast balances
  - Calculates deficit quantities for planning
  - Assigns action tags based on urgency and alternate stock availability
  - Provides QC flags for planner review

Business Rules:
  - Action tags prioritize urgency: URGENT_PURCHASE > URGENT_TRANSFER > URGENT_EXPEDITE
  - Alternate stock (WFQ + RMQTY) triggers REVIEW_ALTERNATE_STOCK tag
  - QC flag REVIEW_NO_WC_AVAILABLE only when no alternate stock exists
  - Deficit thresholds: >=100 (PURCHASE), >=50 (TRANSFER), <50 (EXPEDITE)
================================================================================
*/



SELECT
    fl.ORDERNUMBER,
    fl.CleanOrder,
    fl.ITEMNMBR,
    fl.CleanItem,
    fl.WCID_From_MO,
    fl.Construct,
    fl.Client_ID,
    fl.FG,
    fl.FG_Desc,
    fl.ItemDescription,
    fl.UOMSCHDL,
    fl.STSDESCR,
    fl.MRPTYPE,
    fl.VendorItem,
    fl.INCLUDE_MRP,
    fl.Site_ID,
    fl.PRIME_VN,
    fl.BEG_BAL,
    fl.Base_Demand,
    fl.effective_demand,
    fl.Date_Expiry,
    fl.SortPriority,
    fl.IsActiveWindow,
    fl.ATP_Running_Balance,
    fl.Forecast_Running_Balance,
    fl.Adjusted_Running_Balance,
    fl.Stock_Out_Flag,
    fl.Potential_Deficit_Flag,
    fl.WC_Allocation_Applied_Flag,
    fl.Status_Description,
    fl.Item_Lead_Time_Days,
    fl.Item_Safety_Stock,
    fl.Original_Deductions,
    fl.Original_Expiry,
    fl.Original_POs,
    fl.Original_Running_Balance,
    fl.MRP_Issued_Qty,
    fl.MRP_Remaining_Qty,

    -- ============================================================
    -- Alternate Stock Quantities
    -- ============================================================
    COALESCE(asq.WFQ_QTY, 0.0) AS WFQ_QTY,
    COALESCE(asq.RMQTY_QTY, 0.0) AS RMQTY_QTY,
    COALESCE(asq.Alternate_Stock, 0.0) AS Alternate_Stock,

    -- ============================================================
    -- Deficit Calculations
    -- Negative balance indicates stock-out; deficit = absolute value
    -- ============================================================
    CASE
        WHEN fl.ATP_Running_Balance < 0 THEN ABS(fl.ATP_Running_Balance)
        ELSE 0.0
    END AS Deficit_ATP,
    
    CASE
        WHEN fl.Forecast_Running_Balance < 0 THEN ABS(fl.Forecast_Running_Balance)
        ELSE 0.0
    END AS Deficit_Forecast,

    -- ============================================================
    -- Action Tags for Planners
    -- Based on urgency rules and alternate stock availability
    -- ============================================================
    CASE
        -- ATP constrained but Forecast OK: supply timing issue
        WHEN fl.ATP_Running_Balance < 0 AND fl.Forecast_Running_Balance >= 0 
            THEN 'ATP_CONSTRAINED'
        
        -- ATP deficit within active window: urgent action required
        WHEN fl.ATP_Running_Balance < 0 AND fl.IsActiveWindow = 1 THEN
            CASE
                -- Large deficit: purchase required
                WHEN ABS(fl.ATP_Running_Balance) >= 100 THEN 'URGENT_PURCHASE'
                -- Medium deficit: transfer from alternate location
                WHEN ABS(fl.ATP_Running_Balance) >= 50 THEN 'URGENT_TRANSFER'
                -- Small deficit: expedite existing orders
                ELSE 'URGENT_EXPEDITE'
            END
        
        -- ATP deficit with alternate stock available: review options
        WHEN fl.ATP_Running_Balance < 0 AND COALESCE(asq.Alternate_Stock, 0.0) > 0 
            THEN 'REVIEW_ALTERNATE_STOCK'
        
        -- ATP deficit with no alternate stock: stock-out
        WHEN fl.ATP_Running_Balance < 0 
            THEN 'STOCK_OUT'
        
        -- No deficit: normal status
        ELSE 'NORMAL'
    END AS Action_Tag,

    -- ============================================================
    -- QC Flag
    -- Flags items needing review when no WC available and ATP negative
    -- ============================================================
    CASE
        WHEN fl.ATP_Running_Balance < 0 AND COALESCE(asq.Alternate_Stock, 0.0) <= 0
            THEN 'REVIEW_NO_WC_AVAILABLE'
        ELSE NULL
    END AS QC_Flag

FROM dbo.Rolyat_Final_Ledger_3 AS fl
LEFT JOIN (
    SELECT
        ITEMNMBR AS Item_Number,
        -- WFQ quantity (quarantine)
        SUM(CASE WHEN Site_ID = 'WF-Q' THEN QTY_ON_HAND ELSE 0 END) AS WFQ_QTY,
        -- RMQTY quantity (restricted material)
        SUM(CASE WHEN Site_ID = 'RMQTY' THEN QTY_ON_HAND ELSE 0 END) AS RMQTY_QTY,
        -- Total alternate stock
        SUM(QTY_ON_HAND) AS Alternate_Stock
    FROM dbo.Rolyat_WFQ_5
    GROUP BY ITEMNMBR
) AS asq
    ON fl.CleanItem = asq.Item_Number
