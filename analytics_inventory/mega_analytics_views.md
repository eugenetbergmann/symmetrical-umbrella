# ETB2 Analytics Inventory: Comprehensive Standalone Query Documentation

**Generated:** 2026-01-25  
**Repository State:** Standalone Queries Migration Complete  
**Total Standalone Queries Documented:** 8 (Optimized, Excel-Ready, SELECT-Only)

---

## 1. Repository Context

### Purpose
This repository implements a unified supply chain planning and analytics system built on the **ETB2 (Enterprise Tactical Business 2)** architecture, now fully migrated to **standalone, dependency-free SELECT-only queries**.

The system consolidates demand planning, inventory management, allocation, and supply chain optimization into cohesive, planner-direct analytical outputs. All queries are:
- Fully self-contained (inline all logic via CTEs)
- SELECT-only (no views, tables, or hidden dependencies)
- Excel-ready (human-readable columns, meaningful ORDER BY)
- Immediately executable by planners without explanation

Legacy Rolyat-prefixed views and ETB2 views have been retired and replaced by these 8 atomic standalone queries.

### Analytics Domains Present
1. **Configuration Management** - Multi-tier config hierarchy (Item > Client > Global)
2. **Demand Planning** - Base demand calculation, demand cleansing
3. **Inventory Management** - WC, WFQ, RMQTY batches with eligibility and expiry
4. **Supply Chain Analysis** - ATP, stockout risk, net requirements
5. **Rebalancing & Optimization** - Expiry-driven inventory transfers, risk mitigation
6. **Reporting & Dashboards** - Planner-focused risk, requirements, and rebalancing lists

### Architecture Layers
- **Standalone Layer:** 8 self-contained SELECT queries replacing all prior foundation and core views
- **Deleted Legacy Views:** All prior Rolyat_* and ETB2_* views (18 total) consolidated into these 8 standalone outputs
- **Key Preservation:** Exact logic from critical Rolyat views (Cleaned_Base_Demand_1, WC_Inventory, WFQ_5) preserved in dedicated queries

---

## 2. Standalone Query Inventory

#### Query: `query_t001_unified-active-configuration.sql`
**Intended Persona:** System Administrator, Configuration Manager, All Planners  
**Grain:** Item / Client / Site  
**Metrics Produced:** All configuration parameters (hold days, shelf life, safety stock, degradation factors, etc.)  
**Notable Assumptions:** 
- Priority: Item > Client > Global
- Temporal validity applied
- Placeholders for future Client/Item overrides

#### Query: `query_t002_cleaned-base-demand.sql`
**Intended Persona:** Demand Planner, Supply Planner  
**Grain:** Order Line  
**Metrics Produced:** Base_Demand_Quantity, Demand_Priority_Type, Is_Within_Active_Planning_Window  
**Notable Assumptions:** Exact preservation of original Rolyat_Cleaned_Base_Demand_1 (excludes 60.x/70.x, partial receives, Remaining > Deductions > Expiry priority)

#### Query: `query_t003_wc-batch-inventory.sql`
**Intended Persona:** Inventory Manager, Allocation Planner  
**Grain:** WC Batch  
**Metrics Produced:** Available_Quantity, Batch_Age_Days, Days_Until_Expiry, FEFO_Sort_Priority  
**Notable Assumptions:** Exact preservation of original Rolyat_WC_Inventory (WC sites only, shelf life fallback 180 days, always eligible, no hold)

#### Query: `query_t004_quarantine-restricted-inventory.sql`
**Intended Persona:** Inventory Manager, QC Manager  
**Grain:** WFQ/RMQTY Batch (RCTSEQNM)  
**Metrics Produced:** Quantity_On_Hand, Age_Days, Days_Until_Release, Is_Eligible_For_Release  
**Notable Assumptions:** Exact preservation of original Rolyat_WFQ_5 (separate 14/7 day holds, 90-day expiry filter, eligibility flag)

#### Query: `query_t005_unified-batch-inventory.sql`
**Intended Persona:** Inventory Manager, Allocation Planner  
**Grain:** Eligible Batch (WC + releasable WFQ/RMQTY)  
**Metrics Produced:** Quantity_On_Hand, Days_Until_Expiry, Is_Eligible_For_Release, Allocation_Sort_Priority (WC first, then expiry)  
**Notable Assumptions:** Consolidated eligible stock; no expiry filter on WFQ/RMQTY (per ETB2 unification)

#### Query: `query_t006_stockout-risk-analysis.sql`
**Intended Persona:** Supply Planner, Demand Planner  
**Grain:** Item-Date (simplified to item-level in standalone)  
**Metrics Produced:** Total_Demand, Total_Allocated, ATP_Balance, Unmet_Demand, Available_Alternate_Quantity, Risk_Level, Recommended_Action  
**Notable Assumptions:** Simplified aggregate allocation (WC primary); alternate = eligible WFQ/RMQTY

#### Query: `query_t007_net-procurement-requirements.sql`
**Intended Persona:** Supply Planner, Procurement  
**Grain:** Item  
**Metrics Produced:** Net_Requirement_Quantity, Safety_Stock_Level, Days_Of_Supply, Requirement_Status, Requirement_Priority  
**Notable Assumptions:** DAYS_OF_SUPPLY method; cascading shortage + safety logic preserved

#### Query: `query_t008_expiry-driven-rebalancing-opportunities.sql`
**Intended Persona:** Supply Planner, Inventory Manager  
**Grain:** Batch-to-Item Opportunity  
**Metrics Produced:** Recommended_Transfer_Quantity, Transfer_Priority, Rebalancing_Type, Business_Impact  
**Notable Assumptions:** Matches expiring (<=90 days) eligible batches to unmet demand items; priority matrix preserved

---

## 3. Metric Index (Key Preserved Metrics)

- **Base_Demand_Quantity** → T-002
- **Quantity_On_Hand / Remaining_Quantity** → T-003, T-004, T-005, T-008
- **Days_Until_Expiry / Days_Until_Release** → T-003, T-004, T-005, T-008
- **Is_Eligible_For_Release** → T-004, T-005
- **ATP_Balance / Unmet_Demand** → T-006, T-007
- **Net_Requirement_Quantity** → T-007
- **Recommended_Transfer_Quantity** → T-008
- Configuration parameters → T-001

All original critical metrics preserved; extended values (pricing, financials) deferred for future standalone if needed.

---

## 4. Time & Calendar Logic Summary
Preserved exactly:
- Active window ±21 days (T-002)
- Hold periods: WFQ 14 days, RMQTY 7 days (T-004, T-005)
- Shelf life default 180 days (T-003, T-005)
- Expiry risk/rebalance thresholds 30/60/90 days (T-008)
- Degradation tiers configured but not applied (T-001)

---

## 5. Planner / Persona Notes
- **Daily Workflow:** Open T-006 (risk), T-007 (requirements), T-008 (rebalancing) in Excel
- **Inventory Checks:** T-003 (WC only), T-004 (held), T-005 (eligible total)
- **Demand Review:** T-002
- **Config Adjustments:** Edit VALUES in T-001

---

## 6. Known Gaps (Resolved in Standalone Migration)
- All prior view dependencies eliminated
- Degradation, backward suppression, client/item overrides remain placeholders (configurable in T-001)
- Per-date grain simplified in some queries for performance/standalone feasibility
- Pricing, PO detail, master financials deferred (add future standalone if needed)

---

## 7. Forensic Observations
- **Migration Complete:** 18 legacy views → 8 standalone queries (55% reduction)
- **Benefits:** Zero dependencies, direct Excel use, immediate deployability
- **Data Flow Simplified:** Config → Demand → Inventory → Risk → Requirements → Rebalancing

---

## 8. Summary Statistics

| Category                  | Count |
|---------------------------|-------|
| Total Standalone Queries  | 8     |
| Preserved Rolyat Logic    | 3     |
| Consolidated Outputs      | 5     |
| Configuration Parameters  | 16+   |
| Risk Classifications      | 3 types |
| Inventory Types           | 3     |

---

## 9. ETB2 Analytical Inventory (Authoritative)

**Updated:** 2026-01-26
**SESSION_ID:** ETB2-20260126030557-ABCD

| Object Name | Dependency Group | Upstream Dependencies | Downstream Consumers | Analytics Readiness Status |
|-------------|------------------|-----------------------|----------------------|-----------------------------|
| ETB2_Config_Active | ETB2_SELF_CONTAINED | None | All planning queries | READY |
| ETB2_Demand_Cleaned_Base | ETB2_EXTERNAL_DEPENDENCY | dbo.ETB_PAB_AUTO, Prosenthal_Vendor_Items | ETB2_Planning_Stockout_Risk, ETB2_Planning_Net_Requirements, ETB2_Planning_Rebalancing_Opportunities | READY |
| ETB2_Inventory_Quarantine_Restricted | ETB2_EXTERNAL_DEPENDENCY | dbo.IV00300, dbo.IV00101 | ETB2_Inventory_Unified_Eligible | READY |
| ETB2_Inventory_Unified_Eligible | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.EXT_BINTYPE, dbo.IV00300, dbo.IV00101 | ETB2_Planning_Stockout_Risk, ETB2_Planning_Rebalancing_Opportunities | READY |
| ETB2_Inventory_WC_Batches | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.EXT_BINTYPE | ETB2_Inventory_Unified_Eligible | READY |
| ETB2_Planning_Net_Requirements | ETB2_EXTERNAL_DEPENDENCY | dbo.ETB_PAB_AUTO | None | READY |
| ETB2_Planning_Rebalancing_Opportunities | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.IV00300 | None | READY |
| ETB2_Planning_Stockout_Risk | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE | None | READY |

---

## END OF CANONICAL STANDALONE QUERY DOCUMENTATION

**Document Purpose:** True canonical ledger of current repository state — all analytics now delivered via standalone SELECT-only queries.
**Intended Audience:** Architects, Planners, LLMs, Auditors
**Completeness:** Exhaustive snapshot post-migration
**Last Updated:** 2026-01-26
**Repository State:** ETB2 Validation & Analytics Update Complete
