# ETB2 Deployment Status Tracker

## Deployment Progress

**Last Updated:** 2026-01-28  
**Total Views:** 17  
**Deployed:** 3  
**Remaining:** 14  
**Refactoring Status:** ✅ ALL VIEWS 10-17 REFACTORED

---

## Phase Status

### ✅ Phase 1: Configuration Foundation (COMPLETE)
- [x] 01 - ETB2_Config_Lead_Times
- [x] 02 - ETB2_Config_Part_Pooling
- [x] 03 - ETB2_Config_Active

### 🔄 Phase 2: Data Foundation (IN PROGRESS)
- [ ] 04 - ETB2_Demand_Cleaned_Base ← **DEPLOY NEXT**
- [ ] 05 - ETB2_Inventory_WC_Batches
- [ ] 06 - ETB2_Inventory_Quarantine_Restricted

### ⏸️ Phase 3: Unified Inventory (PENDING)
- [ ] 07 - ETB2_Inventory_Unified_Eligible

### ⏸️ Phase 4: Planning Core (PENDING)
- [ ] 08 - ETB2_Planning_Stockout_Risk
- [ ] 09 - ETB2_Planning_Net_Requirements
- [ ] 10 - ETB2_Planning_Rebalancing_Opportunities

### ⏸️ Phase 5: Campaign Foundation (PENDING)
- [ ] 11 - ETB2_Campaign_Normalized_Demand
- [ ] 12 - ETB2_Campaign_Concurrency_Window
- [ ] 13 - ETB2_Campaign_Collision_Buffer

### ⏸️ Phase 6: Event Ledger (PENDING)
- [ ] 17 - ETB2_PAB_EventLedger_v1 ⚠️ Deploys after 13

### ⏸️ Phase 7: Campaign Analytics (PENDING)
- [ ] 14 - ETB2_Campaign_Risk_Adequacy
- [ ] 15 - ETB2_Campaign_Absorption_Capacity
- [ ] 16 - ETB2_Campaign_Model_Data_Gaps

---

## REFACTORING COMPLETED (Views 10-17)

### Issues Fixed in Views 10-17:

| View | File | Issues Fixed |
|------|------|--------------|
| 10 | 10_Planning_Rebalancing_Opportunities.sql | ETB3→ETB2 ref, NOLOCK, COALESCE, TRY_CAST |
| 11 | 11_Campaign_Normalized_Demand.sql | ETB3→ETB2 ref, NOLOCK, COALESCE, TRY_CAST |
| 12 | 12_Campaign_Concurrency_Window.sql | ETB3→ETB2 ref, NOLOCK, NULLIF for division |
| 13 | 13_Campaign_Collision_Buffer.sql | ETB3→ETB2 ref, NOLOCK |
| 14 | 14_Campaign_Risk_Adequacy.sql | NOLOCK, NULLIF, COALESCE, TRY_CAST |
| 15 | 15_Campaign_Absorption_Capacity.sql | NOLOCK, COALESCE, TRY_CAST |
| 16 | 16_Campaign_Model_Data_Gaps.sql | ETB3→ETB2 refs (3 places), NOLOCK |
| 17 | 17_PAB_EventLedger_v1.sql | ETB3→ETB2 ref, NOLOCK, TRY_CAST, TRY_CONVERT |

### Summary of Changes:
- **ETB3 References Fixed:** 8 occurrences across views 10-17
- **NOLOCK Hints Added:** All table references now have WITH (NOLOCK)
- **Type Safety:** TRY_CAST added to all quantity columns
- **Date Safety:** TRY_CONVERT added to all date fields
- **NULL Safety:** COALESCE added to all aggregations
- **Division Safety:** NULLIF added to prevent divide-by-zero

---

## Next Steps

**Current Action:** Deploy view 04 (Demand_Cleaned_Base)

**After completing Phase 2:**
- Validate data foundation views have rows
- Proceed to Phase 3 (Unified Inventory)

**After completing all phases:**
- Run comprehensive validation
- Test with end users
- Update configuration tables with real data

---

## Notes

- Config foundation working correctly ✅
- Same deployment method for all remaining views
- Remember: File 17 deploys between 13 and 14
- All views 10-17 have been refactored with ETB3→ETB2 fixes
