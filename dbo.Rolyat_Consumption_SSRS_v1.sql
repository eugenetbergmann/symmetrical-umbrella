SELECT
    fl.ITEMNMBR,
    fl.CleanItem,
    fl.Client_ID,
    fl.DUEDATE,
    fl.Row_Type,
    fl.Base_Demand AS Demand_Qty,
    fl.Effective_Demand AS ATP_Demand_Qty,
    fl.Forecast_Supply_Event,
    fl.ATP_Supply_Event,
    fl.Forecast_Running_Balance AS Forecast_Balance,
    fl.ATP_Running_Balance AS ATP_Balance,
    fl.wc_allocation_status AS Allocation_Status,
    fl.QC_Flag AS QC_Status,
    fl.IsActiveWindow
FROM dbo.Rolyat_Final_Ledger_3 AS fl;
