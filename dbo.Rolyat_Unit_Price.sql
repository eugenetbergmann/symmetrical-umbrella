USE [MED]
GO

/****** Object:  View [dbo].[Rolyat_Unit_Price]    Script Date: 1/13/2026 ******/
/*
================================================================================
VIEW: Rolyat_Unit_Price
PURPOSE: Calculate blended average cost per item at WF-Q location
DEPENDENCIES: 
  - dbo.IV00300 (Inventory lot table)
  - dbo.IV00101 (Item master)
DOWNSTREAM: Standalone reporting/costing view

BUSINESS LOGIC:
- Blended_Average_Cost = (AVG(CURRCOST) + AVG(UNITCOST)) / 2
- Only includes items with non-zero quantity at WF-Q
- Excludes expired inventory (expiry within 90 days)

CHANGES (2026-01-13):
- Removed TOP (100) PERCENT anti-pattern (ORDER BY in views is ignored)
- Added COALESCE to handle NULL costs from LEFT JOIN
- Added comprehensive header documentation
- Reformatted for readability
- Note: Add ORDER BY when querying this view, not in the view definition
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[Rolyat_Unit_Price]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_Unit_Price]
AS
SELECT 
    TRIM(inv.ITEMNMBR) AS Item_Number,
    TRIM(itm.UOMSCHDL) AS UOM,
    -- Blended cost with NULL protection
    -- If either cost is NULL, use the non-NULL value; if both NULL, result is NULL
    CASE 
        WHEN AVG(itm.CURRCOST) IS NULL AND AVG(inv.UNITCOST) IS NULL THEN NULL
        WHEN AVG(itm.CURRCOST) IS NULL THEN AVG(inv.UNITCOST)
        WHEN AVG(inv.UNITCOST) IS NULL THEN AVG(itm.CURRCOST)
        ELSE (AVG(itm.CURRCOST) + AVG(inv.UNITCOST)) / 2.0
    END AS Blended_Average_Cost

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
    TRIM(itm.UOMSCHDL)

HAVING 
    SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0;
GO
