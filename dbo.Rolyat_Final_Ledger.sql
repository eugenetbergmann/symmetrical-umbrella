USE [MED]
GO

/****** Object:  View [dbo].[Rolyat_Final_Ledger]    Script Date: 1/13/2026 ******/
/*
================================================================================
VIEW: Rolyat_Final_Ledger
PURPOSE: Layer 6 - Final output view with running balance and status flags
DEPENDENCIES: dbo.Rolyat_WC_PAB_effective_demand
DOWNSTREAM: Dashboard consumption

BUSINESS LOGIC:
- Adjusted_Running_Balance: Per-item cumulative balance
  * Formula: SUM(BEG_BAL + POs - effective_demand) over item timeline
  * BUG FIX: BEG_BAL and POs only counted on FIRST row per item to prevent
    double-counting when LEFT JOIN creates multiple rows per demand
- Row_Type: Categorizes each row (BEGINNING_BALANCE, PURCHASE_ORDER, DEMAND_EVENT, OTHER)
- Demand_Validation_Status: Indicates WC supply coverage
- Allocation_Efficiency_Flag: Indicates allocation completeness
- QC_Flag: Highlights urgent or review-needed items

CHANGES (2026-01-13):
- BUG FIX: Added item_row_num condition to prevent BEG_BAL/POs double-counting
  * Root cause: LEFT JOIN in Layer 3 creates multiple rows per demand
  * Fix: Only include BEG_BAL/POs when item_row_num = 1
- Added comprehensive header documentation
- Reformatted for readability with logical column grouping
- Removed ORDER BY (not allowed in views; add when querying)
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[Rolyat_Final_Ledger]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_Final_Ledger]
AS
SELECT
    -- Core identifiers
    ORDERNUMBER,
    ITEMNMBR,
    CleanItem,
    WCID_From_MO,
    Construct,
    FG,
    FG_Desc,
    ItemDescription,
    UOMSCHDL,
    STSDESCR,
    MRPTYPE,
    VendorItem,
    INCLUDE_MRP,
    SITE,
    PRIME_VNDR,
    
    -- Date fields
    Date_Expiry,
    Expiry_Dates,
    DUEDATE,
    MRP_IssueDate,
    
    -- Original quantity fields
    BEG_BAL,
    POs,
    Deductions,
    CleanDeductions,
    Expiry,
    Remaining,
    Running_Balance AS Original_Running_Balance,
    Issued,
    
    -- Planning parameters
    PURCHASING_LT,
    PLANNING_LT,
    ORDER_POINT_QTY,
    SAFETY_STOCK,
    
    -- Status flags
    Has_Issued,
    IssueDate_Mismatch,
    Early_Issue_Flag,

    -- WC allocation fields
    Base_Demand,
    allocated AS WC_Inventory_Applied,
    effective_demand AS Effective_Demand,
    wc_allocation_status,

    -- CORRECTED: Per-item running balance
    -- BEG_BAL and POs only counted on first row per item (item_row_num = 1)
    -- This prevents double-counting when multiple WC batches match one demand
    SUM(
        CASE WHEN item_row_num = 1 THEN COALESCE(BEG_BAL, 0.0) ELSE 0.0 END
        + CASE WHEN item_row_num = 1 THEN COALESCE(POs, 0.0) ELSE 0.0 END
        - effective_demand
    ) OVER (
        PARTITION BY ITEMNMBR
        ORDER BY Date_Expiry, ORDERNUMBER
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS Adjusted_Running_Balance,

    -- Row type classification
    CASE
        WHEN BEG_BAL > 0 THEN 'BEGINNING_BALANCE'
        WHEN POs > 0 THEN 'PURCHASE_ORDER'
        WHEN Base_Demand > 0 THEN 'DEMAND_EVENT'
        ELSE 'OTHER'
    END AS Row_Type,

    -- Demand validation status
    CASE
        WHEN allocated >= Base_Demand AND Base_Demand > 0 THEN 'FULLY_SUPPLIED'
        WHEN allocated > 0 THEN 'PARTIALLY_SUPPLIED'
        ELSE 'NO_WC_ALLOCATED'
    END AS Demand_Validation_Status,

    -- Allocation efficiency flag
    CASE
        WHEN allocated = 0 AND Base_Demand > 0 THEN 'NO_ALLOCATION'
        WHEN allocated < Base_Demand THEN 'PARTIAL_ALLOCATION'
        ELSE 'FULL_ALLOCATION'
    END AS Allocation_Efficiency_Flag,

    -- QC flag for urgent items
    CASE
        WHEN effective_demand > 0 AND Date_Expiry BETWEEN GETDATE() AND DATEADD(DAY, 3, GETDATE())
            THEN 'URGENT_UNMET_DEMAND'
        WHEN wc_allocation_status = 'No_WC_Allocation' AND Base_Demand > 0
            THEN 'REVIEW_NO_WC_AVAILABLE'
        ELSE 'NORMAL'
    END AS QC_Flag

FROM dbo.Rolyat_WC_PAB_effective_demand;
GO
