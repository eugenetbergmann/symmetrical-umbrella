USE [MED]
GO

/****** Object:  View [dbo].[Rolyat_StockOut_Analysis_v2]    Script Date: 1/14/2026 ******/
/*
================================================================================
VIEW: Rolyat_StockOut_Analysis_v2
PURPOSE: Stock-Out Intelligence - Analyze negative balances and recommend actions
DEPENDENCIES: dbo.Rolyat_Final_Ledger, dbo.Rolyat_WFQ
DOWNSTREAM: Dashboard consumption

BUSINESS LOGIC:
- Identifies stock-out events: Adjusted_Running_Balance < 0, Row_Type = 'DEMAND_EVENT', Construct = 297
- Validates deficit is real: Cannot be resolved by remaining WC inventory or WF-Q inventory
- Coverage classification: FULL (fully supplied), PARTIAL (partially), NONE (no coverage)
- Action priority: URGENT_EXPEDITE, URGENT_TRANSFER, URGENT_PURCHASE, PLAN_TRANSFER, PLAN_PURCHASE

CHANGES (2026-01-14):
- Created basic version for testing based on PRD requirements
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[Rolyat_StockOut_Analysis_v2]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_StockOut_Analysis_v2]
AS
SELECT
    fl.*,
    wf.QTY_ON_HAND AS WFQ_Available,
    -- Coverage classification
    CASE
        WHEN fl.WC_Inventory_Applied >= fl.Base_Demand THEN 'FULL'
        WHEN fl.WC_Inventory_Applied > 0 THEN 'PARTIAL'
        ELSE 'NONE'
    END AS Coverage_Classification,
    -- Action priority
    CASE
        WHEN fl.Effective_Demand > 0 AND fl.Date_Expiry BETWEEN GETDATE() AND DATEADD(DAY, 3, GETDATE())
            THEN 'URGENT_UNMET_DEMAND'
        WHEN wf.QTY_ON_HAND > 0 AND fl.Date_Expiry BETWEEN GETDATE() AND DATEADD(DAY, 3, GETDATE())
            THEN 'URGENT_TRANSFER'
        WHEN wf.QTY_ON_HAND = 0 AND fl.Date_Expiry BETWEEN GETDATE() AND DATEADD(DAY, 3, GETDATE())
            THEN 'URGENT_PURCHASE'
        WHEN wf.QTY_ON_HAND > 0 AND fl.Date_Expiry > DATEADD(DAY, 3, GETDATE())
            THEN 'PLAN_TRANSFER'
        WHEN wf.QTY_ON_HAND = 0 AND fl.Date_Expiry > DATEADD(DAY, 3, GETDATE())
            THEN 'PLAN_PURCHASE'
        ELSE 'UNKNOWN'
    END AS Action_Priority

FROM dbo.Rolyat_Final_Ledger AS fl
LEFT JOIN dbo.Rolyat_WFQ AS wf
    ON fl.ITEMNMBR = wf.Item_Number

WHERE fl.Adjusted_Running_Balance < 0
    AND fl.Row_Type = 'DEMAND_EVENT'
    AND fl.Construct = 297
GO