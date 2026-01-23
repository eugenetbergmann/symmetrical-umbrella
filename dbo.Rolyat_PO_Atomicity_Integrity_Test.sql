CREATE OR ALTER VIEW dbo.Rolyat_PO_Atomicity_Integrity_Test
AS
WITH OrderedEvents AS (
    SELECT
        ITEMNMBR,
        DUEDATE,
        TRY_CONVERT(DATE, DUEDATE) AS EventDate,
        COALESCE(TRY_CAST(BEG_BAL AS DECIMAL(18, 5)), 0.0) AS BEG_BAL,
        COALESCE(TRY_CAST([PO's] AS DECIMAL(18, 5)), 0.0) AS POs,
        CASE
            WHEN COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0) > 0
                THEN COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0)
            WHEN COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) > 0
                THEN COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0)
            WHEN COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0) > 0
                THEN COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0)
            ELSE 0.0
        END AS Base_Demand,
        COALESCE(TRY_CAST(Running_Balance AS DECIMAL(18, 5)), 0.0) AS Source_Running_Balance,
        ORDERNUMBER,
        ROW_NUMBER() OVER (
            PARTITION BY ITEMNMBR
            ORDER BY
                TRY_CONVERT(DATE, DUEDATE),
                CASE
                    WHEN COALESCE(TRY_CAST(BEG_BAL AS DECIMAL(18, 5)), 0.0) > 0 THEN 1
                    WHEN COALESCE(TRY_CAST([PO's] AS DECIMAL(18, 5)), 0.0) > 0 THEN 2
                    WHEN COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0) > 0
                         OR COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) > 0 THEN 3
                    WHEN COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0) > 0 THEN 4
                    ELSE 5
                END,
                ORDERNUMBER
        ) AS EventSequence
    FROM dbo.ETB_PAB_AUTO
    WHERE TRY_CONVERT(DATE, DUEDATE) IS NOT NULL
        AND TRIM(ITEMNMBR) NOT LIKE '60.%'
        AND TRIM(ITEMNMBR) NOT LIKE '70.%'
        AND TRIM(COALESCE(STSDESCR, '')) <> 'Partially Received'
),
CalculatedBalance AS (
    SELECT
        ITEMNMBR,
        ORDERNUMBER,
        EventSequence,
        Source_Running_Balance,
        SUM(BEG_BAL + POs - Base_Demand) OVER (
            PARTITION BY ITEMNMBR
            ORDER BY EventSequence
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Calculated_Running_Balance
    FROM OrderedEvents
)
SELECT
    ROW_NUMBER() OVER (ORDER BY ITEMNMBR, ORDERNUMBER) AS Ordinal,
    'dbo.Rolyat_Cleaned_Base_Demand_1' AS ViewName,
    'RUNNING_BALANCE_MISMATCH' AS IssueType,
    'CRITICAL' AS Severity,
    'Running balance mismatch: Source=' + CAST(Source_Running_Balance AS VARCHAR(20)) +
    ', Calculated=' + CAST(Calculated_Running_Balance AS VARCHAR(20)) AS Description,
    'ITEMNMBR: ' + ITEMNMBR + ', ORDERNUMBER: ' + ORDERNUMBER + ', Sequence: ' + CAST(EventSequence AS VARCHAR(10)) AS SupportingEvidence,
    'Review PO event sequencing and balance calculation logic in Cleaned_Base_Demand_1' AS RecommendedAction
FROM CalculatedBalance
WHERE ABS(Source_Running_Balance - Calculated_Running_Balance) > 0.001  -- Allow for rounding differences