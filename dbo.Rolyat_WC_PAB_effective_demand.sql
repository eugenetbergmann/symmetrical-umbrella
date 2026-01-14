USE [MED]
GO

/****** Object:  View [dbo].[Rolyat_WC_PAB_effective_demand]    Script Date: 1/13/2026 ******/
/*
================================================================================
VIEW: Rolyat_WC_PAB_effective_demand
PURPOSE: Layer 5 - Calculate effective demand after WC allocation
DEPENDENCIES: dbo.Rolyat_WC_PAB_inventory_and_allocation
DOWNSTREAM: Rolyat_Final_Ledger

BUSINESS LOGIC:
- For demands within active window (±21 days from today):
  * effective_demand = Base_Demand - allocated (minimum 0)
  * WC allocation reduces the demand that needs to be fulfilled
- For demands outside active window:
  * effective_demand = Base_Demand (no WC allocation applied)
- wc_allocation_status indicates the allocation state:
  * 'WC_Suppressed': Demand reduced by WC allocation
  * 'No_WC_Allocation': In window but no WC available
  * 'Outside_Active_Window': Demand date too far in past/future

CHANGES (2026-01-13):
- Added comprehensive header documentation
- Reformatted for readability
- Added item_row_num for downstream deduplication (used in Final_Ledger)
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[Rolyat_WC_PAB_effective_demand]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_WC_PAB_effective_demand]
AS
SELECT 
    -- Pass through all columns from allocation layer
    ORDERNUMBER,
    CleanOrder,
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
    Date_Expiry,
    Expiry_Dates,
    DUEDATE,
    MRP_IssueDate,
    BEG_BAL,
    POs,
    Deductions,
    CleanDeductions,
    Expiry,
    Remaining,
    Running_Balance,
    Issued,
    PURCHASING_LT,
    PLANNING_LT,
    ORDER_POINT_QTY,
    SAFETY_STOCK,
    Has_Issued,
    IssueDate_Mismatch,
    Early_Issue_Flag,
    Base_Demand,
    WC_Item,
    WC_Site,
    Available_Qty,
    WC_DateReceived,
    WC_Age_Days,
    WC_Degradation_Factor,
    WC_Effective_Qty,
    WC_Batch_ID,
    pri_wcid_match,
    pri_expiry_proximity,
    pri_temporal_proximity,
    batch_prior_claimed_demand,
    allocated,
    
    -- Calculate effective demand based on active window
    CASE 
        WHEN Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE()) 
        THEN CASE 
                WHEN Base_Demand - allocated > 0 THEN Base_Demand - allocated 
                ELSE 0.0 
             END 
        ELSE Base_Demand 
    END AS effective_demand,
    
    -- Allocation status for reporting
    CASE 
        WHEN Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE()) 
        THEN CASE 
                WHEN allocated > 0 THEN 'WC_Suppressed' 
                ELSE 'No_WC_Allocation' 
             END 
        ELSE 'Outside_Active_Window' 
    END AS wc_allocation_status,
    
    -- Row number within each item for deduplication in Final_Ledger
    -- Used to ensure BEG_BAL and POs are only counted once per item
    ROW_NUMBER() OVER (
        PARTITION BY ITEMNMBR 
        ORDER BY Date_Expiry, ORDERNUMBER
    ) AS item_row_num

FROM dbo.Rolyat_WC_PAB_inventory_and_allocation;
GO
