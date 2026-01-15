-- BOM Material Balance Test View
-- Validates component consumption for production events against the BOM, flagging over-/under-consumption

USE [MED];
GO

CREATE VIEW dbo.BOM_Material_Balance_Test AS
SELECT
    pe.ITEMNMBR AS Parent_Item,
    pe.Production_Date,
    pe.Qty_Produced,
    bom.Component_Item,
    bom.Qty_Per,
    pe.Qty_Produced * bom.Qty_Per AS Expected_Consumption,
    ISNULL(cc.Qty_Consumed, 0) AS Component_Usage,
    CASE
        WHEN ABS(ISNULL(cc.Qty_Consumed, 0) - (pe.Qty_Produced * bom.Qty_Per)) > 0.01 THEN 'Mismatch' -- Tolerance 0.01
        ELSE 'OK'
    END AS Status
FROM dbo.Production_Events pe
INNER JOIN dbo.BOM bom ON pe.ITEMNMBR = bom.Parent_Item
LEFT JOIN dbo.Component_Consumption cc ON bom.Component_Item = cc.Component_Item
    AND pe.Production_Date = cc.Consumption_Date
WHERE ABS(ISNULL(cc.Qty_Consumed, 0) - (pe.Qty_Produced * bom.Qty_Per)) > 0.01;
GO