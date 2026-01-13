USE [MED]
GO

/****** Object:  View [dbo].[Rolyat_Base_Demand]    Script Date: 1/13/2026 ******/
/*
================================================================================
VIEW: Rolyat_Base_Demand
PURPOSE: Layer 2 - Calculate Base_Demand from cleaned PAB data
DEPENDENCIES: dbo.rolyat_WC_PAB_data_cleaned
DOWNSTREAM: Rolyat_WC_PAB_with_prioritized_inventory

BUSINESS LOGIC:
- Base_Demand is calculated using priority: Remaining > Deductions > Expiry
- Only the first non-zero value is used (not summed)
- If all are zero or negative, Base_Demand = 0

CHANGES (2026-01-13):
- Added header documentation
- Simplified column list formatting for readability
- Added comment explaining Base_Demand priority logic
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[Rolyat_Base_Demand]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_Base_Demand]
AS
SELECT 
    -- Pass through all columns from cleaned data
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
    
    -- Calculate Base_Demand using priority logic:
    -- 1. If Remaining > 0, use Remaining
    -- 2. Else if Deductions > 0, use Deductions  
    -- 3. Else if Expiry > 0, use Expiry
    -- 4. Otherwise, 0.0
    CASE 
        WHEN Remaining > 0 THEN Remaining 
        WHEN Deductions > 0 THEN Deductions 
        WHEN Expiry > 0 THEN Expiry 
        ELSE 0.0 
    END AS Base_Demand

FROM dbo.rolyat_WC_PAB_data_cleaned;
GO
