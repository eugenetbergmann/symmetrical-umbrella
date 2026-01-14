USE [MED]
GO

/****** Object:  View [dbo].[Rolyat_WC_PAB_data_and_demand]    Script Date: 1/14/2026 ******/
/*
================================================================================
VIEW: Rolyat_WC_PAB_data_and_demand
PURPOSE: Merged Layer 1-2 - Data cleansing, standardization, and base demand calculation
DEPENDENCIES: dbo.ETB_PAB_AUTO (base table)
DOWNSTREAM: Rolyat_WC_PAB_inventory_and_allocation

BUSINESS LOGIC:
- Data cleansing and standardization from ETB_PAB_AUTO
- Base_Demand calculated using priority: Remaining > Deductions > Expiry
- Only the first non-zero value is used (not summed)
- If all are zero or negative, Base_Demand = 0

CHANGES (2026-01-14):
- Merged rolyat_WC_PAB_data_cleaned and Rolyat_Base_Demand into single view
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[Rolyat_WC_PAB_data_and_demand]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_WC_PAB_data_and_demand]
AS
SELECT 
    -- Order identifiers (cleaned and standardized)
    UPPER(TRIM(ORDERNUMBER)) AS ORDERNUMBER,
    UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
        TRIM(REPLACE(ORDERNUMBER, 'MO', '')), 
        '-', ''), ' ', ''), '/', ''), '.', ''), '#', '')) AS CleanOrder,
    
    -- Item identifiers
    TRIM(ITEMNMBR) AS ITEMNMBR,
    TRIM(ITEMNMBR) AS CleanItem,  -- Kept for backward compatibility
    
    -- Work center and product hierarchy
    TRIM(COALESCE(WCID_From_MO, '')) AS WCID_From_MO,
    TRIM(COALESCE(Construct, '')) AS Construct,
    TRIM(COALESCE(FG, '')) AS FG,
    TRIM(COALESCE([FG Desc], '')) AS FG_Desc,
    TRIM(COALESCE(ItemDescription, '')) AS ItemDescription,
    
    -- Item attributes
    TRIM(COALESCE(UOMSCHDL, '')) AS UOMSCHDL,
    TRIM(COALESCE(STSDESCR, '')) AS STSDESCR,
    TRIM(COALESCE(MRPTYPE, '')) AS MRPTYPE,
    TRIM(COALESCE(VendorItem, '')) AS VendorItem,
    TRIM(COALESCE(INCLUDE_MRP, '')) AS INCLUDE_MRP,
    TRIM(COALESCE(SITE, '')) AS SITE,
    TRIM(COALESCE(PRIME_VNDR, '')) AS PRIME_VNDR,
    
    -- Date fields (converted to DATE type)
    TRY_CONVERT(DATE, [Date + Expiry]) AS Date_Expiry,
    TRY_CONVERT(DATE, [Expiry Dates]) AS Expiry_Dates,
    TRY_CONVERT(DATE, DUEDATE) AS DUEDATE,
    TRY_CONVERT(DATE, MRP_IssueDate) AS MRP_IssueDate,
    
    -- Quantity fields (converted to DECIMAL with NULL protection)
    COALESCE(TRY_CAST(BEG_BAL AS DECIMAL(18, 5)), 0.0) AS BEG_BAL,
    COALESCE(TRY_CAST([PO's] AS DECIMAL(18, 5)), 0.0) AS POs,
    COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) AS Deductions,
    COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) AS CleanDeductions,
    COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0) AS Expiry,
    COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0) AS Remaining,
    COALESCE(TRY_CAST(Running_Balance AS DECIMAL(18, 5)), 0.0) AS Running_Balance,
    COALESCE(TRY_CAST(Issued AS DECIMAL(18, 5)), 0.0) AS Issued,
    
    -- Planning parameters
    COALESCE(TRY_CAST(PURCHASING_LT AS DECIMAL(18, 5)), 0.0) AS PURCHASING_LT,
    COALESCE(TRY_CAST(PLANNING_LT AS DECIMAL(18, 5)), 0.0) AS PLANNING_LT,
    COALESCE(TRY_CAST(ORDER_POINT_QTY AS DECIMAL(18, 5)), 0.0) AS ORDER_POINT_QTY,
    COALESCE(TRY_CAST(SAFETY_STOCK AS DECIMAL(18, 5)), 0.0) AS SAFETY_STOCK,
    
    -- Status flags (standardized to uppercase YES/NO)
    UPPER(TRIM(COALESCE(Has_Issued, 'NO'))) AS Has_Issued,
    UPPER(TRIM(COALESCE(IssueDate_Mismatch, 'NO'))) AS IssueDate_Mismatch,
    UPPER(TRIM(COALESCE(Early_Issue_Flag, 'NO'))) AS Early_Issue_Flag,
    
    -- Calculate Base_Demand using priority logic:
    -- 1. If Remaining > 0, use Remaining
    -- 2. Else if Deductions > 0, use Deductions  
    -- 3. Else if Expiry > 0, use Expiry
    -- 4. Otherwise, 0.0
    CASE 
        WHEN COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0) > 0 THEN COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0)
        WHEN COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) > 0 THEN COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0)
        WHEN COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0) > 0 THEN COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0)
        ELSE 0.0 
    END AS Base_Demand

FROM dbo.ETB_PAB_AUTO
WHERE 
    -- Exclude rows with invalid dates
    TRY_CONVERT(DATE, [Date + Expiry]) IS NOT NULL
    -- Exclude specific item prefixes (60.x and 70.x series)
    AND TRIM(ITEMNMBR) NOT LIKE '60.%'
    AND TRIM(ITEMNMBR) NOT LIKE '70.%'
    -- Exclude partially received orders
    AND TRIM(COALESCE(STSDESCR, '')) <> 'Partially Received';
GO