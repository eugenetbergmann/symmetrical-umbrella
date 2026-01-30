# ETB2 Refactored Views: FG + Construct Carry-Through Summary

**Refactor Date:** 2026-01-30  
**Schema:** ETB2Refactored_views  
**Objective:** Materialize FG Item Number and Construct as explicit row-level columns using PAB-style derivation

---

## Executive Summary

All 14 views in the ETB2Refactored_views schema have been refactored to carry FG Item Number (FG) and Construct through the entire analytics pipeline. FG and Construct are now:

1. **Sourced from ETB_PAB_MO** (production/MO-side truth) - NOT from config tables
2. **Normalized using CleanOrder logic** (strip MO, hyphens, spaces, punctuation, uppercase)
3. **Deduplicated using ROW_NUMBER** partitioning by CleanOrder + FG
4. **Carried forward** through all downstream joins, windowing, and aggregation

---

## Views Changed

| View | FG/Construct Introduced | Notes |
|------|------------------------|-------|
| **04_ETB2_Demand_Cleaned_Base** | Base CTE via ETB_PAB_MO join | Foundation view - all downstream views inherit |
| **05_ETB2_Inventory_WC_Batches** | Via lot-to-order pattern matching | Links inventory lots to MO data |
| **06_ETB2_Inventory_Quarantine_Restricted** | Via lot-to-order pattern matching | WFQ/RMQTY inventory with FG linkage |
| **07_ETB2_Inventory_Unified** | Inherited from views 05, 06 | UNION ALL carries FG/Construct through |
| **08_ETB2_Planning_Net_Requirements** | Aggregated from view 04 | MAX() used to carry primary FG/Construct |
| **09_ETB2_Planning_Stockout** | Coalesced from views 07, 08 | FULL OUTER JOIN preserves FG/Construct |
| **10_ETB2_Planning_Rebalancing_Opportunities** | Coalesced from surplus/deficit CTEs | Transfer recommendations with FG context |
| **11_ETB2_Campaign_Normalized_Demand** | Aggregated from view 04 | Campaign-level FG/Construct assignment |
| **12_ETB2_Campaign_Concurrency_Window** | Inherited from view 11 | Overlapping campaigns carry FG/Construct |
| **13_ETB2_Campaign_Collision_Buffer** | Inherited from view 11 | Buffer calculations with FG context |
| **14_ETB2_Campaign_Risk_Adequacy** | Inherited from view 13 | Risk scoring with FG/Construct |
| **15_ETB2_Campaign_Absorption_Capacity** | Aggregated from view 14 | Executive KPIs with FG context |
| **16_ETB2_Campaign_Model_Data_Gaps** | Linked from view 04 | Data quality flags with FG/Construct |
| **17_ETB2_PAB_EventLedger_v1** | Via CleanOrder join to ETB_PAB_MO | Event ledger with FG for demand events |

---

## FG + Construct Derivation Pattern (PAB-Style)

### CleanOrder Normalization
```sql
UPPER(
    REPLACE(
        REPLACE(
            REPLACE(
                REPLACE(
                    REPLACE(
                        REPLACE(ORDERNUMBER, 'MO', ''),
                        '-', ''
                    ),
                    ' ', ''
                ),
                '/', ''
            ),
            '.', ''
        ),
        '#', ''
    )
) AS CleanOrder
```

### Deduplication Standard
```sql
ROW_NUMBER() OVER (
    PARTITION BY CleanOrder, FG
    ORDER BY Customer, [FG Desc], ORDERNUMBER
) AS FG_RowNum
-- Filter: WHERE FG_RowNum = 1
```

### Source Attribution
- **FG** derives from `ETB_PAB_MO.FG`
- **FG Desc** derives from `ETB_PAB_MO.[FG Desc]`
- **Construct** derives from `ETB_PAB_MO.Customer`

---

## Inline Comment Markers

All views include standardized inline comments:

```sql
-- FG SOURCE (PAB-style): [description of derivation]
-- Construct SOURCE (PAB-style): [description of derivation]
```

---

## Edge Cases Resolved

| Edge Case | Resolution |
|-----------|------------|
| Multiple FG rows per CleanOrder | ROW_NUMBER() selects rn=1 deterministically |
| Inventory lots without MO linkage | LEFT JOIN allows NULL FG/Construct |
| Campaign aggregation | MAX() selects primary FG per campaign |
| Full outer joins | COALESCE() preserves FG from either side |
| PO events in EventLedger | NULL FG/Construct (no MO linkage for POs) |
| Data gap analysis | Subquery linkage to demand base for FG |

---

## Validation Checks

### No Config Table References
- Verified: No references to config tables for FG or Construct derivation
- FG/Construct sourced exclusively from ETB_PAB_MO

### Row Count Stability
- Deduplication logic prevents inflation from FG joins
- ROW_NUMBER() filter ensures 1:1 cardinality per CleanOrder+FG

### Column Exposure
All views now expose these columns:
- `FG_Item_Number` (VARCHAR/NVARCHAR)
- `FG_Description` (VARCHAR/NVARCHAR)
- `Construct` (VARCHAR/NVARCHAR)

---

## Deployment Order

Views must be deployed in dependency order:

1. `04_ETB2_Demand_Cleaned_Base.sql` (Foundation)
2. `05_ETB2_Inventory_WC_Batches.sql`
3. `06_ETB2_Inventory_Quarantine_Restricted.sql`
4. `07_ETB2_Inventory_Unified.sql`
5. `08_ETB2_Planning_Net_Requirements.sql`
6. `09_ETB2_Planning_Stockout.sql`
7. `10_ETB2_Planning_Rebalancing_Opportunities.sql`
8. `11_ETB2_Campaign_Normalized_Demand.sql`
9. `12_ETB2_Campaign_Concurrency_Window.sql`
10. `13_ETB2_Campaign_Collision_Buffer.sql`
11. `17_ETB2_PAB_EventLedger_v1.sql`
12. `14_ETB2_Campaign_Risk_Adequacy.sql`
13. `15_ETB2_Campaign_Absorption_Capacity.sql`
14. `16_ETB2_Campaign_Model_Data_Gaps.sql`

---

## Files Modified

All files in `/refactored_views/` directory:
- `04_ETB2_Demand_Cleaned_Base.sql`
- `05_ETB2_Inventory_WC_Batches.sql`
- `06_ETB2_Inventory_Quarantine_Restricted.sql`
- `07_ETB2_Inventory_Unified.sql`
- `08_ETB2_Planning_Net_Requirements.sql`
- `09_ETB2_Planning_Stockout.sql`
- `10_ETB2_Planning_Rebalancing_Opportunities.sql`
- `11_ETB2_Campaign_Normalized_Demand.sql`
- `12_ETB2_Campaign_Concurrency_Window.sql`
- `13_ETB2_Campaign_Collision_Buffer.sql`
- `14_ETB2_Campaign_Risk_Adequacy.sql`
- `15_ETB2_Campaign_Absorption_Capacity.sql`
- `16_ETB2_Campaign_Model_Data_Gaps.sql`
- `17_ETB2_PAB_EventLedger_v1.sql`

---

## Post-Deployment Verification

```sql
-- Verify FG/Construct presence in all views
SELECT 
    'ETB2_Demand_Cleaned_Base' AS ViewName,
    COUNT(*) AS TotalRows,
    COUNT(FG_Item_Number) AS RowsWithFG,
    COUNT(Construct) AS RowsWithConstruct
FROM dbo.ETB2_Demand_Cleaned_Base
UNION ALL
SELECT 
    'ETB2_Inventory_WC_Batches',
    COUNT(*),
    COUNT(FG_Item_Number),
    COUNT(Construct)
FROM dbo.ETB2_Inventory_WC_Batches
-- ... repeat for all refactored views
```

---

**End of Summary**
