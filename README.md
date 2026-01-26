# ETB2 SQL Views - Query Designer Deployment

## ⚠️ CRITICAL: Deployment Order

**You MUST deploy in numerical order. View 17 (EventLedger) deploys BETWEEN files 13 and 14, NOT at the end!**

### Correct Deployment Sequence:

**START HERE:**
1. ✅ `01_Config_Lead_Times_TABLE.sql` - Create table first
2. ✅ `02_Config_Part_Pooling_TABLE.sql` - Create table first  
3. ✅ `03_Config_Active.sql` - First view (depends on tables 1-2)
4. ✅ `04_Demand_Cleaned_Base.sql`
5. ✅ `05_Inventory_WC_Batches.sql`
6. ✅ `06_Inventory_Quarantine_Restricted.sql`
7. ✅ `07_Inventory_Unified_Eligible.sql`
8. ✅ `08_Planning_Stockout_Risk.sql`
9. ✅ `09_Planning_Net_Requirements.sql`
10. ✅ `10_Planning_Rebalancing_Opportunities.sql`
11. ✅ `11_Campaign_Normalized_Demand.sql`
12. ✅ `12_Campaign_Concurrency_Window.sql`
13. ✅ `13_Campaign_Collision_Buffer.sql`
14. ⚠️ `17_PAB_EventLedger_v1.sql` - **DEPLOY NOW** (between 13 and 14)
15. ✅ `14_Campaign_Risk_Adequacy.sql`
16. ✅ `15_Campaign_Absorption_Capacity.sql`
17. ✅ `16_Campaign_Model_Data_Gaps.sql` - **LAST**

---

## How to Use Query Designer

### Step-by-Step for Each View:

1. **Open New View**
   - Object Explorer → Right-click **Views** → **New View**
   - Query Designer opens with 4 panes

2. **Switch to SQL Pane**
   - Method A: Menu bar → **Query Designer** → **Pane** → **SQL** only
   - Method B: Right-click in designer area → **Pane** → **SQL**
   - This hides the grid/diagram and shows just SQL text editor

3. **Clear Default SQL**
   - Delete the default `SELECT` statement that appears

4. **Paste Your Query**
   - Open query file (e.g., `03_Config_Active.sql`)
   - Copy the SELECT statement (between the marker comments)
   - Paste into SQL pane

5. **Test Query**
   - Click **Execute** button (red ! icon) or press Ctrl+R
   - Results appear at bottom
   - Verify you see data (not errors)

6. **Save as View**
   - Click **Save** (disk icon) or press Ctrl+S
   - Enter name: `dbo.ETB2_Config_Active`
   - Click OK

7. **Verify**
   - Refresh Views folder in Object Explorer
   - Confirm view appears in list

8. **Move to Next File**
   - Proceed to next numbered query file

---

## Why Your EventLedger Failed

The error shows these invalid columns:
- `ITEMNMBR` ✗
- `POSTSTATUS` ✗  
- `QTYORDER` ✗
- `CITYCANCEL` ✗
- etc.

**Root cause:** EventLedger (file 17) depends on many other views that don't exist yet.

**Fix:** Start over from file 01 and deploy in exact numerical order.

---

## Quick Troubleshooting

### "Invalid column name"
- **Cause:** You're deploying out of order
- **Fix:** Check file number, verify all lower-numbered views exist first

### "Invalid object name 'dbo.ETB2_XXX'"  
- **Cause:** Missing dependency view
- **Fix:** Deploy dependencies first (check file header for list)

### Query Designer shows grid instead of SQL
- **Fix:** Click Query Designer menu → Pane → SQL

### Save button grayed out
- **Fix:** Click Execute first to validate query

---

## Deployment Checklist

Print and check off as you deploy:

**Foundation:**
- [ ] 01 - Config_Lead_Times (TABLE)
- [ ] 02 - Config_Part_Pooling (TABLE)
- [ ] 03 - Config_Active (VIEW)

**Data Foundation:**
- [ ] 04 - Demand_Cleaned_Base
- [ ] 05 - Inventory_WC_Batches  
- [ ] 06 - Inventory_Quarantine_Restricted

**Unified Inventory:**
- [ ] 07 - Inventory_Unified_Eligible

**Planning:**
- [ ] 08 - Planning_Stockout_Risk
- [ ] 09 - Planning_Net_Requirements
- [ ] 10 - Planning_Rebalancing_Opportunities

**Campaign Foundation:**
- [ ] 11 - Campaign_Normalized_Demand
- [ ] 12 - Campaign_Concurrency_Window
- [ ] 13 - Campaign_Collision_Buffer

**⚠️ CRITICAL - EventLedger NOW:**
- [ ] 17 - PAB_EventLedger_v1 (DEPLOY BETWEEN 13 AND 14)

**Campaign Analytics:**
- [ ] 14 - Campaign_Risk_Adequacy
- [ ] 15 - Campaign_Absorption_Capacity  
- [ ] 16 - Campaign_Model_Data_Gaps

**Validation:**
- [ ] All 17 objects exist: `SELECT COUNT(*) FROM sys.objects WHERE name LIKE 'ETB2_%'`
- [ ] Result should be 17

✅ **Done!**
