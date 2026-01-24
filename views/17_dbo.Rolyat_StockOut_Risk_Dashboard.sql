/*
================================================================================
View: dbo.Rolyat_StockOut_Risk_Dashboard
Description: Single-screen stock-out risk status dashboard (8 columns max)
Version: 1.0.0
Last Modified: 2026-01-24
Dependencies: 
  - dbo.Rolyat_StockOut_Analysis_v2
  - dbo.Rolyat_Final_Ledger_3

Purpose:
  - Provides executive-level stock-out risk visibility
  - Tells the story: "Here's what items are at risk right now and what to do"
  - Optimized for single-screen viewing with 8 columns max
  - No CTEs - direct query for performance

Business Rules:
  - Risk levels based on ATP balance thresholds
  - Recommended actions prioritize urgency
  - Focuses on items with active risk (not HEALTHY status)
  - Includes demand projection for planning context
================================================================================
*/

SELECT
    -- ============================================================
    -- Item Identification (2 columns)
    -- ============================================================
    soa.CleanItem AS Item_Number,
    soa.Client_ID,
    
    -- ============================================================
    -- Current Stock Status (2 columns)
    -- ============================================================
    soa.effective_demand AS Current_ATP_Balance,
    CASE 
        WHEN soa.effective_demand <= 0 THEN 'CRITICAL_STOCKOUT'
        WHEN soa.effective_demand < 50 THEN 'HIGH_RISK'
        WHEN soa.effective_demand < 100 THEN 'MEDIUM_RISK'
        ELSE 'HEALTHY'
    END AS Stock_Out_Risk_Level,
    
    -- ============================================================
    -- Action Guidance (2 columns)
    -- ============================================================
    CASE 
        WHEN soa.effective_demand <= 0 THEN 'URGENT_PURCHASE'
        WHEN soa.effective_demand <= 7 THEN 'EXPEDITE_OPEN_POS'
        WHEN soa.effective_demand <= 14 THEN 'TRANSFER_FROM_OTHER_SITES'
        ELSE 'MONITOR'
    END AS Recommended_Action,
    
    -- ============================================================
    -- Alternate Stock Availability (1 column)
    -- ============================================================
    soa.Alternate_Stock AS Available_Alternate_Stock_Qty,
    
    -- ============================================================
    -- Demand Context (1 column)
    -- ============================================================
    soa.Original_Running_Balance AS Forecast_Balance_Before_Allocation

FROM dbo.Rolyat_StockOut_Analysis_v2 soa

WHERE
    -- Focus on items with active risk (exclude HEALTHY items for brevity)
    CASE 
        WHEN soa.effective_demand <= 0 THEN 'CRITICAL_STOCKOUT'
        WHEN soa.effective_demand < 50 THEN 'HIGH_RISK'
        WHEN soa.effective_demand < 100 THEN 'MEDIUM_RISK'
        ELSE 'HEALTHY'
    END <> 'HEALTHY'

ORDER BY
    -- Prioritize by urgency: CRITICAL first, then HIGH_RISK, then MEDIUM_RISK
    CASE 
        WHEN soa.effective_demand <= 0 THEN 1
        WHEN soa.effective_demand < 50 THEN 2
        WHEN soa.effective_demand < 100 THEN 3
        ELSE 4
    END ASC,
    -- Within same risk level, sort by ATP balance (most critical first)
    soa.effective_demand ASC,
    -- Then by item for consistency
    soa.CleanItem ASC;
