# ETB2 SQL Views - 17 Views for Supply Chain Planning

> **All Objects Are Views** - No tables to create  
> **Method:** Copy-paste SELECT statements into SSMS Query Designer  
> **Time:** 20-30 minutes for all 17 views

---

## Quick Start

### Prerequisites
- SQL Server Management Studio (SSMS)
- Connection to target database
- CREATE VIEW permission
- External tables exist (see `/reference/external_tables_required.md`)

---

## ⚠️ Deployment Order (CRITICAL)

Deploy in exact numerical order. Each view depends on previous ones.

**Exception:** View 17 deploys BETWEEN files 13 and 14 (not at the end).

### Correct Deployment Sequence:

```
01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10 → 11 → 12 → 13 → 17 → 14 → 15 → 16
          ↑                                                          ↑
          |                                                          |
     (Views only)                                              (DEPLOY HERE)
```

### Deployment Order Table:

| # | File | View Name | Deploy After |
|---|------|-----------|--------------|
| 01 | `01_Config_Lead_Times.sql` | ETB2_Config_Lead_Times | - (first) |
| 02 | `02_Config_Part_Pooling.sql` | ETB2_Config_Part_Pooling | 01 |
| 03 | `03_Config_Active.sql` | ETB2_Config_Active | 01, 02 |
| 04 | `04_Demand_Cleaned_Base.sql` | ETB2_Demand_Cleaned_Base | External only |
| 05 | `05_Inventory_WC_Batches.sql` | ETB2_Inventory_WC_Batches | External only |
| 06 | `06_Inventory_Quarantine_Restricted.sql` | ETB2_Inventory_Quarantine_Restricted | External only |
| 07 | `07_Inventory_Unified_Eligible.sql` | ETB2_Inventory_Unified_Eligible | 05, 06 |
| 08 | `08_Planning_Stockout_Risk.sql` | ETB2_Planning_Stockout_Risk | 04, 05 |
| 09 | `09_Planning_Net_Requirements.sql` | ETB2_Planning_Net_Requirements | 04, 05 |
| 10 | `10_Planning_Rebalancing_Opportunities.sql` | ETB2_Planning_Rebalancing_Opportunities | 04, 05, 06 |
| 11 | `11_Campaign_Normalized_Demand.sql` | ETB2_Campaign_Normalized_Demand | 04 |
| 12 | `12_Campaign_Concurrency_Window.sql` | ETB2_Campaign_Concurrency_Window | 11, 03 |
| 13 | `13_Campaign_Collision_Buffer.sql` | ETB2_Campaign_Collision_Buffer | 11, 12, 02 |
| **17** | **`17_PAB_EventLedger_v1.sql`** | **ETB2_PAB_EventLedger_v1** | **13 (DEPLOY NOW!)** |
| 14 | `14_Campaign_Risk_Adequacy.sql` | ETB2_Campaign_Risk_Adequacy | 07, 17, 04, 13 |
| 15 | `15_Campaign_Absorption_Capacity.sql` | ETB2_Campaign_Absorption_Capacity | 13, 14, 03, 02 |
| 16 | `16_Campaign_Model_Data_Gaps.sql` | ETB2_Campaign_Model_Data_Gaps | 03, 02 |

---

## Deployment Process (Same for All 17 Views)

**For each query file in order:**

1. **Open New View in SSMS**
   - Object Explorer → Right-click **Views** → **New View...**

2. **Switch to SQL Pane**
   - Menu: **Query Designer** → **Pane** → **SQL**
   - (Hides diagram/grid, shows only SQL editor)

3. **Copy Query**
   - Open query file (e.g., `01_Config_Lead_Times.sql`)
   - Copy text between "COPY FROM HERE" and "COPY TO HERE" markers

4. **Paste & Test**
   - Paste into SQL pane (delete any default SQL first)
   - Click **Execute** (!) to test
   - Verify results appear (no errors)

5. **Save View**
   - Click **Save** (disk icon)
   - Enter exact name from file header: `dbo.ETB2_Config_Lead_Times`
   - Click OK

6. **Verify**
   - Refresh Views folder
   - Confirm view appears

7. **Next File**
   - Move to next numbered file
   - Repeat steps 1-6

---

## What You're Building

### Configuration Layer (01-03)
- **01_Config_Lead_Times:** 30-day lead time defaults per item
- **02_Config_Part_Pooling:** Pooling classification (Dedicated/Semi-Pooled/Pooled)
- **03_Config_Active:** Unified config with COALESCE logic

### Data Foundation (04-06)
- **04_Demand_Cleaned_Base:** Cleaned demand (excludes partial/invalid orders)
- **05_Inventory_WC_Batches:** Work center inventory (FEFO ordering)
- **06_Inventory_Quarantine_Restricted:** Quarantine/restricted inventory (hold periods)

### Unified Inventory (07)
- **07_Inventory_Unified_Eligible:** All eligible inventory consolidated

### Planning Core (08-10)
- **08_Planning_Stockout_Risk:** ATP balances and stockout risk classification
- **09_Planning_Net_Requirements:** Net procurement requirements
- **10_Planning_Rebalancing_Opportunities:** Expiry-driven transfer recommendations

### Campaign Model (11-16)
- **11_Campaign_Normalized_Demand:** Campaign consumption units (CCU)
- **12_Campaign_Concurrency_Window:** Campaign concurrency windows (CCW)
- **13_Campaign_Collision_Buffer:** Collision buffer calculations
- **14_Campaign_Risk_Adequacy:** Risk adequacy assessment
- **15_Campaign_Absorption_Capacity:** Absorption capacity KPI
- **16_Campaign_Model_Data_Gaps:** Data quality flags

### Event Ledger (17)
- **17_PAB_EventLedger_v1:** Atomic event tracking (BEGIN_BAL, PO, DEMAND, EXPIRY)
- ⚠️ **Deploy AFTER 13 but BEFORE 14**

---

## Validation

After deploying all 17 views:

```sql
-- Check all views exist
SELECT name AS ViewName
FROM sys.views
WHERE name LIKE 'ETB2_%'
ORDER BY name;
-- Should return 17 rows

-- Quick data check
SELECT 
    'ETB2_Config_Lead_Times' AS ViewName, 
    COUNT(*) AS RowCount 
FROM dbo.ETB2_Config_Lead_Times
UNION ALL
SELECT 'ETB2_Demand_Cleaned_Base', COUNT(*) FROM dbo.ETB2_Demand_Cleaned_Base
UNION ALL
SELECT 'ETB2_Planning_Stockout_Risk', COUNT(*) FROM dbo.ETB2_Planning_Stockout_Risk;
-- All should return > 0 rows
```

---

## Troubleshooting

### "Invalid object name 'dbo.ETB2_XXX'"
**Problem:** Dependency view doesn't exist yet  
**Fix:** Deploy in exact numerical order, create dependencies first

### "Invalid column name"
**Problem:** Source table structure different than expected  
**Fix:** Verify external table exists and has expected columns

### View saves but returns 0 rows
**Problem:** Source data empty or filters too restrictive  
**Fix:** Check source tables have data, review WHERE clauses

### "Incorrect syntax near 'GO'"
**Problem:** Copied GO statement into view designer  
**Fix:** Copy only SELECT statement (between markers), no GO

---

## Deployment Checklist

Print and check off as you go:

- [ ] 01 - Config_Lead_Times
- [ ] 02 - Config_Part_Pooling
- [ ] 03 - Config_Active
- [ ] 04 - Demand_Cleaned_Base
- [ ] 05 - Inventory_WC_Batches
- [ ] 06 - Inventory_Quarantine_Restricted
- [ ] 07 - Inventory_Unified_Eligible
- [ ] 08 - Planning_Stockout_Risk
- [ ] 09 - Planning_Net_Requirements
- [ ] 10 - Planning_Rebalancing_Opportunities
- [ ] 11 - Campaign_Normalized_Demand
- [ ] 12 - Campaign_Concurrency_Window
- [ ] 13 - Campaign_Collision_Buffer
- [ ] 17 - PAB_EventLedger_v1 ⚠️ Deploy before 14
- [ ] 14 - Campaign_Risk_Adequacy
- [ ] 15 - Campaign_Absorption_Capacity
- [ ] 16 - Campaign_Model_Data_Gaps

**Validation:**
- [ ] All 17 views exist
- [ ] Spot-check views return data

✅ **Done!**

---

## Support Files

- **DEPLOYMENT_ORDER.md** - Detailed dependency explanations
- **docs/VIEW_DEFINITIONS.md** - Specs for each view
- **docs/DEPENDENCY_MAP.md** - Visual dependency tree
- **docs/TROUBLESHOOTING.md** - Common issues and solutions
- **reference/external_tables_required.md** - Required external tables (10 total)
