USE [MED]
GO

/****** Object:  View [dbo].[Rolyat_Intelligence]    Script Date: 1/14/2026 ******/
/*
================================================================================
VIEW: Rolyat_Intelligence
PURPOSE: Merged intelligence layer - WF-Q inventory and stock-out analysis
DEPENDENCIES: 
  - dbo.IV00300 (Inventory lot table)
  - dbo.IV00101 (Item master)
  - dbo.Rolyat_Final_Ledger
DOWNSTREAM: Dashboard consumption

BUSINESS LOGIC:
- WF-Q inventory aggregation by item
- Stock-out analysis for negative balances
- Coverage classification and action priorities

CHANGES (2026-01-14):
- Merged Rolyat_WFQ and Rolyat_StockOut_Analysis_v2
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[Rolyat_Intelligence]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_Intelligence]
AS
-- WF-Q Inventory Section
SELECT 
    'WFQ_INVENTORY' AS Record_Type,
    TRIM(inv.ITEMNMBR) AS Item_Number,
    TRIM(inv.LOCNCODE) AS SITE,
    TRIM(itm.UOMSCHDL) AS UOM,
    SUM(inv.QTYRECVD - inv.QTYSOLD) AS QTY_ON_HAND,
    NULL AS Adjusted_Running_Balance,
    NULL AS Coverage_Classification,
    NULL AS Action_Priority

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

UNION ALL

-- Stock-Out Analysis Section
SELECT 
    'STOCK_OUT' AS Record_Type,
    fl.ITEMNMBR AS Item_Number,
    fl.SITE,
    fl.UOMSCHDL AS UOM,
    wf.QTY_ON_HAND,
    fl.Adjusted_Running_Balance,
    CASE
        WHEN fl.WC_Inventory_Applied >= fl.Base_Demand THEN 'FULL'
        WHEN fl.WC_Inventory_Applied > 0 THEN 'PARTIAL'
        ELSE 'NONE'
    END AS Coverage_Classification,
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
    AND fl.Construct = 297;
GO