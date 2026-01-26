# Quick Start Guide - ETB2 SQL Views

## Overview

This guide helps you deploy 17 SQL Server views in the correct order using SSMS Query Designer.

## ⚠️ BEFORE YOU START

**File 17 (EventLedger) deploys between file 13 and 14!**

```
Correct order: 01→02→03→04→05→06→07→08→09→10→11→12→13→17→14→15→16
                Foundation         Data        Planning    Campaign    EventLedger Analytics
```

---

## Step 1: Open New View

1. Open SQL Server Management Studio (SSMS)
2. Connect to your database server
3. In Object Explorer, expand your database
4. Right-click **Views** folder
5. Select **New View...**

![Screenshot: Right-click Views → New View]

## Step 2: Switch to SQL Pane

When Query Designer opens, you'll see 4 panes (Diagram, Grid, SQL, Results).

**To switch to SQL-only mode:**
- **Option A:** Click **Query Designer** menu → **Pane** → **SQL**
- **Option B:** Right-click in the designer area → **Pane** → **SQL**

Now you should see only the SQL text editor pane.

## Step 3: Clear Default SQL

Delete any default SQL that appears (usually `SELECT * FROM` with a dropdown).

## Step 4: Paste Your Query

1. Open the query file (e.g., `queries/03_Config_Active.sql`)
2. Copy the SELECT statement (between `-- Copy from here ↓` and `-- Copy to here ↑`)
3. Paste into the SQL pane

## Step 5: Test Query

Click the **Execute** button (red ! icon in toolbar) or press `Ctrl+R`.

**Expected:** Results appear in the bottom pane with data rows.

**If error:** Check file header for dependencies - you may have deployed out of order.

## Step 6: Save View

1. Click **Save** (disk icon) or press `Ctrl+S`
2. Enter view name: `dbo.ETB2_Config_Active` (match exact name from file header)
3. Click **OK**

## Step 7: Verify

1. Right-click **Views** folder in Object Explorer
2. Select **Refresh**
3. Confirm your new view appears in the list

## Step 8: Repeat

Proceed to the next numbered file in the sequence.

---

## Deployment Sequence with Descriptions

| Step | File | What It Does |
|------|------|--------------|
| 1 | `01_Config_Lead_Times_TABLE.sql` | Creates table for lead time configuration |
| 2 | `02_Config_Part_Pooling_TABLE.sql` | Creates table for pooling classification |
| 3 | `03_Config_Active.sql` | Multi-tier config hierarchy (Item/Client/Global) |
| 4 | `04_Demand_Cleaned_Base.sql` | Cleans raw demand data |
| 5 | `05_Inventory_WC_Batches.sql` | Work center inventory with FEFO |
| 6 | `06_Inventory_Quarantine_Restricted.sql` | Quarantine and restricted inventory |
| 7 | `07_Inventory_Unified_Eligible.sql` | All eligible inventory combined |
| 8 | `08_Planning_Stockout_Risk.sql` | ATP and shortage risk analysis |
| 9 | `09_Planning_Net_Requirements.sql` | Procurement requirements calculation |
| 10 | `10_Planning_Rebalancing_Opportunities.sql` | Inventory transfer recommendations |
| 11 | `11_Campaign_Normalized_Demand.sql` | Campaign consumption normalization |
| 12 | `12_Campaign_Concurrency_Window.sql` | Campaign overlap calculation |
| 13 | `13_Campaign_Collision_Buffer.sql` | Buffer quantity calculation |
| **14** | **`17_PAB_EventLedger_v1.sql`** | **⚠️ EVENT LEDGER - DEPLOY NOW** |
| 15 | `14_Campaign_Risk_Adequacy.sql` | Risk adequacy assessment |
| 16 | `15_Campaign_Absorption_Capacity.sql` | Executive capacity KPI |
| 17 | `16_Campaign_Model_Data_Gaps.sql` | Data quality flagging |

---

## Common Errors & Fixes

### "Invalid column name 'XXX'"

**Cause:** Deploying out of order  
**Fix:** Start from file 01 and deploy sequentially

### "Invalid object name 'dbo.ETB2_XXX'"

**Cause:** Missing dependency view or table  
**Fix:** Check file header for required dependencies

### Query Designer shows grid, not SQL

**Fix:** Click Query Designer menu → Pane → SQL

### Save button is grayed out

**Fix:** Click Execute first to validate the query

### No rows returned

**Fix:** Check that external source tables have data

---

## Validation Queries

After each deployment, run these queries to verify:

```sql
-- Check all objects exist
SELECT name, type_desc FROM sys.objects 
WHERE name LIKE 'ETB2_%' 
ORDER BY name;

-- Count rows in each view
SELECT 'ETB2_Config_Active' AS ViewName, COUNT(*) AS RowCount FROM dbo.ETB2_Config_Active
UNION ALL
SELECT 'ETB2_Demand_Cleaned_Base', COUNT(*) FROM dbo.ETB2_Demand_Cleaned_Base;
-- Add more as needed
```

---

## Need Help?

- See [docs/DEPLOYMENT_ORDER.md](docs/DEPLOYMENT_ORDER.md) for detailed dependency information
- See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for error solutions
- See [docs/VIEW_DEFINITIONS.md](docs/VIEW_DEFINITIONS.md) for view purposes and formulas
