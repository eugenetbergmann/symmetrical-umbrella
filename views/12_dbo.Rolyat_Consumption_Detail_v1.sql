/*
================================================================================
View: dbo.Rolyat_Consumption_Detail_v1
Description: Detailed consumption view for analysis and reporting
Version: 1.0.0
Last Modified: 2026-01-16
Dependencies: 
  - dbo.Rolyat_Final_Ledger_3

Purpose:
  - Provides detailed consumption data for analysis
  - Exposes all key metrics from the final ledger
  - Supports drill-down analysis and troubleshooting

Usage:
  - Use for detailed item-level analysis
  - Supports filtering by Client_ID, ITEMNMBR, date ranges
  - Provides full visibility into supply/demand events
================================================================================
*/

SELECT
    -- ============================================================
    -- Item and Order Identifiers
    -- ============================================================
    fl.ITEMNMBR,
    fl.CleanItem,
    fl.Client_ID,
    fl.ORDERNUMBER,

    -- ============================================================
    -- Date Fields
    -- ============================================================
    fl.DUEDATE,
    fl.Date_Expiry,

    -- ============================================================
    -- Event Ordering
    -- ============================================================
    fl.SortPriority,
    fl.Row_Type,

    -- ============================================================
    -- Demand Quantities
    -- ============================================================
    fl.Base_Demand,
    fl.suppressed_demand AS Effective_Demand,

    -- ============================================================
    -- Supply Quantities
    -- ============================================================
    fl.BEG_BAL,
    fl.Total_PO_Supply AS POs,
    fl.Released_PO_Supply AS Released_PO_Qty,
    fl.Total_WFQ AS WFQ_QTY,
    fl.Eligible_RMQTY AS RMQTY_QTY,

    -- ============================================================
    -- Supply Events (for running balance calculation)
    -- ============================================================
    -- Removed invalid columns: Forecast_Supply_Event, ATP_Supply_Event

    -- ============================================================
    -- Running Balances
    -- ============================================================
    fl.Original_Running_Balance,
    fl.effective_demand,

    -- ============================================================
    -- Allocation and Status
    -- ============================================================
    -- Removed invalid column: ATP_Suppression_Qty
    fl.Allocation_Status AS wc_allocation_status,
    fl.Stock_Out_Flag AS QC_Flag,
    fl.IsActiveWindow

FROM dbo.Rolyat_Final_Ledger_3 AS fl
