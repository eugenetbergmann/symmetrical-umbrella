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

CREATE VIEW dbo.Rolyat_StockOut_Analysis_v2
AS

-- ============================================================
-- CTE: Aggregate Alternate Stock per Item
-- ============================================================
WITH AlternateStock AS (
    SELECT
        Item_Number,
        -- WFQ quantity (quarantine)
        SUM(CASE WHEN SITE = 'WF-Q' THEN QTY_ON_HAND ELSE 0 END) AS WFQ_QTY,
        -- RMQTY quantity (restricted material)
        SUM(CASE WHEN SITE = 'RMQTY' THEN QTY_ON_HAND ELSE 0 END) AS RMQTY_QTY,
        -- Total alternate stock
        SUM(QTY_ON_HAND) AS Alternate_Stock
    FROM dbo.Rolyat_WFQ_5
    GROUP BY Item_Number
)

SELECT
    fl.*,

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
    -- Updated QC Flag
    -- Adds alternate stock awareness to QC review condition
    -- ============================================================
    CASE
        WHEN fl.ATP_Running_Balance < 0 AND COALESCE(asq.Alternate_Stock, 0.0) <= 0 
            THEN 'REVIEW_NO_WC_AVAILABLE'
        ELSE fl.QC_Flag
    END AS Updated_QC_Flag

FROM dbo.Rolyat_Final_Ledger_3 AS fl
LEFT JOIN AlternateStock AS asq
    ON fl.CleanItem = asq.Item_Number

GO

-- Add extended property for documentation
EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Stock-out analysis view with action tags, deficit calculations, and alternate stock awareness. Provides planner-ready intelligence for inventory management.',
    @level0type = N'SCHEMA', @level0name = 'dbo',
    @level1type = N'VIEW', @level1name = 'Rolyat_StockOut_Analysis_v2'
GO
