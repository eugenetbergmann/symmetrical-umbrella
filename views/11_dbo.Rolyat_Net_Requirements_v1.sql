/*
===============================================================================
View: dbo.Rolyat_Net_Requirements_v1
Description: Net Requirements calculation for MRP extension
Version: 1.0.0
Last Modified: 2026-01-16

Purpose:
  - Calculate net requirements after rebalancing
  - Support Material Requirements Planning (MRP) integration
  - Identify procurement needs beyond current inventory

Dependencies:
  - dbo.Rolyat_Rebalancing_Layer
  - dbo.fn_GetConfig (for planning parameters)

Notes:
  - Optional extension for MRP systems
  - Calculates gross requirements minus available inventory
===============================================================================
*/

CREATE OR ALTER VIEW dbo.Rolyat_Net_Requirements_v1 AS

WITH Rebalanced_Inventory AS (
    SELECT
        ITEMNMBR,
        Client_ID,
        SUM(Rebalanced_Qty) AS Total_Available_Qty,
        MAX(AsOfDate) AS AsOfDate
    FROM dbo.Rolyat_Rebalancing_Layer
    GROUP BY ITEMNMBR, Client_ID
),

Demand_Forecast AS (
    SELECT
        ITEMNMBR,
        Client_ID,
        SUM(Forecast_Balance) AS Total_Forecast_Demand,
        MAX(DUEDATE) AS Latest_Demand_Date
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE DUEDATE >= GETDATE()
    GROUP BY ITEMNMBR, Client_ID
)

SELECT
    ri.ITEMNMBR,
    ri.Client_ID,
    ri.Total_Available_Qty,
    ISNULL(df.Total_Forecast_Demand, 0) AS Forecast_Demand,
    CASE
        WHEN ri.Total_Available_Qty >= ISNULL(df.Total_Forecast_Demand, 0) THEN 0
        ELSE ISNULL(df.Total_Forecast_Demand, 0) - ri.Total_Available_Qty
    END AS Net_Requirements_Qty,
    CASE
        WHEN ri.Total_Available_Qty >= ISNULL(df.Total_Forecast_Demand, 0) THEN 'SURPLUS'
        WHEN ri.Total_Available_Qty > 0 THEN 'PARTIAL_COVERAGE'
        ELSE 'FULL_SHORTAGE'
    END AS Requirements_Status,
    ri.AsOfDate,
    df.Latest_Demand_Date,
    COALESCE(
        (SELECT Config_Value FROM dbo.Rolyat_Config_Items WHERE ITEMNMBR = ri.ITEMNMBR AND Config_Key = 'Safety_Stock_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
        (SELECT Config_Value FROM dbo.Rolyat_Config_Clients WHERE Client_ID = ri.Client_ID AND Config_Key = 'Safety_Stock_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())),
        (SELECT Config_Value FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'Safety_Stock_Days' AND Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE()))
    ) AS Safety_Stock_Days_Config
FROM Rebalanced_Inventory ri
LEFT JOIN Demand_Forecast df ON ri.ITEMNMBR = df.ITEMNMBR AND ri.Client_ID = df.Client_ID;