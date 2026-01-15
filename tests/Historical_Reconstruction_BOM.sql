-- Historical Reconstruction BOM View
-- Evaluates BOM accuracy by replaying event histories for any selected timeframe using sequence and event management

USE [MED];
GO

CREATE VIEW dbo.Historical_Reconstruction_BOM AS
WITH EventReplay AS (
    SELECT
        ITEMNMBR,
        Event_Date,
        Event_Type,
        Qty_Change,
        SUM(Qty_Change) OVER (PARTITION BY ITEMNMBR ORDER BY Event_Date, Event_Sequence ROWS UNBOUNDED PRECEDING) AS Reconstructed_Quantity
    FROM dbo.BOM_Events
    WHERE Event_Date <= GETDATE() -- Or parameterize timeframe
)
SELECT
    er.ITEMNMBR,
    er.Event_Date,
    er.Reconstructed_Quantity,
    inv.Active_Quantity,
    CASE
        WHEN ABS(er.Reconstructed_Quantity - inv.Active_Quantity) > 0.01 THEN 'Mismatch' -- Tolerance
        ELSE 'OK'
    END AS Reconstruction_Status
FROM EventReplay er
INNER JOIN dbo.Inventory inv ON er.ITEMNMBR = inv.ITEMNMBR
WHERE ABS(er.Reconstructed_Quantity - inv.Active_Quantity) > 0.01;
GO