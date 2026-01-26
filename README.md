# ETB2 SQL Views - Views 04-17 Deployment

> ✅ **Views 01-03 already deployed successfully**  
> 🔴 **Deploy views 04-17 using same method**  
> ⏱️ **Estimated time:** 15-20 minutes

---

## Current Status

### ✅ Already Deployed (Foundation)
- **01** - ETB2_Config_Lead_Times ✅
- **02** - ETB2_Config_Part_Pooling ✅
- **03** - ETB2_Config_Active ✅

### 🔴 To Deploy (Data, Planning, Campaign layers)
- **04** - Demand_Cleaned_Base ← **START HERE**
- **05** - Inventory_WC_Batches
- **06** - Inventory_Quarantine_Restricted
- **07** - Inventory_Unified_Eligible
- **08** - Planning_Stockout_Risk
- **09** - Planning_Net_Requirements
- **10** - Planning_Rebalancing_Opportunities
- **11** - Campaign_Normalized_Demand
- **12** - Campaign_Concurrency_Window
- **13** - Campaign_Collision_Buffer
- **17** - PAB_EventLedger_v1 ⚠️ Deploy here (before 14)
- **14** - Campaign_Risk_Adequacy
- **15** - Campaign_Absorption_Capacity
- **16** - Campaign_Model_Data_Gaps

---

## Deployment Method (Same as Views 1-3)

You've already done this 3 times successfully. Continue the same way:

### For Each View (04-17):

1. **Open New View**
   - Object Explorer → Right-click Views → New View...

2. **Switch to SQL Pane** ⚠️
   - Menu: Query Designer → Pane → SQL
   - (Hides diagram/grid - same as before)

3. **Paste Query**
   - Open query file (e.g., `04_Demand_Cleaned_Base.sql`)
   - Copy SELECT between markers
   - Paste into SQL pane

4. **Test & Save**
   - Execute (!) to test
   - Save as: dbo.ETB2_[ViewName]
   - Verify in Views folder

5. **Next File**
   - Move to next numbered file

---

## Deployment Sequence

**Phase 2: Data Foundation**
- 04 → 05 → 06

**Phase 3: Unified Inventory**
- 07

**Phase 4: Planning**
- 08 → 09 → 10

**Phase 5: Campaign Foundation**
- 11 → 12 → 13

**Phase 6: Event Ledger**
- 17 ⚠️ Deploy here (not at end)

**Phase 7: Campaign Analytics**
- 14 → 15 → 16

---

## Dependencies Reference

| View # | Depends On |
|--------|------------|
| 04 | Config views (✅), ETB_PAB_AUTO |
| 05 | Prosenthal_INV_BIN_QTY_wQTYTYPE, EXT_BINTYPE |
| 06 | IV00300, IV00101 |
| 07 | Views 05, 06 |
| 08 | Views 04, 05 |
| 09 | Views 04, 05 |
| 10 | Views 04, 05, 06 |
| 11 | View 04 |
| 12 | Views 11, 03 (✅) |
| 13 | Views 11, 12, 02 (✅) |
| 17 | View 04, POP tables, IV00102 |
| 14 | Views 07, 17, 04, 13 |
| 15 | Views 13, 14, 03 (✅), 02 (✅) |
| 16 | Views 03 (✅), 02 (✅) |

---

## Progress Tracking

After each deployment, check it off:

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

**Event Ledger:**
- [ ] 17 - PAB_EventLedger_v1

**Campaign Analytics:**
- [ ] 14 - Campaign_Risk_Adequacy
- [ ] 15 - Campaign_Absorption_Capacity
- [ ] 16 - Campaign_Model_Data_Gaps

---

## Quick Validation After Deploying All

```sql
-- Should return 17 total views
SELECT COUNT(*) FROM sys.views WHERE name LIKE 'ETB2_%'

-- List all deployed views
SELECT name FROM sys.views 
WHERE name LIKE 'ETB2_%'
ORDER BY name

-- Check key views have data
SELECT 'Demand' AS Layer, COUNT(*) FROM dbo.ETB2_Demand_Cleaned_Base
UNION ALL
SELECT 'Inventory', COUNT(*) FROM dbo.ETB2_Inventory_WC_Batches
UNION ALL
SELECT 'Planning', COUNT(*) FROM dbo.ETB2_Planning_Stockout_Risk
UNION ALL
SELECT 'Campaign', COUNT(*) FROM dbo.ETB2_Campaign_Collision_Buffer
```

---

## Important Notes

### ETB_PAB_AUTO Quirks
Many columns are stored as VARCHAR but contain numbers. All query files use safe conversion:
```sql
CASE 
    WHEN ISNUMERIC(column) = 1 
    THEN CAST(column AS DECIMAL(18,5))
    ELSE 0 
END
```

### File 17 Deploys Out of Order
- File **17** (EventLedger) deploys BETWEEN files 13 and 14
- This is because view 14 depends on view 17
- Deploy sequence: 01→02→03→04→05→06→07→08→09→10→11→12→13→**17**→14→15→16

---

## Troubleshooting

### "Invalid object name 'dbo.ETB2_XXX'"
**Cause:** Dependency view not deployed yet  
**Fix:** Check deploy order, create dependencies first

### View has 0 rows
**Cause:** Source table empty or filters too restrictive  
**Fix:** 
- Check ETB_PAB_AUTO has data: `SELECT COUNT(*) FROM dbo.ETB_PAB_AUTO`
- Review WHERE clause in view definition

### "Arithmetic overflow" error
**Cause:** Missing ISNUMERIC check before CAST  
**Fix:** Use query files as-is (they have safe conversion)

---

## What You're Building

**You've completed:** Configuration foundation  
**Now building:**
- Data foundation (demand, inventory)
- Planning layer (risk, requirements, rebalancing)
- Campaign model (CCU, CCW, collision buffers)
- Event ledger (audit trail)
- Campaign analytics (risk assessment, capacity)

**End goal:** Complete supply chain planning and analytics system
