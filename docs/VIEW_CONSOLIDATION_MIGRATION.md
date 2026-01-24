# SQL Server View Consolidation Migration Guide

## Overview
This document outlines the consolidation of 4 legacy views into 2 unified views, eliminating duplicate logic and providing single sources of truth for inventory and consumption reporting.

---

## VIEW 1: ETB2_Inventory_Unified_v1

### Purpose
Replaces **Rolyat_WC_Inventory (View 05)** and **Rolyat_WFQ_5 (View 06)** with a single unified inventory view.

### What It Consolidates
- **WC batches**: Physical bin locations, expiry dates from EXPNDATE or DATERECD + Shelf_Life
- **WFQ batches**: Hold period (14 days default), release eligibility based on DATERECD
- **RMQTY batches**: Hold period (7 days default), different release logic

### Key Columns
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR | Item number |
| Client_ID | VARCHAR | Client identifier |
| Site_ID | VARCHAR | Site/location code |
| Batch_ID | VARCHAR | Unique batch identifier |
| QTY_ON_HAND | NUMERIC | Available quantity |
| Inventory_Type | VARCHAR | 'WC_BATCH', 'WFQ_BATCH', or 'RMQTY_BATCH' |
| Receipt_Date | DATE | Date received |
| Expiry_Date | DATE | Expiration date |
| Age_Days | INT | Days since receipt |
| Projected_Release_Date | DATE | When batch becomes eligible for use |
| Days_Until_Release | INT | Days until eligible (negative = already eligible) |
| Is_Eligible_For_Release | BIT | 1 if ready to use, 0 if on hold |
| Bin_Location | VARCHAR | Physical bin (WC only) |
| Bin_Type | VARCHAR | Bin type classification (WC only) |
| UOM | VARCHAR | Unit of measure |
| SortPriority | INT | Allocation priority (1=WC, 2=WFQ, 3=RMQTY) |

### Business Rules
- **WC batches**: Always eligible (Is_Eligible_For_Release = 1), no hold period
- **WFQ batches**: Hold period configurable via ETB2_Config_Engine_v1.WFQ_Hold_Days (default 14 days)
- **RMQTY batches**: Hold period configurable via ETB2_Config_Engine_v1.RMQTY_Hold_Days (default 7 days)
- All batches sorted by FEFO (First Expiry First Out)
- Inventory_Type distinguishes batch source for allocation logic

### Downstream View Updates
Replace references as follows:

```sql
-- OLD: FROM dbo.Rolyat_WC_Inventory
-- NEW:
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'WC_BATCH'

-- OLD: FROM dbo.Rolyat_WFQ_5
-- NEW:
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type IN ('WFQ_BATCH', 'RMQTY_BATCH')
```

### Views Updated
- **View 08**: Rolyat_WC_Allocation_Effective_2 ✓ (already uses ETB2_Inventory_Unified_v1)
- **View 09**: Rolyat_Final_Ledger_3 ✓ (already uses ETB2_Inventory_Unified_v1)
- **View 10**: Rolyat_StockOut_Analysis_v2 ✓ (already uses ETB2_Inventory_Unified_v1)
- **View 11**: Rolyat_Rebalancing_Layer ✓ (already uses ETB2_Inventory_Unified_v1)
- **View 18**: Rolyat_Batch_Expiry_Risk_Dashboard ✓ (updated to use ETB2_Inventory_Unified_v1)
- **View 19**: Rolyat_Supply_Planner_Action_List ✓ (updated to use ETB2_Inventory_Unified_v1)

---

## VIEW 2: ETB2_Consumption_Detail_v1

### Purpose
Replaces **Rolyat_Consumption_Detail_v1 (View 12)** and **Rolyat_Consumption_SSRS_v1 (View 13)** with a single view serving both purposes.

### What It Consolidates
- **Detailed consumption analysis** (View 12): Technical column names for drill-down analysis
- **SSRS reporting** (View 13): Business-friendly aliases for report consumption

### Key Columns
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR | Item number |
| CleanItem | VARCHAR | Cleaned item identifier |
| Client_ID | VARCHAR | Client identifier |
| ORDERNUMBER | VARCHAR | Order/demand number |
| DUEDATE | DATE | Due date |
| Date_Expiry | DATE | Expiry date |
| SortPriority | INT | Event ordering priority |
| Base_Demand | NUMERIC | Unsuppressed demand quantity |
| Effective_Demand | NUMERIC | Demand after WC allocation |
| Demand_Qty | NUMERIC | Business-friendly alias for Base_Demand |
| ATP_Demand_Qty | NUMERIC | Business-friendly alias for Effective_Demand |
| BEG_BAL | NUMERIC | Beginning balance |
| POs | NUMERIC | Total PO supply |
| Released_PO_Qty | NUMERIC | Released PO supply only |
| WFQ_QTY | NUMERIC | Quarantine inventory |
| RMQTY_QTY | NUMERIC | Restricted material inventory |
| Original_Running_Balance | NUMERIC | Forecast balance (before allocation) |
| effective_demand | NUMERIC | ATP balance (after allocation) |
| Forecast_Balance | NUMERIC | Business-friendly alias for Original_Running_Balance |
| ATP_Balance | NUMERIC | Business-friendly alias for effective_demand |
| wc_allocation_status | VARCHAR | Technical allocation status |
| Allocation_Status | VARCHAR | Business-friendly allocation status |
| QC_Flag | BIT | Quality control flag |
| QC_Status | VARCHAR | Business-friendly QC status |
| IsActiveWindow | BIT | Within active planning window |
| Is_Active_Window | BIT | Business-friendly alias for IsActiveWindow |

### Dual Naming Strategy
The view includes **both technical and business-friendly column names** so a single view serves both purposes:

```sql
-- For detailed analysis (technical names):
SELECT ITEMNMBR, Base_Demand, effective_demand, Allocation_Status
FROM dbo.ETB2_Consumption_Detail_v1

-- For SSRS reports (business-friendly aliases):
SELECT ITEMNMBR, Demand_Qty, ATP_Balance, Allocation_Status
FROM dbo.ETB2_Consumption_Detail_v1
```

### Downstream View Updates
Any views referencing Views 12 or 13 should now reference:

```sql
FROM dbo.ETB2_Consumption_Detail_v1
```

---

## Migration Checklist

### Phase 1: Deploy New Views ✓
- [x] Create ETB2_Inventory_Unified_v1
- [x] Create ETB2_Consumption_Detail_v1

### Phase 2: Update Downstream Views ✓
- [x] View 08: Rolyat_WC_Allocation_Effective_2
- [x] View 09: Rolyat_Final_Ledger_3
- [x] View 10: Rolyat_StockOut_Analysis_v2
- [x] View 11: Rolyat_Rebalancing_Layer
- [x] View 18: Rolyat_Batch_Expiry_Risk_Dashboard
- [x] View 19: Rolyat_Supply_Planner_Action_List

### Phase 3: Validation
- [ ] Test ETB2_Inventory_Unified_v1 row counts match combined Views 05 + 06
- [ ] Test ETB2_Consumption_Detail_v1 row counts match Views 12 + 13
- [ ] Verify downstream views execute without errors
- [ ] Compare output with legacy views for data consistency
- [ ] Test allocation logic with sample data

### Phase 4: Decommission Legacy Views (Optional)
- [ ] Archive Views 05, 06, 12, 13 for historical reference
- [ ] Update documentation to reference new views
- [ ] Remove legacy views from production (after validation period)

---

## Benefits of Consolidation

### Eliminated Duplicate Logic
- **Before**: 5+ JOIN operations repeated across 6+ downstream views
- **After**: Single unified view with consistent logic

### Single Source of Truth
- **Inventory**: One view for all batch types (WC, WFQ, RMQTY)
- **Consumption**: One view for both analysis and reporting

### Reduced Maintenance
- Configuration changes (hold periods, shelf life) apply globally
- Bug fixes in batch logic fix all downstream views automatically
- Easier to audit and validate business rules

### Improved Performance
- Consolidated CTEs reduce redundant calculations
- Fewer JOIN operations in downstream views
- Potential for query optimization at single point

### Better Flexibility
- Dual naming in consumption view supports multiple use cases
- Inventory_Type column enables easy filtering by batch source
- Easier to add new batch types in future

---

## Configuration Dependencies

### ETB2_Config_Engine_v1 Columns Used
- `Shelf_Life_Days`: WC batch shelf life (default 180 days)
- `WFQ_Hold_Days`: WFQ hold period (default 14 days)
- `WFQ_Expiry_Filter_Days`: WFQ expiry filter threshold (default 90 days)
- `RMQTY_Hold_Days`: RMQTY hold period (default 7 days)
- `RMQTY_Expiry_Filter_Days`: RMQTY expiry filter threshold (default 90 days)
- `WFQ_Locations`: Sites configured for WFQ
- `RMQTY_Locations`: Sites configured for RMQTY

---

## Testing Recommendations

### Data Validation Queries

```sql
-- Verify WC batch count
SELECT COUNT(*) AS WC_Count
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'WC_BATCH';

-- Verify WFQ batch count
SELECT COUNT(*) AS WFQ_Count
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'WFQ_BATCH';

-- Verify RMQTY batch count
SELECT COUNT(*) AS RMQTY_Count
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Inventory_Type = 'RMQTY_BATCH';

-- Verify consumption detail row count
SELECT COUNT(*) AS Consumption_Rows
FROM dbo.ETB2_Consumption_Detail_v1;

-- Verify no NULL Batch_IDs
SELECT COUNT(*) AS Null_Batch_IDs
FROM dbo.ETB2_Inventory_Unified_v1
WHERE Batch_ID IS NULL;

-- Verify release eligibility logic
SELECT 
  Inventory_Type,
  COUNT(*) AS Count,
  SUM(CASE WHEN Is_Eligible_For_Release = 1 THEN 1 ELSE 0 END) AS Eligible_Count
FROM dbo.ETB2_Inventory_Unified_v1
GROUP BY Inventory_Type;
```

---

## Rollback Plan

If issues are discovered:

1. **Immediate**: Revert downstream views to reference legacy views (05, 06, 12, 13)
2. **Short-term**: Keep legacy views active during validation period
3. **Long-term**: Archive legacy views after 30-day validation period

---

## Contact & Support

For questions or issues with the consolidated views:
- Review this migration guide
- Check ETB2_Config_Engine_v1 for configuration issues
- Validate data in source tables (Prosenthal_INV_BIN_QTY, IV00300, IV00102)
