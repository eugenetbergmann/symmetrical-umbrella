-- BOM Event Sequence Validation View
-- Enforces monotonic increments in event sequences, addressing gaps, duplicates, and consistency

USE [MED];
GO

CREATE VIEW dbo.BOM_Event_Sequence_Validation AS
WITH SequenceCheck AS (
    SELECT
        ITEMNMBR,
        Event_Sequence,
        ROW_NUMBER() OVER (PARTITION BY ITEMNMBR ORDER BY Event_Sequence) AS Expected_Sequence,
        LAG(Event_Sequence) OVER (PARTITION BY ITEMNMBR ORDER BY Event_Sequence) AS Prev_Sequence
    FROM dbo.BOM_Events
)
SELECT
    ITEMNMBR,
    Event_Sequence,
    CASE
        WHEN COUNT(*) OVER (PARTITION BY ITEMNMBR, Event_Sequence) > 1 THEN 'Duplicate'
        WHEN Event_Sequence <> Expected_Sequence THEN 'Gap'
        WHEN Event_Sequence <= Prev_Sequence THEN 'Non-Monotonic'
        ELSE NULL
    END AS Violation_Type
FROM SequenceCheck
WHERE
    COUNT(*) OVER (PARTITION BY ITEMNMBR, Event_Sequence) > 1
    OR Event_Sequence <> Expected_Sequence
    OR Event_Sequence <= Prev_Sequence;
GO