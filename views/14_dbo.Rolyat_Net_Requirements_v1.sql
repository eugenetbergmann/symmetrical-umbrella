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
    (SELECT Safety_Stock_Days FROM dbo.ETB2_Config_Engine_v1
     WHERE ITEMNMBR = ri.ITEMNMBR AND Client_ID = ri.Client_ID
     ORDER BY Effective_Priority ASC
     OFFSET 0 ROWS FETCH NEXT 1 ROW ONLY) AS Safety_Stock_Days_Config
FROM (
    SELECT
        ITEMNMBR,
        Client_ID,
        SUM(Total_Timed_Hope_Supply) AS Total_Available_Qty,
        MAX(DUEDATE) AS AsOfDate
    FROM dbo.Rolyat_Rebalancing_Layer
    GROUP BY ITEMNMBR, Client_ID
) AS ri
LEFT JOIN (
    SELECT
        ITEMNMBR,
        Client_ID,
        SUM(Base_Demand) AS Total_Forecast_Demand,
        MAX(DUEDATE) AS Latest_Demand_Date
    FROM dbo.Rolyat_StockOut_Analysis_v2
    WHERE DUEDATE >= GETDATE()
    GROUP BY ITEMNMBR, Client_ID
) AS df ON ri.ITEMNMBR = df.ITEMNMBR AND ri.Client_ID = df.Client_ID