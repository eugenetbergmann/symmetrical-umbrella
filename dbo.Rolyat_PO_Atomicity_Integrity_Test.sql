CREATE OR ALTER VIEW dbo.Rolyat_PO_Atomicity_Integrity_Test
AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ITEMNMBR, ORDERNUMBER) AS Ordinal,
    'dbo.Rolyat_PO_Detail' AS ViewName,
    CASE
        WHEN TRY_CAST([PO's] AS DECIMAL(18, 5)) IS NULL THEN 'INVALID_PO_QUANTITY'
        WHEN TRY_CONVERT(DATE, [Date + Expiry]) IS NULL THEN 'INVALID_PO_DATE'
        ELSE 'ATOMICITY_VIOLATION'
    END AS IssueType,
    'CRITICAL' AS Severity,
    CASE
        WHEN TRY_CAST([PO's] AS DECIMAL(18, 5)) IS NULL THEN 'PO quantity cannot be converted to numeric: ' + QUOTENAME([PO's])
        WHEN TRY_CONVERT(DATE, [Date + Expiry]) IS NULL THEN 'PO date cannot be converted to valid date: ' + QUOTENAME([Date + Expiry])
        ELSE 'PO event missing required atomic components'
    END AS Description,
    'ORDERNUMBER: ' + ORDERNUMBER + ', ITEMNMBR: ' + ITEMNMBR AS SupportingEvidence,
    'Cleanse invalid PO data or review data source integrity' AS RecommendedAction
FROM dbo.ETB_PAB_AUTO
WHERE
    TRY_CAST([PO's] AS DECIMAL(18, 5)) IS NULL
    OR TRY_CONVERT(DATE, [Date + Expiry]) IS NULL
    OR TRIM(COALESCE(STSDESCR, '')) = 'Partially Received'  -- Example atomicity check