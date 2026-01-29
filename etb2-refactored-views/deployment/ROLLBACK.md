# ETB2 Refactored Views - Rollback Guide

## Overview
This guide provides instructions for rolling back the ETB2 refactored views if issues are encountered.

## Quick Rollback (All Views)

Run this script to drop all ETB2 views in reverse dependency order:

```sql
-- Rollback Script for ETB2 Refactored Views
-- Execute in REVERSE deployment order

PRINT 'Starting ETB2 Views Rollback...';

-- Drop views in reverse dependency order
IF OBJECT_ID('dbo.ETB2_PAB_EventLedger_v1', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_PAB_EventLedger_v1;
PRINT 'Dropped: ETB2_PAB_EventLedger_v1';

IF OBJECT_ID('dbo.ETB2_Campaign_Model_Data_Gaps', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Campaign_Model_Data_Gaps;
PRINT 'Dropped: ETB2_Campaign_Model_Data_Gaps';

IF OBJECT_ID('dbo.ETB2_Campaign_Absorption_Capacity', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Campaign_Absorption_Capacity;
PRINT 'Dropped: ETB2_Campaign_Absorption_Capacity';

IF OBJECT_ID('dbo.ETB2_Campaign_Risk_Adequacy', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Campaign_Risk_Adequacy;
PRINT 'Dropped: ETB2_Campaign_Risk_Adequacy';

IF OBJECT_ID('dbo.ETB2_Campaign_Collision_Buffer', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Campaign_Collision_Buffer;
PRINT 'Dropped: ETB2_Campaign_Collision_Buffer';

IF OBJECT_ID('dbo.ETB2_Campaign_Concurrency_Window', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Campaign_Concurrency_Window;
PRINT 'Dropped: ETB2_Campaign_Concurrency_Window';

IF OBJECT_ID('dbo.ETB2_Campaign_Normalized_Demand', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Campaign_Normalized_Demand;
PRINT 'Dropped: ETB2_Campaign_Normalized_Demand';

IF OBJECT_ID('dbo.ETB2_Planning_Rebalancing_Opportunities', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Planning_Rebalancing_Opportunities;
PRINT 'Dropped: ETB2_Planning_Rebalancing_Opportunities';

IF OBJECT_ID('dbo.ETB2_Planning_Stockout', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Planning_Stockout;
PRINT 'Dropped: ETB2_Planning_Stockout';

IF OBJECT_ID('dbo.ETB2_Planning_Net_Requirements', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Planning_Net_Requirements;
PRINT 'Dropped: ETB2_Planning_Net_Requirements';

IF OBJECT_ID('dbo.ETB2_Inventory_Unified', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Inventory_Unified;
PRINT 'Dropped: ETB2_Inventory_Unified';

IF OBJECT_ID('dbo.ETB2_Inventory_Quarantine_Restricted', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Inventory_Quarantine_Restricted;
PRINT 'Dropped: ETB2_Inventory_Quarantine_Restricted';

IF OBJECT_ID('dbo.ETB2_Inventory_WC_Batches', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Inventory_WC_Batches;
PRINT 'Dropped: ETB2_Inventory_WC_Batches';

IF OBJECT_ID('dbo.ETB2_Demand_Cleaned_Base', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Demand_Cleaned_Base;
PRINT 'Dropped: ETB2_Demand_Cleaned_Base';

IF OBJECT_ID('dbo.ETB2_Config_Active', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Config_Active;
PRINT 'Dropped: ETB2_Config_Active';

IF OBJECT_ID('dbo.ETB2_Config_Items', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Config_Items;
PRINT 'Dropped: ETB2_Config_Items';

IF OBJECT_ID('dbo.ETB2_Config_Part_Pooling', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Config_Part_Pooling;
PRINT 'Dropped: ETB2_Config_Part_Pooling';

IF OBJECT_ID('dbo.ETB2_Config_Lead_Times', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Config_Lead_Times;
PRINT 'Dropped: ETB2_Config_Lead_Times';

PRINT 'ETB2 Views Rollback Complete.';
```

## Selective Rollback (Individual Views)

To rollback specific views only:

```sql
-- Example: Rollback only campaign-related views
IF OBJECT_ID('dbo.ETB2_Campaign_Absorption_Capacity', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Campaign_Absorption_Capacity;

IF OBJECT_ID('dbo.ETB2_Campaign_Risk_Adequacy', 'V') IS NOT NULL
    DROP VIEW dbo.ETB2_Campaign_Risk_Adequacy;
```

## Rollback Verification

After rollback, verify views have been removed:

```sql
-- Check remaining ETB2 views
SELECT 
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS ViewName
FROM sys.views
WHERE name LIKE 'ETB2_%'
ORDER BY name;

-- Should return 0 rows if all views dropped
```

## Restore Original Views

If you need to restore the original (pre-refactored) views:

1. Locate the original view definitions from your source control
2. Execute the original CREATE VIEW statements
3. Verify functionality matches pre-deployment state

## Emergency Contact

If rollback fails or causes issues:
1. Do not attempt further modifications
2. Contact database administrator immediately
3. Reference this rollback guide and deployment timestamp

## Rollback Checklist

- [ ] Identify reason for rollback
- [ ] Notify stakeholders of rollback
- [ ] Execute rollback script
- [ ] Verify all ETB2 views removed
- [ ] Test dependent applications
- [ ] Document rollback reason and resolution