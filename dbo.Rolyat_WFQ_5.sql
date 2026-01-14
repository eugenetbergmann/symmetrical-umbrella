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
    SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0
