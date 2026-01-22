/*
================================================================================
View: dbo.Rolyat_Unit_Price_4
Description: Unit and extended price calculation for WF inventory items (excluding QCL) with UOM
Version: 1.2.0
Last Modified: 2026-01-22
Dependencies: 
  - dbo.IV00300 (Inventory Lot Master)
  - dbo.IV00101 (Item Master)

Purpose:
  - Calculates unit price (blended average cost) and extended price (unit price * total quantity)
  - Filters to WF location inventory only, excluding QCL
  - Excludes zero-quantity lots and expired inventory
  - Includes UOM for pricing breakdown

Business Rules:
  - Unit price = (CURRCOST + UNITCOST) / 2 when both available
  - Falls back to available cost if one is NULL
  - Extended price = unit price * aggregate net quantity
  - Excludes lots with zero net quantity (QTYRECVD - QTYSOLD = 0)
  - Excludes inventory with expiry date before today
================================================================================
*/

SELECT
    TRIM(inv.ITEMNMBR) AS Item_Number,
    TRIM(itm.UOMSCHDL) AS UOM,
    CASE
        WHEN AVG(itm.CURRCOST) IS NULL AND AVG(inv.UNITCOST) IS NULL THEN NULL
        WHEN AVG(itm.CURRCOST) IS NULL THEN AVG(inv.UNITCOST)
        WHEN AVG(inv.UNITCOST) IS NULL THEN AVG(itm.CURRCOST)
        ELSE (AVG(itm.CURRCOST) + AVG(inv.UNITCOST)) / 2.0
    END AS Unit_Price,
    CASE
        WHEN AVG(itm.CURRCOST) IS NULL AND AVG(inv.UNITCOST) IS NULL THEN NULL
        WHEN AVG(itm.CURRCOST) IS NULL THEN AVG(inv.UNITCOST)
        WHEN AVG(inv.UNITCOST) IS NULL THEN AVG(itm.CURRCOST)
        ELSE (AVG(itm.CURRCOST) + AVG(inv.UNITCOST)) / 2.0
    END * SUM(inv.QTYRECVD - inv.QTYSOLD) AS Extended_Price
FROM dbo.IV00300 AS inv
LEFT OUTER JOIN dbo.IV00101 AS itm
    ON inv.ITEMNMBR = itm.ITEMNMBR
WHERE
    -- Net inventory must be non-zero
    inv.QTYRECVD - inv.QTYSOLD <> 0
    -- CHANGED: Include all WF locations, explicitly exclude QCL
    AND TRIM(inv.LOCNCODE) LIKE 'WF%'
    AND TRIM(inv.LOCNCODE) NOT LIKE 'QCL%'
    -- Include non-expired inventory or inventory with no expiry date
    AND (inv.EXPNDATE IS NULL OR inv.EXPNDATE > GETDATE())
GROUP BY
    TRIM(inv.ITEMNMBR),
    TRIM(itm.UOMSCHDL)
HAVING
    -- Aggregate net quantity must be non-zero
    SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0
