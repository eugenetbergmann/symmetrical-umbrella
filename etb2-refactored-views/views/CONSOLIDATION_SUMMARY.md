# ETB2 Refactored Views - Consolidation Summary

**Date:** 2026-01-30  
**Status:** COMPLETE

---

## Overview

All views have been consolidated into `etb2-refactored-views/views/` with the following features:

1. **ETB2 Context Columns**: `client`, `contract`, `run` preserved throughout
2. **FG + Construct**: Sourced from `ETB_PAB_MO` using PAB-style derivation
3. **CleanOrder Normalization**: Strip MO, hyphens, spaces, punctuation, uppercase
4. **Is_Suppressed Flag**: Data quality filtering

---

## Views Consolidated (14 Total)

| View | FG/Construct Source | Notes |
|------|---------------------|-------|
| 04_ETB2_Demand_Cleaned_Base | ETB_PAB_MO join | Foundation view |
| 05_ETB2_Inventory_WC_Batches | Lot-to-order pattern matching | WC inventory |
| 06_ETB2_Inventory_Quarantine_Restricted | Lot-to-order pattern matching | WFQ/RMQTY |
| 07_ETB2_Inventory_Unified | Inherited from 05, 06 | Unified inventory |
| 08_ETB2_Planning_Net_Requirements | Aggregated from 04 | Net requirements |
| 09_ETB2_Planning_Stockout | Coalesced from 07, 08 | ATP analysis |
| 10_ETB2_Planning_Rebalancing_Opportunities | Coalesced from surplus/deficit | Transfer recommendations |
| 11_ETB2_Campaign_Normalized_Demand | Aggregated from 04 | CCU calculation |
| 12_ETB2_Campaign_Concurrency_Window | Inherited from 11 | CCW calculation |
| 13_ETB2_Campaign_Collision_Buffer | Inherited from 11 | Buffer calculation |
| 14_ETB2_Campaign_Risk_Adequacy | Inherited from 13 | Risk scoring |
| 15_ETB2_Campaign_Absorption_Capacity | Aggregated from 14 | Executive KPIs |
| 16_ETB2_Campaign_Model_Data_Gaps | Linked from 04 | Data quality |
| 17_ETB2_PAB_EventLedger_v1 | ETB_PAB_MO join | Event ledger |

---

## FG + Construct Derivation Pattern

### CleanOrder Normalization
```sql
UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ORDERNUMBER, 'MO', ''), '-', ''), ' ', ''), '/', ''), '.', ''), '#', '')) AS CleanOrder
```

### Source Attribution
- **FG** → `ETB_PAB_MO.FG`
- **FG Desc** → `ETB_PAB_MO.[FG Desc]`
- **Construct** → `ETB_PAB_MO.Customer`

---

## Redundant Folder Removed

- ✅ `refactored_views/` folder deleted
- All views now in `etb2-refactored-views/views/`

---

## Deployment

Deploy in dependency order (04 → 17):
```sql
-- 04 must be deployed first (foundation)
-- 05, 06, 07 (inventory layer)
-- 08, 09, 10 (planning layer)
-- 11, 12, 13, 14, 15 (campaign layer)
-- 16 (data gaps)
-- 17 (event ledger - between 13 and 14)
```

---

## Validation

All views expose these columns:
- `client` (VARCHAR)
- `contract` (VARCHAR)
- `run` (VARCHAR)
- `FG_Item_Number` (VARCHAR)
- `FG_Description` (VARCHAR)
- `Construct` (VARCHAR)
- `Is_Suppressed` (BIT)
