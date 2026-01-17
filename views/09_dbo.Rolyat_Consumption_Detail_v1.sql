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

CREATE VIEW dbo.Rolyat_Consumption_Detail_v1
AS
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
    fl.Effective_Demand,
    
    -- ============================================================
    -- Supply Quantities
    -- ============================================================
    fl.BEG_BAL,
    fl.POs,
    fl.Released_PO_Qty,
    fl.WFQ_QTY,
    fl.RMQTY_QTY,
    fl.RMQTY_Eligible_Qty,
    
    -- ============================================================
    -- Supply Events (for running balance calculation)
    -- ============================================================
    fl.Forecast_Supply_Event,
    fl.ATP_Supply_Event,
    
    -- ============================================================
    -- Running Balances
    -- ============================================================
    fl.Forecast_Running_Balance,
    fl.ATP_Running_Balance,
    
    -- ============================================================
    -- Allocation and Status
    -- ============================================================
    fl.ATP_Suppression_Qty,
    fl.wc_allocation_status,
    fl.QC_Flag,
    fl.IsActiveWindow

FROM dbo.Rolyat_Final_Ledger_3 AS fl

GO

-- Add extended property for documentation
EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Detailed consumption view exposing all key metrics from the final ledger for analysis and troubleshooting.',
    @level0type = N'SCHEMA', @level0name = 'dbo',
    @level1type = N'VIEW', @level1name = 'Rolyat_Consumption_Detail_v1'
GO
