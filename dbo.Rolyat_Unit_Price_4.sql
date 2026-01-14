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
    SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0
