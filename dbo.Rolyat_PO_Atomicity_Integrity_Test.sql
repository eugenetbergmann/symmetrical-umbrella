CREATE OR ALTER VIEW dbo.Rolyat_PO_Atomicity_Integrity_Test
AS
SELECT
    1 AS Ordinal,
    'N/A' AS ViewName,
    'JSON_INPUT_ERROR' AS IssueType,
    'CRITICAL' AS Severity,
    'JSON input is malformed or incomplete' AS Description,
    '' AS SupportingEvidence,
    'Review PO event preservation in this view' AS RecommendedAction