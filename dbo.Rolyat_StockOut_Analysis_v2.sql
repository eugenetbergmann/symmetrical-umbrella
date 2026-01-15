WITH AlternateStock AS (
    SELECT
        Item_Number,
        SUM(CASE WHEN SITE = 'WF-Q' THEN QTY_ON_HAND ELSE 0 END) AS WFQ_QTY,
        SUM(CASE WHEN SITE = 'RMQTY' THEN QTY_ON_HAND ELSE 0 END) AS RMQTY_QTY,
        SUM(QTY_ON_HAND) AS Alternate_Stock
    FROM dbo.Rolyat_WFQ_5
    GROUP BY Item_Number
)
SELECT
    fl.*,

    -- Alternate stock quantities
    COALESCE(asq.WFQ_QTY, 0.0) AS WFQ_QTY,
    COALESCE(asq.RMQTY_QTY, 0.0) AS RMQTY_QTY,
    COALESCE(asq.Alternate_Stock, 0.0) AS Alternate_Stock,

    -- Deficit calculation (negative balance indicates stock-out)
    CASE
        WHEN fl.Adjusted_Running_Balance < 0 THEN ABS(fl.Adjusted_Running_Balance)
        ELSE 0.0
    END AS Deficit,

    -- Action tags for planners based on urgency rules
    CASE
        WHEN fl.Adjusted_Running_Balance < 0 AND fl.IsActiveWindow = 1 THEN
            CASE
                WHEN ABS(fl.Adjusted_Running_Balance) >= 100 THEN 'URGENT_PURCHASE'
                WHEN ABS(fl.Adjusted_Running_Balance) >= 50 THEN 'URGENT_TRANSFER'
                ELSE 'URGENT_EXPEDITE'
            END
        WHEN fl.Adjusted_Running_Balance < 0 AND COALESCE(asq.Alternate_Stock, 0.0) > 0 THEN 'REVIEW_ALTERNATE_STOCK'
        WHEN fl.Adjusted_Running_Balance < 0 THEN 'STOCK_OUT'
        ELSE 'NORMAL'
    END AS Action_Tag,

    -- QC flag updated for alternate stock awareness
    CASE
        WHEN fl.Adjusted_Running_Balance < 0 AND COALESCE(asq.Alternate_Stock, 0.0) <= 0 THEN 'REVIEW_NO_WC_AVAILABLE'
        ELSE fl.QC_Flag
    END AS Updated_QC_Flag

FROM dbo.Rolyat_Final_Ledger_3 AS fl
LEFT JOIN AlternateStock AS asq
    ON fl.CleanItem = asq.Item_Number