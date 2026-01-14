USE [MED]
GO

/****** Object:  View [dbo].[Rolyat_WC_PAB_inventory_and_allocation]    Script Date: 1/14/2026 ******/
/*
================================================================================
VIEW: Rolyat_WC_PAB_inventory_and_allocation
PURPOSE: Merged Layer 3-4 - Join demand with WC inventory, calculate priorities, and allocate inventory
DEPENDENCIES: 
  - dbo.Rolyat_WC_PAB_data_and_demand
  - dbo.ETB_WC_INV (WC inventory table)
DOWNSTREAM: Rolyat_WC_PAB_effective_demand

BUSINESS LOGIC:
- LEFT JOIN to ETB_WC_INV matches eligible WC batches to demand rows
- Eligibility: Same item, WC site pattern, available qty > 0, temporal proximity ±21 days, age <= 90 days
- Degradation factor: 0-30:100%, 31-60:75%, 61-90:50%, >90:0%
- Priority scores for FEFO: site match, expiry proximity, temporal proximity
- Allocation per WC batch in priority order, capped at effective qty

CHANGES (2026-01-14):
- Merged Rolyat_WC_PAB_with_prioritized_inventory and Rolyat_WC_PAB_with_allocation
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[Rolyat_WC_PAB_inventory_and_allocation]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_WC_PAB_inventory_and_allocation]
AS
WITH PriorClaimed AS (
    -- Calculate cumulative demand claimed by prior rows within each WC batch
    SELECT 
        bd.*,
        
        -- WC Inventory columns
        w.Item_Number AS WC_Item,
        w.SITE AS WC_Site,
        w.QTY_Available AS Available_Qty,
        w.DATERECD AS WC_DateReceived,
        
        -- WC Age calculation
        DATEDIFF(DAY, w.DATERECD, GETDATE()) AS WC_Age_Days,
        
        -- Degradation factor based on inventory age
        CASE 
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 30 THEN 1.00
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 60 THEN 0.75
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90 THEN 0.50
            ELSE 0.00 
        END AS WC_Degradation_Factor,
        
        -- Effective quantity after degradation
        w.QTY_Available * CASE 
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 30 THEN 1.00
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 60 THEN 0.75
            WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90 THEN 0.50
            ELSE 0.00 
        END AS WC_Effective_Qty,
        
        -- Unique batch identifier
        ISNULL(w.Item_Number, '') + '|' + 
        ISNULL(w.SITE, '') + '|' + 
        ISNULL(w.LOT_Number, '') + '|' + 
        ISNULL(FORMAT(w.DATERECD, 'yyyy-MM-dd'), '') AS WC_Batch_ID,
        
        -- Priority scores
        CASE WHEN w.SITE = bd.SITE THEN 1 ELSE 999 END AS pri_wcid_match,
        ABS(DATEDIFF(DAY, 
            COALESCE(w.EXPNDATE, '9999-12-31'), 
            COALESCE(bd.Expiry_Dates, '9999-12-31')
        )) AS pri_expiry_proximity,
        ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) AS pri_temporal_proximity
        
    FROM dbo.Rolyat_WC_PAB_data_and_demand AS bd
    LEFT JOIN dbo.ETB_WC_INV AS w 
        ON LTRIM(RTRIM(w.Item_Number)) = bd.CleanItem 
        AND w.SITE LIKE 'WC-W%' 
        AND w.QTY_Available > 0 
        AND ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) <= 21 
        AND DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90
),
BatchAllocation AS (
    SELECT 
        pc.*,
        CASE 
            WHEN WC_Batch_ID IS NULL THEN 0.0
            ELSE COALESCE(
                SUM(Base_Demand) OVER (
                    PARTITION BY WC_Batch_ID
                    ORDER BY pri_wcid_match, pri_expiry_proximity, pri_temporal_proximity, Date_Expiry, ORDERNUMBER
                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                ), 0.0)
        END AS batch_prior_claimed_demand
    FROM PriorClaimed AS pc
)
SELECT 
    -- All columns from data_and_demand
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
    
    -- WC columns
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
    
    -- Allocation
    CASE 
        WHEN WC_Batch_ID IS NULL THEN 0.0
        WHEN Base_Demand <= (WC_Effective_Qty - batch_prior_claimed_demand)
            THEN Base_Demand  -- Full demand
        WHEN (WC_Effective_Qty - batch_prior_claimed_demand) > 0
            THEN (WC_Effective_Qty - batch_prior_claimed_demand)  -- Partial
        ELSE 0.0  -- No remaining
    END AS allocated

FROM BatchAllocation;
GO