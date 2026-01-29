# ETB2 Refactored Views - Deployment Guide

## Overview
This guide provides instructions for deploying the 18 refactored ETB2 views to your SQL Server environment.

## Deployment Order

Views must be deployed in the following dependency order:

1. **01_ETB2_Config_Lead_Times.sql** - Base configuration (no dependencies)
2. **02_ETB2_Config_Part_Pooling.sql** - Base configuration (no dependencies)
3. **02B_ETB2_Config_Items.sql** - Base configuration (no dependencies)
4. **03_ETB2_Config_Active.sql** - Depends on 01, 02
5. **04_ETB2_Demand_Cleaned_Base.sql** - Depends on 02B
6. **05_ETB2_Inventory_WC_Batches.sql** - Depends on external tables
7. **06_ETB2_Inventory_Quarantine_Restricted.sql** - Depends on external tables
8. **07_ETB2_Inventory_Unified.sql** - Depends on 05, 06
9. **08_ETB2_Planning_Net_Requirements.sql** - Depends on 04, 02B
10. **09_ETB2_Planning_Stockout.sql** - Depends on 08, 07, 02B
11. **10_ETB2_Planning_Rebalancing_Opportunities.sql** - Depends on 04, 07
12. **11_ETB2_Campaign_Normalized_Demand.sql** - Depends on 04
13. **12_ETB2_Campaign_Concurrency_Window.sql** - Depends on 11
14. **13_ETB2_Campaign_Collision_Buffer.sql** - Depends on 11, 12
15. **14_ETB2_Campaign_Risk_Adequacy.sql** - Depends on 13, 07
16. **15_ETB2_Campaign_Absorption_Capacity.sql** - Depends on 14
17. **16_ETB2_Campaign_Model_Data_Gaps.sql** - Depends on 03, 07, 04, 11
18. **17_ETB2_PAB_EventLedger_v1.sql** - Depends on 04, external tables

## Deployment Steps

### Step 1: Pre-Deployment Checklist
- [ ] Backup existing database
- [ ] Verify SQL Server version compatibility (2016+)
- [ ] Ensure all external tables exist:
  - dbo.IV00101 (Item Master)
  - dbo.IV00102 (Item Quantity Master)
  - dbo.IV00300 (Serial/Lot Master)
  - dbo.POP10100 (Purchase Order Work)
  - dbo.POP10110 (Purchase Line)
  - dbo.ETB_PAB_AUTO (PAB Auto)
  - dbo.Prosenthal_Vendor_Items (Vendor Items)
  - dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (Inventory Bin Qty)

### Step 2: Deploy Views

#### Option A: Manual Deployment (SSMS)
1. Open SQL Server Management Studio (SSMS)
2. Connect to target database
3. For each view file (in order):
   - Open the .sql file
   - Execute the SELECT statement to verify it runs
   - Select all (Ctrl+A)
   - Right-click → Create View
   - Save with the view name specified in the file header

#### Option B: Scripted Deployment
```sql
-- Execute each view creation script in order
-- Example for view 01:
CREATE VIEW dbo.ETB2_Config_Lead_Times AS
SELECT DISTINCT
    'DEFAULT_CLIENT' AS client,
    'DEFAULT_CONTRACT' AS contract,
    'CURRENT_RUN' AS run,
    ITEMNMBR,
    30 AS Lead_Time_Days,
    GETDATE() AS Last_Updated,
    'SYSTEM_DEFAULT' AS Config_Source,
    CAST(0 AS BIT) AS Is_Suppressed
FROM dbo.IV00101 WITH (NOLOCK)
WHERE ITEMNMBR IS NOT NULL
  AND ITEMNMBR NOT LIKE 'MO-%'
  AND CAST(GETDATE() AS DATE) BETWEEN 
      DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
      AND DATEADD(DAY, 90, CAST(GETDATE() AS DATE))
  AND CAST(0 AS BIT) = 0;
```

### Step 3: Post-Deployment Verification

Run the following verification queries:

```sql
-- Check all views exist
SELECT 
    SCHEMA_NAME(schema_id) AS SchemaName,
    name AS ViewName,
    create_date,
    modify_date
FROM sys.views
WHERE name LIKE 'ETB2_%'
ORDER BY name;

-- Verify view 01 returns data
SELECT TOP 5 * FROM dbo.ETB2_Config_Lead_Times;

-- Verify view 04 returns data
SELECT TOP 5 * FROM dbo.ETB2_Demand_Cleaned_Base;

-- Verify view 07 returns data
SELECT TOP 5 * FROM dbo.ETB2_Inventory_Unified;

-- Check for MO- items (should return 0 rows)
SELECT COUNT(*) AS MO_Item_Count 
FROM dbo.ETB2_Demand_Cleaned_Base 
WHERE Item_Number LIKE 'MO-%';

-- Check Is_Suppressed filter (should return 0 rows)
SELECT COUNT(*) AS Suppressed_Count 
FROM dbo.ETB2_Config_Lead_Times 
WHERE Is_Suppressed = 1;
```

## Key Refactoring Changes

### 1. Context Columns
All views now include three context columns:
- `client` - Client identifier
- `contract` - Contract identifier  
- `run` - Run/batch identifier

### 2. Is_Suppressed Flag
All views include an `Is_Suppressed` BIT column that:
- Defaults to 0 (not suppressed)
- Is filtered in WHERE/HAVING clauses to exclude suppressed records

### 3. MO Conflation Filter
All views filter out items with ITEMNMBR LIKE 'MO-%' to prevent conflation issues.

### 4. Date Window Expansion
Date windows expanded from ±21 days to ±90 days for broader data capture.

### 5. ROW_NUMBER Partitioning
Views using ROW_NUMBER now include context columns in PARTITION BY:
```sql
ROW_NUMBER() OVER (
    PARTITION BY client, contract, run, ITEMNMBR
    ORDER BY Expiry_Date ASC, Receipt_Date ASC
) AS Use_Sequence
```

## Troubleshooting

### Issue: View creation fails with "Invalid object name"
**Solution**: Ensure all dependent views are created first, following the deployment order.

### Issue: "Column names in each view must be unique"
**Solution**: Check that all column aliases are unique within the SELECT statement.

### Issue: No data returned from views
**Solution**: 
- Verify external tables have data
- Check that date filters aren't too restrictive
- Ensure ITEMNMBR values don't contain leading/trailing spaces

### Issue: Permission denied
**Solution**: Ensure the deploying user has CREATE VIEW permission and SELECT permission on all referenced tables.

## Rollback Procedure

See ROLLBACK.md for detailed rollback instructions.

## Support

For issues or questions:
1. Check the verification report at /etb2-refactored-views/verification/VALIDATION_REPORT.txt
2. Review view-specific documentation in the SQL file headers
3. Contact the ETB2 development team