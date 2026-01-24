/*
===============================================================================
View: dbo.ETB2_Consumption_Detail_v1
Description: Unified consumption view consolidating detail and SSRS reporting
Version: 1.0.0
Last Modified: 2026-01-24
Dependencies:
   - dbo.Rolyat_Final_Ledger_3 (final ledger data)

Purpose:
   - Consolidates detailed consumption analysis and SSRS reporting views
   - Provides both technical and business-friendly column names
   - Supports drill-down analysis and SSRS report consumption
   - Eliminates 90% duplication between Detail and SSRS views

Business Rules:
   - Exposes all key metrics from final ledger
   - Includes both technical names and business aliases
   - Supports filtering by Client_ID, ITEMNMBR, date ranges
   - Provides full visibility into supply/demand events

REPLACES:
   - dbo.Rolyat_Consumption_Detail_v1 (View 12)
   - dbo.Rolyat_Consumption_SSRS_v1 (View 13)

USAGE:
   - For detailed analysis: Use technical column names
   - For SSRS reports: Use business-friendly aliases
   - Single view serves both purposes with dual naming
===============================================================================
*/

CREATE OR ALTER VIEW dbo.ETB2_Consumption_Detail_v1
AS

SELECT
  -- ============================================================
  -- Item Identifiers (technical and business names)
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
  
  -- ============================================================
  -- Demand Quantities (technical names)
  -- ============================================================
  fl.Base_Demand,
  fl.suppressed_demand AS Effective_Demand,
  
  -- ============================================================
  -- Demand Quantities (business-friendly aliases)
  -- ============================================================
  fl.Base_Demand AS Demand_Qty,
  fl.suppressed_demand AS ATP_Demand_Qty,
  
  -- ============================================================
  -- Supply Quantities (technical names)
  -- ============================================================
  fl.BEG_BAL,
  fl.Total_PO_Supply AS POs,
  fl.Released_PO_Supply AS Released_PO_Qty,
  fl.Total_WFQ AS WFQ_QTY,
  fl.Eligible_RMQTY AS RMQTY_QTY,
  
  -- ============================================================
  -- Running Balances (technical names)
  -- ============================================================
  fl.Original_Running_Balance,
  fl.effective_demand,
  
  -- ============================================================
  -- Running Balances (business-friendly aliases)
  -- ============================================================
  fl.Original_Running_Balance AS Forecast_Balance,
  fl.effective_demand AS ATP_Balance,
  
  -- ============================================================
  -- Allocation and Status (technical names)
  -- ============================================================
  fl.Allocation_Status AS wc_allocation_status,
  fl.Stock_Out_Flag AS QC_Flag,
  fl.IsActiveWindow,
  
  -- ============================================================
  -- Allocation and Status (business-friendly aliases)
  -- ============================================================
  fl.Allocation_Status,
  fl.Stock_Out_Flag AS QC_Status,
  fl.IsActiveWindow AS Is_Active_Window

FROM dbo.Rolyat_Final_Ledger_3 AS fl;
