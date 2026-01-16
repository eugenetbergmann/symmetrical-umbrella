# Rolyat Pipeline Deployment Guide

## Overview

This document provides comprehensive deployment instructions for the Rolyat Stock-Out Intelligence Pipeline. The pipeline consists of SQL Server views that provide deterministic, noise-reduced, WF-Q/RMQTY-aware stock-out intelligence.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Architecture Overview](#architecture-overview)
3. [Deployment Order](#deployment-order)
4. [Step-by-Step Deployment](#step-by-step-deployment)
5. [Configuration](#configuration)
6. [Validation](#validation)
7. [Rollback Procedures](#rollback-procedures)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Database Requirements

- **SQL Server**: 2016 or later (for `GREATEST` function support)
- **Database**: MED (or your target database)
- **Permissions**: 
  - `CREATE VIEW` permission
  - `SELECT` permission on source tables
  - `EXECUTE` permission for stored procedures

### Source Tables Required

| Table | Description |
|-------|-------------|
| `dbo.ETB_PAB_AUTO` | Primary demand/supply data source |
| `dbo.IV00300` | Inventory lot master |
| `dbo.IV00101` | Item master |
| `dbo.Rolyat_Site_Config` | Site configuration (WFQ/RMQTY locations) |
| `dbo.Rolyat_PO_Detail` | Purchase order details |

### Configuration Function

The pipeline requires a configuration function `dbo.fn_GetConfig` for retrieving item/client-specific parameters. If not present, create a stub:

```sql
CREATE FUNCTION dbo.fn_GetConfig(
    @ITEMNMBR NVARCHAR(50),
    @Client_ID NVARCHAR(50),
    @ConfigKey NVARCHAR(100),
    @AsOfDate DATETIME
)
RETURNS NVARCHAR(100)
AS
BEGIN
    -- Default values for common config keys
    RETURN CASE @ConfigKey
        WHEN 'Degradation_Tier1_Days' THEN '30'
        WHEN 'Degradation_Tier1_Factor' THEN '1.00'
        WHEN 'Degradation_Tier2_Days' THEN '60'
        WHEN 'Degradation_Tier2_Factor' THEN '0.75'
        WHEN 'Degradation_Tier3_Days' THEN '90'
        WHEN 'Degradation_Tier3_Factor' THEN '0.50'
        WHEN 'Degradation_Tier4_Factor' THEN '0.00'
        WHEN 'WFQ_Hold_Days' THEN '14'
        WHEN 'WFQ_Expiry_Filter_Days' THEN '90'
        WHEN 'RMQTY_Hold_Days' THEN '7'
        WHEN 'RMQTY_Expiry_Filter_Days' THEN '90'
        WHEN 'WC_Batch_Shelf_Life_Days' THEN '180'
        ELSE '0'
    END
END
GO
```

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        DATA FLOW DIAGRAM                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌──────────────┐                                                        │
│  │ ETB_PAB_AUTO │──────┐                                                 │
│  └──────────────┘      │                                                 │
│                        ▼                                                 │
│              ┌─────────────────────────────┐                             │
│              │ Rolyat_Cleaned_Base_Demand_1│  (Layer 1: Data Cleansing)  │
│              └─────────────────────────────┘                             │
│                        │                                                 │
│                        ▼                                                 │
│  ┌──────────────┐    ┌─────────────────────────────────┐                 │
│  │ WC_Inventory │───▶│ Rolyat_WC_Allocation_Effective_2│ (Layer 2)       │
│  └──────────────┘    └─────────────────────────────────┘                 │
│                        │                                                 │
│                        ▼                                                 │
│  ┌──────────────┐    ┌─────────────────────────────┐                     │
│  │ PO_Detail    │───▶│ Rolyat_Final_Ledger_3       │ (Layer 3)           │
│  │ WFQ_5        │───▶│                             │                     │
│  └──────────────┘    └─────────────────────────────┘                     │
│                        │                                                 │
│                        ▼                                                 │
│              ┌─────────────────────────────┐                             │
│              │ Rolyat_StockOut_Analysis_v2 │ (Layer 4: Intelligence)     │
│              └─────────────────────────────┘                             │
│                        │                                                 │
│                        ▼                                                 │
│              ┌─────────────────────────────┐                             │
│              │ Rolyat_Rebalancing_Layer    │ (Layer 5: Rebalancing)      │
│              └─────────────────────────────┘                             │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Deployment Order

Views must be deployed in dependency order:

| Order | View Name | Dependencies |
|-------|-----------|--------------|
| 1 | `dbo.Rolyat_Cleaned_Base_Demand_1` | ETB_PAB_AUTO |
| 2 | `dbo.Rolyat_WC_Inventory` | Rolyat_Cleaned_Base_Demand_1 |
| 3 | `dbo.Rolyat_WFQ_5` | IV00300, IV00101, Rolyat_Site_Config |
| 4 | `dbo.Rolyat_Unit_Price_4` | IV00300, IV00101 |
| 5 | `dbo.Rolyat_WC_Allocation_Effective_2` | Rolyat_Cleaned_Base_Demand_1, Rolyat_WC_Inventory |
| 6 | `dbo.Rolyat_Final_Ledger_3` | Rolyat_WC_Allocation_Effective_2, Rolyat_PO_Detail, Rolyat_WFQ_5 |
| 7 | `dbo.Rolyat_StockOut_Analysis_v2` | Rolyat_Final_Ledger_3, Rolyat_WFQ_5 |
| 8 | `dbo.Rolyat_Rebalancing_Layer` | Rolyat_Final_Ledger_3, Rolyat_PO_Detail, Rolyat_WFQ_5 |
| 9 | `dbo.Rolyat_Consumption_Detail_v1` | Rolyat_Final_Ledger_3 |
| 10 | `dbo.Rolyat_Consumption_SSRS_v1` | Rolyat_Final_Ledger_3 |

---

## Step-by-Step Deployment

### Step 1: Backup Existing Views

```sql
-- Generate backup script for existing views
SELECT 
    'IF OBJECT_ID(''' + SCHEMA_NAME(schema_id) + '.' + name + ''', ''V'') IS NOT NULL ' +
    'EXEC sp_rename ''' + SCHEMA_NAME(schema_id) + '.' + name + ''', ''' + name + '_backup_' + 
    FORMAT(GETDATE(), 'yyyyMMdd') + ''';'
FROM sys.views
WHERE name LIKE 'Rolyat_%';
```

### Step 2: Deploy Configuration Function

```sql
-- Deploy fn_GetConfig if not exists
-- See Prerequisites section for implementation
```

### Step 3: Deploy Views in Order

Execute each SQL file in the following order:

```bash
# From repository root
sqlcmd -S <server> -d MED -i dbo.Rolyat_Cleaned_Base_Demand_1.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_WC_Inventory.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_WFQ_5.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Unit_Price_4.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_WC_Allocation_Effective_2.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Final_Ledger_3.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_StockOut_Analysis_v2.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Rebalancing_Layer.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Consumption_Detail_v1.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Consumption_SSRS_v1.sql
```

### Step 4: Deploy Test Framework

```sql
-- Deploy test schema and procedures
sqlcmd -S <server> -d MED -i tests/synthetic_data_generation.sql
sqlcmd -S <server> -d MED -i tests/unit_tests.sql
sqlcmd -S <server> -d MED -i tests/test_harness.sql
```

### Step 5: Run Validation Tests

```sql
-- Run unit tests
EXEC tests.sp_run_unit_tests;

-- Or run full harness
EXEC tests.sp_run_test_iterations @max_iterations = 5, @seed_start = 1000;
```

---

## Configuration

### Active Window Configuration

The active planning window is set to ±21 days from current date. To modify:

1. Update `dbo.Rolyat_Cleaned_Base_Demand_1.sql`:
   ```sql
   -- Change 21 to desired days
   DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
   ```

### Degradation Tiers

Configure via `dbo.fn_GetConfig` or update defaults:

| Tier | Age (Days) | Factor |
|------|------------|--------|
| 1 | 0-30 | 1.00 |
| 2 | 31-60 | 0.75 |
| 3 | 61-90 | 0.50 |
| 4 | >90 | 0.00 |

### Action Tag Thresholds

Modify in `dbo.Rolyat_StockOut_Analysis_v2.sql`:

| Tag | Deficit Threshold |
|-----|-------------------|
| URGENT_PURCHASE | ≥100 |
| URGENT_TRANSFER | ≥50 |
| URGENT_EXPEDITE | <50 |

---

## Validation

### Quick Validation Queries

```sql
-- Check view row counts
SELECT 'Rolyat_Cleaned_Base_Demand_1' AS View_Name, COUNT(*) AS Row_Count 
FROM dbo.Rolyat_Cleaned_Base_Demand_1
UNION ALL
SELECT 'Rolyat_Final_Ledger_3', COUNT(*) FROM dbo.Rolyat_Final_Ledger_3
UNION ALL
SELECT 'Rolyat_StockOut_Analysis_v2', COUNT(*) FROM dbo.Rolyat_StockOut_Analysis_v2;

-- Check for stock-out items
SELECT TOP 10 * 
FROM dbo.Rolyat_StockOut_Analysis_v2 
WHERE Action_Tag LIKE 'URGENT_%'
ORDER BY Deficit_ATP DESC;

-- Verify active window flagging
SELECT 
    IsActiveWindow,
    COUNT(*) AS Row_Count,
    MIN(DUEDATE) AS Min_Date,
    MAX(DUEDATE) AS Max_Date
FROM dbo.Rolyat_Cleaned_Base_Demand_1
GROUP BY IsActiveWindow;
```

### Run Full Test Suite

```sql
-- Execute comprehensive unit tests
EXEC tests.sp_run_unit_tests;

-- Expected: All tests PASS
-- Review any failures before production use
```

---

## Rollback Procedures

### Quick Rollback

```sql
-- Drop new views and restore backups
DECLARE @date NVARCHAR(8) = FORMAT(GETDATE(), 'yyyyMMdd');

-- Drop new views
DROP VIEW IF EXISTS dbo.Rolyat_Consumption_SSRS_v1;
DROP VIEW IF EXISTS dbo.Rolyat_Consumption_Detail_v1;
DROP VIEW IF EXISTS dbo.Rolyat_Rebalancing_Layer;
DROP VIEW IF EXISTS dbo.Rolyat_StockOut_Analysis_v2;
DROP VIEW IF EXISTS dbo.Rolyat_Final_Ledger_3;
DROP VIEW IF EXISTS dbo.Rolyat_WC_Allocation_Effective_2;
DROP VIEW IF EXISTS dbo.Rolyat_Unit_Price_4;
DROP VIEW IF EXISTS dbo.Rolyat_WFQ_5;
DROP VIEW IF EXISTS dbo.Rolyat_WC_Inventory;
DROP VIEW IF EXISTS dbo.Rolyat_Cleaned_Base_Demand_1;

-- Restore backups (adjust date as needed)
-- EXEC sp_rename 'dbo.Rolyat_Cleaned_Base_Demand_1_backup_20260116', 'Rolyat_Cleaned_Base_Demand_1';
-- ... repeat for each view
```

---

## Troubleshooting

### Common Issues

#### 1. "Invalid object name 'dbo.fn_GetConfig'"

**Solution**: Deploy the configuration function (see Prerequisites).

#### 2. "GREATEST is not a recognized built-in function"

**Solution**: Requires SQL Server 2022+ or replace with:
```sql
CASE WHEN value1 > value2 THEN value1 ELSE value2 END
```

#### 3. View returns no rows

**Check**:
- Source table `ETB_PAB_AUTO` has data
- Date filters are not excluding all rows
- Item prefixes 60.x/70.x are expected to be excluded

#### 4. Performance issues

**Solutions**:
- Add indexes on frequently filtered columns
- Consider materialized views for large datasets
- Review execution plans for bottlenecks

### Support Contacts

For deployment issues:
1. Review test results: `EXEC tests.sp_run_unit_tests;`
2. Check diagnostics: `EXEC tests.sp_generate_diagnostics;`
3. Review iteration log: `SELECT * FROM tests.TestIterationLog ORDER BY iteration_id DESC;`

---

## Appendix: File Manifest

| File | Description |
|------|-------------|
| `dbo.Rolyat_Cleaned_Base_Demand_1.sql` | Data cleansing and base demand calculation |
| `dbo.Rolyat_WC_Allocation_Effective_2.sql` | WC allocation with FEFO logic |
| `dbo.Rolyat_Final_Ledger_3.sql` | Running balance calculations |
| `dbo.Rolyat_Unit_Price_4.sql` | Blended cost calculation |
| `dbo.Rolyat_WFQ_5.sql` | WFQ/RMQTY inventory tracking |
| `dbo.Rolyat_WC_Inventory.sql` | WC batch inventory |
| `dbo.Rolyat_StockOut_Analysis_v2.sql` | Stock-out intelligence |
| `dbo.Rolyat_Rebalancing_Layer.sql` | Rebalancing analysis |
| `dbo.Rolyat_Consumption_Detail_v1.sql` | Detailed consumption view |
| `dbo.Rolyat_Consumption_SSRS_v1.sql` | SSRS-optimized view |
| `tests/unit_tests.sql` | Comprehensive test suite |
| `tests/assertions.sql` | Standalone assertion queries |
| `tests/test_harness.sql` | Iterative test harness |
| `tests/synthetic_data_generation.sql` | Test data generation |

---

*Last Updated: 2026-01-16*
*Version: 2.0.0*
