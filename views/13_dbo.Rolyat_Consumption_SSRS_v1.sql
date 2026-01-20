/*
================================================================================
View: dbo.Rolyat_Consumption_SSRS_v1
Description: SSRS-optimized consumption view for reporting
Version: 1.0.0
Last Modified: 2026-01-16
Dependencies: 
  - dbo.Rolyat_Final_Ledger_3

Purpose:
  - Provides simplified, report-friendly column names
  - Optimized for SSRS report consumption
  - Exposes key metrics with business-friendly aliases

Usage:
  - Use as data source for SSRS reports
  - Supports standard report filtering and grouping
  - Column names aligned with business terminology
================================================================================
*/

SELECT
    -- ============================================================
    -- Item Identifiers
    -- ============================================================
    fl.ITEMNMBR,
    fl.CleanItem,
    fl.Client_ID,
    
    -- ============================================================
    -- Date Fields
    -- ============================================================
    fl.DUEDATE,
    
    -- ============================================================
    -- Event Type
    -- ============================================================
    fl.Row_Type,
    
    -- ============================================================
    -- Demand Quantities (business-friendly names)
    -- ============================================================
    fl.Base_Demand AS Demand_Qty,
    fl.Effective_Demand AS ATP_Demand_Qty,
    
    -- ============================================================
    -- Supply Events
    -- ============================================================
    fl.Forecast_Supply_Event,
    fl.ATP_Supply_Event,
    
    -- ============================================================
    -- Running Balances (business-friendly names)
    -- ============================================================
    fl.Forecast_Running_Balance AS Forecast_Balance,
    fl.ATP_Running_Balance AS ATP_Balance,
    
    -- ============================================================
    -- Status Fields (business-friendly names)
    -- ============================================================
    fl.wc_allocation_status AS Allocation_Status,
    fl.QC_Flag AS QC_Status,
    fl.IsActiveWindow

FROM dbo.Rolyat_Final_Ledger_3 AS fl
