/*
================================================================================
View: dbo.Rolyat_Unit_Price_4
Description: Blended average cost calculation for WF-Q inventory items
Version: 1.0.0
Last Modified: 2026-01-16
Dependencies: 
  - dbo.IV00300 (Inventory Lot Master)
  - dbo.IV00101 (Item Master)

Purpose:
  - Calculates blended average cost from current cost and unit cost
  - Filters to WF-Q location inventory only
  - Excludes zero-quantity lots and expired/soon-to-expire inventory

Business Rules:
  - Blended cost = (CURRCOST + UNITCOST) / 2 when both available
  - Falls back to available cost if one is NULL
  - Excludes lots with zero net quantity (QTYRECVD - QTYSOLD = 0)
  - Excludes inventory expiring within 90 days
================================================================================
*/

CREATE OR ALTER VIEW dbo.Rolyat_Unit_Price_4
AS
SELECT
    -- Item identifier
    TRIM(inv.ITEMNMBR) AS Item_Number,
    
    -- Unit of measure
    TRIM(itm.UOMSCHDL) AS UOM,
    
    -- ============================================================
    -- Blended Cost Calculation
    -- Priority: Both costs available -> average
    --           One cost NULL -> use the other
    --           Both NULL -> NULL
    -- ============================================================
    CASE
        WHEN AVG(itm.CURRCOST) IS NULL AND AVG(inv.UNITCOST) IS NULL 
            THEN NULL
        WHEN AVG(itm.CURRCOST) IS NULL 
            THEN AVG(inv.UNITCOST)
        WHEN AVG(inv.UNITCOST) IS NULL 
            THEN AVG(itm.CURRCOST)
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
    -- Exclude expired or soon-to-expire inventory (90 day buffer)
    AND (inv.EXPNDATE IS NULL OR inv.EXPNDATE > DATEADD(DAY, 90, GETDATE()))

GROUP BY
    TRIM(inv.ITEMNMBR),
    TRIM(itm.UOMSCHDL)

HAVING
    -- Final filter: ensure net quantity is non-zero after aggregation
    SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0

GO

-- Add extended property for documentation
EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Blended average cost view for WF-Q inventory items. Calculates average of current cost and unit cost with NULL handling.',
    @level0type = N'SCHEMA', @level0name = 'dbo',
    @level1type = N'VIEW', @level1name = 'Rolyat_Unit_Price_4'
GO
