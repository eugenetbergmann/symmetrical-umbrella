USE [MED]
GO

/****** Object:  View [dbo].[Rolyat_WFQ]    Script Date: 1/13/2026 ******/
/*
================================================================================
VIEW: Rolyat_WFQ
PURPOSE: WF-Q location inventory summary
DEPENDENCIES: 
  - dbo.IV00300 (Inventory lot table)
  - dbo.IV00101 (Item master)
DOWNSTREAM: Standalone reporting view

BUSINESS LOGIC:
- Aggregates inventory at WF-Q location by item
- Excludes zero-quantity lots
- Excludes expired inventory (expiry within 90 days)
- QTY_ON_HAND = SUM(QTYRECVD - QTYSOLD)

CHANGES (2026-01-13):
- Removed TOP (100) PERCENT anti-pattern (ORDER BY in views is ignored)
- Added comprehensive header documentation
- Reformatted for readability
- Note: Add ORDER BY when querying this view, not in the view definition
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[Rolyat_WFQ]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_WFQ]
AS
SELECT 
    TRIM(inv.ITEMNMBR) AS Item_Number,
    TRIM(inv.LOCNCODE) AS SITE,
    TRIM(itm.UOMSCHDL) AS UOM,
    SUM(inv.QTYRECVD - inv.QTYSOLD) AS QTY_ON_HAND

FROM dbo.IV00300 AS inv
LEFT JOIN dbo.IV00101 AS itm 
    ON inv.ITEMNMBR = itm.ITEMNMBR

WHERE 
    -- Exclude zero-quantity lots
    (inv.QTYRECVD - inv.QTYSOLD) <> 0
    -- WF-Q location only
    AND TRIM(inv.LOCNCODE) = 'WF-Q'
    -- Exclude expired or soon-to-expire inventory
    AND (inv.EXPNDATE IS NULL OR inv.EXPNDATE > DATEADD(DAY, 90, GETDATE()))

GROUP BY 
    TRIM(inv.ITEMNMBR),
    TRIM(inv.LOCNCODE),
    TRIM(itm.UOMSCHDL)

HAVING 
    SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0;
GO
