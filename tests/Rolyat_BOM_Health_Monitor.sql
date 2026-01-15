-- Rolyat BOM Health Monitor
-- Generates real-time BOM health reports with violation counts and color-coded status

USE [MED];
GO

CREATE VIEW dbo.Rolyat_BOM_Health_Monitor AS
SELECT
    'BOM Health Report' AS Report_Type,
    GETDATE() AS Report_Date,
    (SELECT COUNT(*) FROM dbo.BOM_Event_Sequence_Validation) AS Sequence_Violations,
    (SELECT COUNT(*) FROM dbo.BOM_Material_Balance_Test WHERE Status = 'Mismatch') AS Balance_Violations,
    (SELECT COUNT(*) FROM dbo.Historical_Reconstruction_BOM WHERE Reconstruction_Status = 'Mismatch') AS Reconstruction_Violations,
    CASE
        WHEN (SELECT COUNT(*) FROM dbo.BOM_Event_Sequence_Validation) = 0
             AND (SELECT COUNT(*) FROM dbo.BOM_Material_Balance_Test WHERE Status = 'Mismatch') = 0
             AND (SELECT COUNT(*) FROM dbo.Historical_Reconstruction_BOM WHERE Reconstruction_Status = 'Mismatch') = 0
        THEN 'GREEN'
        WHEN (SELECT COUNT(*) FROM dbo.BOM_Event_Sequence_Validation) <= 5
             AND (SELECT COUNT(*) FROM dbo.BOM_Material_Balance_Test WHERE Status = 'Mismatch') <= 5
             AND (SELECT COUNT(*) FROM dbo.Historical_Reconstruction_BOM WHERE Reconstruction_Status = 'Mismatch') <= 5
        THEN 'YELLOW'
        ELSE 'RED'
    END AS Overall_Status
GO