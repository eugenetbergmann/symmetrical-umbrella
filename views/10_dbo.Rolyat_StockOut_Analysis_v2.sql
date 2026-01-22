/*
================================================================================
View: dbo.Rolyat_StockOut_Analysis_v2
Description: Stock-out intelligence with action tags and alternate stock awareness
Version: 2.0.1 (CORRECTED)
Last Modified: 2026-01-20
Changes: 
  - Fixed ATP_Running_Balance → effective_demand (balance AFTER allocation)
  - Fixed Forecast_Running_Balance → Original_Running_Balance (balance BEFORE allocation)
  - IsActiveWindow already correct (no change)
Dependencies: 
  - dbo.Rolyat_Final_Ledger_3
  - dbo.Rolyat_WFQ_5

Purpose:
  - Identifies stock-out conditions from ATP and Forecast balances
  - Calculates deficit quantities for planning
  - Assigns action tags based on urgency and alternate stock availability
  - Provides QC flags for planner review

Business Rules:
  - ATP = Available after WC batch allocation (effective_demand)
  - Forecast = Original running balance before allocation
  - Action tags prioritize urgency: URGENT_PURCHASE > URGENT_TRANSFER > URGENT_EXPEDITE
  - Alternate stock (WFQ + RMQTY) triggers REVIEW_ALTERNATE_STOCK tag
  - QC flag REVIEW_NO_WC_AVAILABLE only when no alternate stock exists
  - Deficit thresholds: >=100 (PURCHASE), >=50 (TRANSFER), <50 (EXPEDITE)
================================================================================
*/



SELECT
    fl.effective_demand,
    fl.Original_Running_Balance,
    fl.IsActiveWindow,
    fl.CleanItem,

    -- ============================================================
    -- Alternate Stock Quantities
    -- ============================================================
    COALESCE(asq.WFQ_QTY, 0.0) AS WFQ_QTY,
    COALESCE(asq.RMQTY_QTY, 0.0) AS RMQTY_QTY,
    COALESCE(asq.Alternate_Stock, 0.0) AS Alternate_Stock,

    -- ============================================================
    -- Deficit Calculations
    -- CORRECTED: ATP = effective_demand (after allocation)
    -- ============================================================
    CASE
        WHEN fl.effective_demand < 0 THEN ABS(fl.effective_demand)
        ELSE 0.0
    END AS Deficit_ATP,

    -- CORRECTED: Forecast = Original_Running_Balance (before allocation)
    CASE
        WHEN fl.Original_Running_Balance < 0 THEN ABS(fl.Original_Running_Balance)
        ELSE 0.0
    END AS Deficit_Forecast,

    -- ============================================================
    -- Action Tags for Planners
    -- CORRECTED: ATP = effective_demand, Forecast = Original_Running_Balance
    -- ============================================================
    CASE
        -- ATP constrained but Forecast OK: allocation/batch timing issue
        -- (Would be fine without batch constraints, but batches create shortage)
        WHEN fl.effective_demand < 0 AND fl.Original_Running_Balance >= 0
            THEN 'ATP_CONSTRAINED'

        -- ATP deficit within active window: urgent action required
        WHEN fl.effective_demand < 0 AND fl.IsActiveWindow = 1 THEN
            CASE
                -- Large deficit: purchase required
                WHEN ABS(fl.effective_demand) >= 100 THEN 'URGENT_PURCHASE'
                -- Medium deficit: transfer from alternate location
                WHEN ABS(fl.effective_demand) >= 50 THEN 'URGENT_TRANSFER'
                -- Small deficit: expedite existing orders
                ELSE 'URGENT_EXPEDITE'
            END

        -- ATP deficit with alternate stock available: review options
        WHEN fl.effective_demand < 0 AND COALESCE(asq.Alternate_Stock, 0.0) > 0
            THEN 'REVIEW_ALTERNATE_STOCK'

        -- ATP deficit with no alternate stock: stock-out
        WHEN fl.effective_demand < 0
            THEN 'STOCK_OUT'

        -- No deficit: normal status
        ELSE 'NORMAL'
    END AS Action_Tag,

    -- ============================================================
    -- QC Flag
    -- CORRECTED: Using effective_demand (ATP)
    -- ============================================================
    CASE
        WHEN fl.effective_demand < 0 AND COALESCE(asq.Alternate_Stock, 0.0) <= 0
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
