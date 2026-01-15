SELECT
    TRIM(inv.ITEMNMBR) AS Item_Number,
    TRIM(inv.LOCNCODE) AS SITE,
    TRIM(itm.UOMSCHDL) AS UOM,
    -- Client segregation placeholder (override with real client mapping if available)
    COALESCE(NULLIF(TRIM(inv.UDFSTR1), ''), 'UNASSIGNED') AS Client_ID,
    SUM(inv.QTYRECVD - inv.QTYSOLD) AS QTY_ON_HAND

FROM dbo.IV00300 AS inv
LEFT JOIN dbo.IV00101 AS itm
    ON inv.ITEMNMBR = itm.ITEMNMBR

WHERE
    -- Exclude zero-quantity lots
    (inv.QTYRECVD - inv.QTYSOLD) <> 0
    -- WF-Q and RMQTY locations
    AND TRIM(inv.LOCNCODE) IN ('WF-Q', 'RMQTY')
    -- Exclude expired or soon-to-expire inventory
    AND (inv.EXPNDATE IS NULL OR inv.EXPNDATE > DATEADD(DAY, 90, GETDATE()))

GROUP BY
    TRIM(inv.ITEMNMBR),
    TRIM(inv.LOCNCODE),
    TRIM(itm.UOMSCHDL),
    COALESCE(NULLIF(TRIM(inv.UDFSTR1), ''), 'UNASSIGNED')

HAVING
    SUM(inv.QTYRECVD - inv.QTYSOLD) <> 0
