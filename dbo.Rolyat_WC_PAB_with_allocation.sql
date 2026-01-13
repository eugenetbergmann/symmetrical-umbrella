USE [MED]
GO

/****** Object:  View [dbo].[Rolyat_WC_PAB_with_allocation]    Script Date: 1/13/2026 ******/
/*
================================================================================
VIEW: Rolyat_WC_PAB_with_allocation
PURPOSE: Layer 4 - Calculate WC inventory allocation per demand row
DEPENDENCIES: dbo.Rolyat_WC_PAB_with_prioritized_inventory
DOWNSTREAM: Rolyat_WC_PAB_effective_demand

BUSINESS LOGIC:
- For each WC batch (WC_Batch_ID), allocate inventory to demands in priority order
- Priority order: pri_wcid_match, pri_expiry_proximity, pri_temporal_proximity, Date_Expiry, ORDERNUMBER
- Allocation is capped at available WC_Effective_Qty per batch
- batch_prior_claimed_demand: Running sum of demand already claimed by earlier rows
- allocated: Amount of WC inventory allocated to this specific demand row

CHANGES (2026-01-13):
- PERFORMANCE FIX: Extracted repeated window function into CTE to compute only once
- Added comprehensive header documentation
- Simplified allocation logic with clearer variable names
- Added comments explaining the allocation algorithm
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[Rolyat_WC_PAB_with_allocation]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_WC_PAB_with_allocation]
AS
WITH PriorClaimed AS (
    -- Calculate cumulative demand claimed by prior rows within each WC batch
    -- This window function was previously computed 4 times; now computed once
    SELECT 
        pi.*,
        CASE 
            WHEN WC_Batch_ID IS NULL THEN 0.0
            ELSE COALESCE(
                SUM(Base_Demand) OVER (
                    PARTITION BY WC_Batch_ID
                    ORDER BY pri_wcid_match, pri_expiry_proximity, pri_temporal_proximity, Date_Expiry, ORDERNUMBER
                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                ), 0.0)
        END AS batch_prior_claimed_demand
    FROM dbo.Rolyat_WC_PAB_with_prioritized_inventory AS pi
)
SELECT 
    -- Pass through all columns from prioritized inventory
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
    
    -- Calculate allocation for this row
    -- remaining_in_batch = WC_Effective_Qty - batch_prior_claimed_demand
    -- allocated = MIN(Base_Demand, MAX(remaining_in_batch, 0))
    CASE 
        WHEN WC_Batch_ID IS NULL THEN 0.0
        WHEN Base_Demand <= (WC_Effective_Qty - batch_prior_claimed_demand)
            THEN Base_Demand  -- Full demand can be satisfied
        WHEN (WC_Effective_Qty - batch_prior_claimed_demand) > 0
            THEN (WC_Effective_Qty - batch_prior_claimed_demand)  -- Partial allocation
        ELSE 0.0  -- No remaining inventory in batch
    END AS allocated

FROM PriorClaimed;
GO
