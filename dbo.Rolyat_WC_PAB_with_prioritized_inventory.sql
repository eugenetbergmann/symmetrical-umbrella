USE [MED]
GO

/****** Object:  View [dbo].[Rolyat_WC_PAB_with_prioritized_inventory]    Script Date: 1/13/2026 ******/
/*
================================================================================
VIEW: Rolyat_WC_PAB_with_prioritized_inventory
PURPOSE: Layer 3 - Join demand with WC inventory and calculate priority scores
DEPENDENCIES: 
  - dbo.Rolyat_Base_Demand
  - dbo.ETB_WC_INV (WC inventory table)
DOWNSTREAM: Rolyat_WC_PAB_with_allocation

BUSINESS LOGIC:
- LEFT JOIN to ETB_WC_INV matches eligible WC batches to demand rows
- Eligibility criteria:
  * Same item (CleanItem = Item_Number)
  * WC site pattern 'WC-W%'
  * Available quantity > 0
  * Temporal proximity within ±21 days
  * Inventory age <= 90 days
- Degradation factor reduces effective quantity based on age:
  * 0-30 days: 100%
  * 31-60 days: 75%
  * 61-90 days: 50%
  * >90 days: 0% (excluded by JOIN)
- Priority scores for FEFO allocation:
  * pri_wcid_match: Site match priority (1=match, 999=no match)
  * pri_expiry_proximity: Days between WC expiry and demand expiry
  * pri_temporal_proximity: Days between WC receipt and demand date

WARNING: This LEFT JOIN can create multiple rows per demand if multiple 
WC batches match. Downstream views must handle this appropriately.

CHANGES (2026-01-13):
- Added comprehensive header documentation
- Reformatted for readability with logical column grouping
- Added explicit column aliases
- Clarified degradation factor logic in comments
================================================================================
*/

DROP VIEW IF EXISTS [dbo].[Rolyat_WC_PAB_with_prioritized_inventory]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_WC_PAB_with_prioritized_inventory]
AS
SELECT 
    -- Pass through all demand columns
    bd.ORDERNUMBER,
    bd.CleanOrder,
    bd.ITEMNMBR,
    bd.CleanItem,
    bd.WCID_From_MO,
    bd.Construct,
    bd.FG,
    bd.FG_Desc,
    bd.ItemDescription,
    bd.UOMSCHDL,
    bd.STSDESCR,
    bd.MRPTYPE,
    bd.VendorItem,
    bd.INCLUDE_MRP,
    bd.SITE,
    bd.PRIME_VNDR,
    bd.Date_Expiry,
    bd.Expiry_Dates,
    bd.DUEDATE,
    bd.MRP_IssueDate,
    bd.BEG_BAL,
    bd.POs,
    bd.Deductions,
    bd.CleanDeductions,
    bd.Expiry,
    bd.Remaining,
    bd.Running_Balance,
    bd.Issued,
    bd.PURCHASING_LT,
    bd.PLANNING_LT,
    bd.ORDER_POINT_QTY,
    bd.SAFETY_STOCK,
    bd.Has_Issued,
    bd.IssueDate_Mismatch,
    bd.Early_Issue_Flag,
    bd.Base_Demand,
    
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
    
    -- Unique batch identifier for allocation partitioning
    ISNULL(w.Item_Number, '') + '|' + 
    ISNULL(w.SITE, '') + '|' + 
    ISNULL(w.LOT_Number, '') + '|' + 
    ISNULL(FORMAT(w.DATERECD, 'yyyy-MM-dd'), '') AS WC_Batch_ID,
    
    -- Priority scores for FEFO allocation (lower = higher priority)
    CASE WHEN w.SITE = bd.SITE THEN 1 ELSE 999 END AS pri_wcid_match,
    ABS(DATEDIFF(DAY, 
        COALESCE(w.EXPNDATE, '9999-12-31'), 
        COALESCE(bd.Expiry_Dates, '9999-12-31')
    )) AS pri_expiry_proximity,
    ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) AS pri_temporal_proximity

FROM dbo.Rolyat_Base_Demand AS bd
LEFT JOIN dbo.ETB_WC_INV AS w 
    ON LTRIM(RTRIM(w.Item_Number)) = bd.CleanItem 
    AND w.SITE LIKE 'WC-W%' 
    AND w.QTY_Available > 0 
    AND ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) <= 21 
    AND DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90;
GO
