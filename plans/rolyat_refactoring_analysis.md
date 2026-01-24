# Rolyat Stock-Out Intelligence Pipeline - Comprehensive Refactoring Analysis

**Analysis Date:** 2026-01-24  
**Project:** Rolyat Stock-Out Intelligence Pipeline (SQL Server)  
**Version:** 2.0.0  
**Scope:** 17 SQL Server views + supporting infrastructure

---

## 1. REPOSITORY STRUCTURE ANALYSIS

### Directory Organization

```
workspace/
├── views/                          # 17 SQL view definitions (numbered 00-16)
│   ├── 00-03: Configuration views (4 views)
│   ├── 04-09: Core processing pipeline (6 views)
│   ├── 10-11: Analysis & rebalancing (2 views)
│   ├── 12-14: Reporting & consumption (3 views)
│   ├── 15-16: PO detail & event ledger (2 views)
│
├── tests/                          # Comprehensive test suite
│   ├── unit_tests.sql              # 25+ unit tests
│   ├── test_harness.sql            # Iterative test framework
│   ├── synthetic_data_generation.sql
│   ├── assertions.sql
│   └── README.md
│
├── validation/                     # Deployment validation
│   ├── 01_smoke_test.sql
│   ├── 02_data_quality_checks.sql
│   ├── 03_business_logic_validation.sql
│   ├── 04_config_coverage_test.sql
│   └── validation_results.md
│
├── docs/                           # Documentation
│   ├── CONFIG_GUIDE.md
│   ├── DEPLOYMENT_ORDER.md
│   ├── ETB2_PAB_EventLedger_v1_README.md
│   └── readout_state.md
│
├── reports/                        # Analysis reports
│   ├── dependency_scan.md
│   └── test_report.md
│
├── plans/                          # Planning documents
│   └── testing_plan.md
│
├── README.md                       # Main documentation
└── dbo.Rolyat_PO_Atomicity_Integrity_Test.sql
```

### File Naming Convention

**Pattern:** `[sequence]_dbo.[ViewName]_[version].sql`

- **Sequence:** 00-16 (execution/dependency order)
- **Schema:** `dbo.` (all views in default schema)
- **Naming:** PascalCase with underscores for logical grouping
- **Version:** Suffix (v1, v2, v3) indicates iteration/maturity
- **Prefixes:** `Rolyat_` (main pipeline), `ETB2_` (new event ledger)

---

## 2. VIEW INVENTORY & COMPLEXITY ASSESSMENT

### Complete View Catalog

| # | View Name | Purpose | LOC | Dependencies | Complexity | Similarity Score |
|---|-----------|---------|-----|--------------|------------|------------------|
| 00 | `Rolyat_Site_Config` | Site configuration (WFQ/RMQTY locations) | 32 | None | Low | 1/10 |
| 01 | `Rolyat_Config_Clients` | Client-specific config overrides | 23 | None | Low | 3/10 |
| 02 | `Rolyat_Config_Global` | System-wide default parameters | 42 | None | Low | 3/10 |
| 03 | `Rolyat_Config_Items` | Item-specific config overrides | 23 | None | Low | 3/10 |
| 04 | `Rolyat_Cleaned_Base_Demand_1` | Data cleansing & base demand calc | 162 | ETB_PAB_AUTO | **High** | 2/10 |
| 05 | `Rolyat_WC_Inventory` | WC batch inventory from bins | 124 | Config_Items, Config_Global | **High** | 4/10 |
| 06 | `Rolyat_WFQ_5` | WFQ/RMQTY inventory tracking | 185 | Site_Config, Config_Items, Config_Global | **Very High** | 5/10 |
| 07 | `Rolyat_Unit_Price_4` | Unit & extended price calculation | 57 | IV00300, IV00101 | Medium | 2/10 |
| 08 | `Rolyat_WC_Allocation_Effective_2` | WC allocation with FEFO logic | 155 | Cleaned_Base_Demand_1, WC_Inventory | **Very High** | 6/10 |
| 09 | `Rolyat_Final_Ledger_3` | Final ledger with running balances | 176 | WC_Allocation_Effective_2, PO_Detail, WFQ_5 | **Very High** | 7/10 |
| 10 | `Rolyat_StockOut_Analysis_v2` | Stock-out intelligence & action tags | 105 | Final_Ledger_3, WFQ_5 | **High** | 3/10 |
| 11 | `Rolyat_Rebalancing_Layer` | Rebalancing with timed hope sources | 206 | Final_Ledger_3, PO_Detail, WFQ_5 | **Very High** | 8/10 |
| 12 | `Rolyat_Consumption_Detail_v1` | Detailed consumption for analysis | 76 | Final_Ledger_3 | Medium | 9/10 |
| 13 | `Rolyat_Consumption_SSRS_v1` | SSRS-optimized reporting view | 54 | Final_Ledger_3 | Low | 9/10 |
| 14 | `Rolyat_Net_Requirements_v1` | Net requirements for MRP | 62 | Rebalancing_Layer, StockOut_Analysis_v2 | Medium | 2/10 |
| 15 | `Rolyat_PO_Detail` | PO details aggregated by item/site | 46 | ETB_PAB_AUTO | Low | 1/10 |
| 16 | `ETB2_PAB_EventLedger_v1` | Atomic event ledger (NEW) | 286 | ETB_PAB_AUTO, Cleaned_Base_Demand_1, IV00102, POP tables | **Very High** | 1/10 |

**Totals:**
- **Total Views:** 17
- **Total LOC:** ~1,834 lines
- **Average LOC per view:** 108 lines
- **High Complexity Views:** 8 (47%)
- **Very High Complexity Views:** 5 (29%)

---

## 3. BUSINESS LOGIC IDENTIFICATION

### Core Business Rules by Layer

#### **Configuration Layer (Views 00-03)**
- **Site Configuration:** Defines WFQ (quarantine) and RMQTY (restricted material) locations
- **Config Hierarchy:** Item > Client > Global (priority order)
- **Configurable Parameters:**
  - Degradation tiers (4 tiers: 0-30, 31-60, 61-90, >90 days)
  - Hold periods (WFQ: 14 days, RMQTY: 7 days)
  - Expiry filters (90 days default)
  - Active window (±21 days)
  - Safety stock (days of supply)

#### **Data Cleansing Layer (View 04)**
- **Exclusions:** Items 60.x, 70.x; Partially Received orders; Invalid dates
- **Base Demand Priority:** Remaining > Deductions > Expiry
- **SortPriority Logic:** BEG_BAL (1) > POs (2) > Demand (3) > Expiry (4)
- **Active Window:** ±21 days from current date (configurable)

#### **Inventory Tracking Layer (Views 05-06)**
- **WC Batches:** FEFO ordering (earliest expiry first)
- **Batch Expiry:** Explicit EXPNDATE or DATERECD + Shelf Life Days
- **WFQ/RMQTY:** Separate hold periods before release eligibility
- **Degradation:** Age-based factors (currently simplified to 1.0)

#### **Allocation & Ledger Layer (Views 08-09)**
- **WC Allocation:** Only within active window (IsActiveWindow = 1)
- **FEFO Matching:** Demand matched to earliest-expiry batches
- **Effective Demand:** Base_Demand - WC_Available (min 0)
- **Running Balances:**
  - **Forecast:** BEG_BAL + All POs + WFQ + RMQTY - Base_Demand (optimistic)
  - **ATP:** BEG_BAL + Released POs + RMQTY - Effective_Demand (conservative)
- **Stock-Out Flag:** Triggers when ATP balance < 0

#### **Analysis Layer (Views 10-11)**
- **Action Tags:** URGENT_PURCHASE (≥100) > URGENT_TRANSFER (≥50) > URGENT_EXPEDITE (<50)
- **Alternate Stock Awareness:** REVIEW_ALTERNATE_STOCK if WFQ/RMQTY available
- **Deficit Calculations:** ATP deficit vs Forecast deficit
- **Timed Hope Sources:** POs, WFQ, RMQTY within lead time window

#### **Reporting Layer (Views 12-14)**
- **Consumption Detail:** Full visibility into supply/demand events
- **SSRS Optimization:** Business-friendly column names
- **Net Requirements:** Gross demand - Available inventory

#### **Event Ledger Layer (View 16 - NEW)**
- **Atomic Events:** BEGIN_BAL, PO_COMMITMENT, PO_RECEIPT, DEMAND, EXPIRY
- **Includes 60.x/70.x:** In-process materials (NOT excluded)
- **MO De-duplication:** Multiple dates per MO → earliest date + summed qty
- **Running Balance:** Cumulative sum across all event types

### Shared Logic Patterns

1. **Configuration Lookups:** Repeated in Views 05, 06, 08 (Config_Items/Config_Global)
2. **Date Calculations:** Active window, hold periods, expiry filters (Views 04, 05, 06, 08)
3. **Aggregation Patterns:** SUM with CASE for supply/demand (Views 09, 11, 14)
4. **Window Functions:** ROW_NUMBER, SUM OVER for running balances (Views 08, 09, 11)
5. **FEFO Logic:** Batch ordering by expiry date (Views 05, 06, 08)

---

## 4. VIEW CONSOLIDATION OPPORTUNITIES

### Consolidation Target 1: Configuration Views (00-03) → Single `Config_Master`

**Current State:**
- 4 separate views with identical schema structure
- Repeated NULL casting and WHERE 1=0 patterns
- Separate lookups in downstream views

**Proposed Consolidation:**
```sql
-- Merge into: dbo.Rolyat_Config_Master
-- Union all config sources with priority ranking
-- Single lookup point for all downstream views
```

**Benefits:**
- **LOC Reduction:** 88 → 120 (net +32, but eliminates 3 views)
- **Maintenance:** Single config view instead of 4
- **Performance:** Consolidated lookup vs. 3 separate subqueries
- **Complexity:** Reduced from 4 Low views to 1 Medium view

**Challenges:**
- Requires updating 8 downstream views (05, 06, 08, 09, 11, 14)
- Config hierarchy logic must be explicit in single view

---

### Consolidation Target 2: Inventory Views (05-06) → `Inventory_Master`

**Current State:**
- `Rolyat_WC_Inventory` (124 LOC): WC batch tracking
- `Rolyat_WFQ_5` (185 LOC): WFQ + RMQTY with UNION ALL

**Proposed Consolidation:**
```sql
-- Merge into: dbo.Rolyat_Inventory_Master
-- Three inventory types: WC_BATCH, WFQ_BATCH, RMQTY_BATCH
-- Unified schema with Row_Type discriminator
-- Single source for all inventory lookups
```

**Benefits:**
- **LOC Reduction:** 309 → 280 (net -29 LOC, 9% reduction)
- **Maintenance:** Single inventory view vs. 2
- **Consistency:** Unified batch ID, expiry, age calculations
- **Performance:** Single join vs. multiple LEFT JOINs

**Challenges:**
- WC_Inventory uses different source tables (Prosenthal_INV_BIN_QTY vs. IV00300)
- Requires updating 5 downstream views (08, 09, 10, 11, 14)
- Different hold period logic (WC vs. WFQ vs. RMQTY)

---

### Consolidation Target 3: Reporting Views (12-13) → `Consumption_Unified`

**Current State:**
- `Rolyat_Consumption_Detail_v1` (76 LOC): Full detail
- `Rolyat_Consumption_SSRS_v1` (54 LOC): SSRS-optimized (9/10 similarity)

**Proposed Consolidation:**
```sql
-- Merge into: dbo.Rolyat_Consumption_Unified
-- Single view with all columns
-- Downstream reports select needed columns
-- Eliminates redundant view
```

**Benefits:**
- **LOC Reduction:** 130 → 76 (net -54 LOC, 42% reduction)
- **Maintenance:** Single view vs. 2 (identical source)
- **Flexibility:** Reports can select any columns needed
- **Simplicity:** No duplication

**Challenges:**
- Minimal - views are nearly identical
- May require report updates if they depend on specific column order

---

### Consolidation Target 4: Analysis Views (10-11) → `Analysis_Master`

**Current State:**
- `Rolyat_StockOut_Analysis_v2` (105 LOC): Stock-out intelligence
- `Rolyat_Rebalancing_Layer` (206 LOC): Rebalancing with timed hope

**Proposed Consolidation:**
```sql
-- Merge into: dbo.Rolyat_Analysis_Master
-- Combine stock-out detection + rebalancing logic
-- Single source for all downstream analysis
-- Eliminates View 14 dependency on both
```

**Benefits:**
- **LOC Reduction:** 311 → 280 (net -31 LOC, 10% reduction)
- **Maintenance:** Single analysis view vs. 2
- **Consistency:** Unified deficit calculations
- **Performance:** Single join vs. multiple

**Challenges:**
- High complexity increase (Very High → Extreme)
- Requires careful refactoring to preserve business logic
- View 14 (Net_Requirements) depends on both - must be updated

---

### Consolidation Target 5: Core Pipeline (04, 08-09) → `Pipeline_Core`

**Current State:**
- `Rolyat_Cleaned_Base_Demand_1` (162 LOC): Cleansing
- `Rolyat_WC_Allocation_Effective_2` (155 LOC): Allocation
- `Rolyat_Final_Ledger_3` (176 LOC): Final ledger

**Proposed Consolidation:**
```sql
-- Merge into: dbo.Rolyat_Pipeline_Core
-- Single view with all processing stages
-- Eliminates intermediate views
-- Reduces dependency chain
```

**Benefits:**
- **LOC Reduction:** 493 → 450 (net -43 LOC, 9% reduction)
- **Maintenance:** Single view vs. 3
- **Performance:** Eliminates 2 intermediate view joins
- **Clarity:** Single source of truth for core logic

**Challenges:**
- **HIGHEST RISK:** Very high complexity increase
- Difficult to debug and maintain
- Breaks existing downstream dependencies (Views 10, 11, 12, 13)
- Requires extensive testing

---

## 5. ETB2 RENAMING IMPACT ANALYSIS

### Current Naming Convention

**Rolyat Prefix Pattern:**
- `dbo.Rolyat_*` (16 views)
- Indicates "Rolyat" pipeline (stock-out intelligence)

**ETB2 Prefix Pattern:**
- `dbo.ETB2_PAB_EventLedger_v1` (1 view - NEW)
- Indicates "ETB2" event ledger (new atomic event system)

### Identifiers Requiring ETB2 Prefix

#### **View Names (if renaming entire pipeline):**
```
Current                              → Proposed ETB2 Name
dbo.Rolyat_Site_Config              → dbo.ETB2_Site_Config
dbo.Rolyat_Config_Clients           → dbo.ETB2_Config_Clients
dbo.Rolyat_Config_Global            → dbo.ETB2_Config_Global
dbo.Rolyat_Config_Items             → dbo.ETB2_Config_Items
dbo.Rolyat_Cleaned_Base_Demand_1    → dbo.ETB2_Cleaned_Base_Demand_1
dbo.Rolyat_WC_Inventory             → dbo.ETB2_WC_Inventory
dbo.Rolyat_WFQ_5                    → dbo.ETB2_WFQ_5
dbo.Rolyat_Unit_Price_4             → dbo.ETB2_Unit_Price_4
dbo.Rolyat_WC_Allocation_Effective_2 → dbo.ETB2_WC_Allocation_Effective_2
dbo.Rolyat_Final_Ledger_3           → dbo.ETB2_Final_Ledger_3
dbo.Rolyat_StockOut_Analysis_v2     → dbo.ETB2_StockOut_Analysis_v2
dbo.Rolyat_Rebalancing_Layer        → dbo.ETB2_Rebalancing_Layer
dbo.Rolyat_Consumption_Detail_v1    → dbo.ETB2_Consumption_Detail_v1
dbo.Rolyat_Consumption_SSRS_v1      → dbo.ETB2_Consumption_SSRS_v1
dbo.Rolyat_Net_Requirements_v1      → dbo.ETB2_Net_Requirements_v1
dbo.Rolyat_PO_Detail                → dbo.ETB2_PO_Detail
```

#### **Column Names (if renaming columns):**
- `Rolyat_Site_Config` → `ETB2_Site_Config` (in column aliases)
- `Rolyat_Config_*` → `ETB2_Config_*` (in column aliases)
- `Rolyat_WC_Inventory` → `ETB2_WC_Inventory` (in column aliases)
- `Rolyat_WFQ_5` → `ETB2_WFQ_5` (in column aliases)
- `Rolyat_Final_Ledger_3` → `ETB2_Final_Ledger_3` (in column aliases)
- `Rolyat_StockOut_Analysis_v2` → `ETB2_StockOut_Analysis_v2` (in column aliases)
- `Rolyat_Rebalancing_Layer` → `ETB2_Rebalancing_Layer` (in column aliases)

#### **Stored Procedures (if any):**
- `sp_run_unit_tests` → `sp_ETB2_run_unit_tests`
- `sp_run_test_iterations` → `sp_ETB2_run_test_iterations`
- `sp_quick_test` → `sp_ETB2_quick_test`
- `sp_generate_diagnostics` → `sp_ETB2_generate_diagnostics`

#### **Test References:**
- All test files reference view names (25+ unit tests)
- Diagnostic queries in view headers
- Test data generation scripts

### Renaming Scope Summary

| Category | Count | Impact |
|----------|-------|--------|
| View Names | 16 | High - All downstream references |
| Column Aliases | ~40 | Medium - Documentation strings |
| Stored Procedures | 4 | Medium - Test infrastructure |
| Test References | 25+ | High - All test files |
| Documentation | 8 | Low - README, guides, comments |
| **Total Identifiers** | **~93** | **High** |

### Breaking Changes & Migration Challenges

1. **Backward Compatibility:** Applications querying `dbo.Rolyat_*` will break
   - **Mitigation:** Create synonym views for 6-month transition period
   - **Cost:** 16 additional synonym views

2. **Test Suite:** All 25+ unit tests reference old view names
   - **Mitigation:** Automated find/replace in test files
   - **Cost:** Requires test re-execution and validation

3. **Deployment Scripts:** SQLCMD scripts in docs reference old names
   - **Mitigation:** Update DEPLOYMENT_ORDER.md and deployment scripts
   - **Cost:** Documentation updates

4. **Reporting Tools:** SSRS reports, Power BI, etc. may have hardcoded references
   - **Mitigation:** Coordinate with BI team before renaming
   - **Cost:** Unknown (depends on report count)

5. **Stored Procedures:** If any exist, they reference old view names
   - **Mitigation:** Update all stored procedure definitions
   - **Cost:** Requires testing

### Recommended Renaming Strategy

**Phase 1 (Immediate):**
- Rename `dbo.ETB2_PAB_EventLedger_v1` → `dbo.ETB2_EventLedger_v1` (shorter)
- Keep `Rolyat_*` views as-is for now

**Phase 2 (Optional - 6 months later):**
- Create synonym views: `dbo.Rolyat_*` → `dbo.ETB2_*`
- Update all internal references to `ETB2_*`
- Deprecate `Rolyat_*` synonyms after 6 months

**Phase 3 (Final):**
- Remove `Rolyat_*` synonyms
- Full migration to `ETB2_*` naming

---

## 6. CONSOLIDATION OPPORTUNITIES SUMMARY TABLE

| Target | Current Views | Proposed Name | LOC Change | Views Reduced | Complexity | Risk | Priority |
|--------|---------------|---------------|-----------|---------------|-----------|------|----------|
| **1** | 00-03 (Config) | `Config_Master` | +32 | 3 | Low→Med | Low | **HIGH** |
| **2** | 05-06 (Inventory) | `Inventory_Master` | -29 | 1 | High→High | Medium | **HIGH** |
| **3** | 12-13 (Reporting) | `Consumption_Unified` | -54 | 1 | Med→Med | Low | **MEDIUM** |
| **4** | 10-11 (Analysis) | `Analysis_Master` | -31 | 1 | High→VHigh | High | **MEDIUM** |
| **5** | 04,08-09 (Core) | `Pipeline_Core` | -43 | 2 | VHigh→Extreme | **CRITICAL** | **LOW** |

**Overall Impact:**
- **Total LOC Reduction:** -125 LOC (6.8% reduction)
- **Views Reduced:** 8 views (47% reduction)
- **Maintenance Burden:** Reduced by ~40%
- **Complexity:** Increased in core pipeline (trade-off)

---

## 7. DEPENDENCY MAPPING

### Dependency Chain (Critical Path)

```
ETB_PAB_AUTO (source table)
    ↓
Rolyat_Cleaned_Base_Demand_1 (View 04)
    ↓
Rolyat_WC_Allocation_Effective_2 (View 08)
    ↓
Rolyat_Final_Ledger_3 (View 09)
    ├→ Rolyat_StockOut_Analysis_v2 (View 10)
    ├→ Rolyat_Rebalancing_Layer (View 11)
    │   └→ Rolyat_Net_Requirements_v1 (View 14)
    ├→ Rolyat_Consumption_Detail_v1 (View 12)
    └→ Rolyat_Consumption_SSRS_v1 (View 13)
```

### Configuration Dependency (Horizontal)

```
Rolyat_Config_Global (View 02)
    ↓
Rolyat_Config_Clients (View 01)
    ↓
Rolyat_Config_Items (View 03)
    ↓
Used by: Views 05, 06, 08, 14
```

### Inventory Dependency (Horizontal)

```
Rolyat_Site_Config (View 00)
    ↓
Rolyat_WFQ_5 (View 06)
    ↓
Used by: Views 09, 10, 11, 14
```

---

## 8. NEXT STEPS: REFACTORING PLAN

### Phase 1: Low-Risk Consolidations (Weeks 1-2)

1. **Consolidate Reporting Views (12-13)**
   - Merge `Consumption_Detail_v1` + `Consumption_SSRS_v1` → `Consumption_Unified`
   - Update View 14 reference
   - Test: 2 unit tests
   - Risk: **LOW**

2. **Consolidate Configuration Views (00-03)**
   - Create `Config_Master` with priority hierarchy
   - Update Views 05, 06, 08, 09, 11, 14 references
   - Test: 5 unit tests
   - Risk: **LOW**

### Phase 2: Medium-Risk Consolidations (Weeks 3-4)

3. **Consolidate Inventory Views (05-06)**
   - Merge `WC_Inventory` + `WFQ_5` → `Inventory_Master`
   - Update Views 08, 09, 10, 11, 14 references
   - Test: 8 unit tests
   - Risk: **MEDIUM**

4. **Consolidate Analysis Views (10-11)**
   - Merge `StockOut_Analysis_v2` + `Rebalancing_Layer` → `Analysis_Master`
   - Update View 14 reference
   - Test: 6 unit tests
   - Risk: **MEDIUM**

### Phase 3: High-Risk Consolidations (Weeks 5-6)

5. **Consolidate Core Pipeline (04, 08-09)**
   - Merge `Cleaned_Base_Demand_1` + `WC_Allocation_Effective_2` + `Final_Ledger_3` → `Pipeline_Core`
   - Update Views 10, 11, 12, 13, 14 references
   - Test: 15+ unit tests
   - Risk: **CRITICAL** - Recommend deferring

### Phase 4: ETB2 Renaming (Week 7)

6. **Rename Views to ETB2 Prefix**
   - Create synonym views for backward compatibility
   - Update all test files
   - Update documentation
   - Test: Full regression test suite
   - Risk: **MEDIUM**

---

## 9. RECOMMENDATIONS

### Immediate Actions (High Priority)

1. ✅ **Consolidate Reporting Views (12-13)** - Quick win, low risk
2. ✅ **Consolidate Configuration Views (00-03)** - Improves maintainability
3. ✅ **Consolidate Inventory Views (05-06)** - Reduces duplication

### Deferred Actions (Lower Priority)

4. ⏸️ **Consolidate Analysis Views (10-11)** - Medium complexity increase
5. ❌ **Consolidate Core Pipeline (04, 08-09)** - Too risky, defer indefinitely

### Optional Actions (Strategic)

6. 🔄 **ETB2 Renaming** - Only if organizational rebranding required
7. 📊 **Create Synonym Views** - For backward compatibility during transition

### Estimated Effort

- **Phase 1 (Reporting + Config):** 3-4 days
- **Phase 2 (Inventory + Analysis):** 4-5 days
- **Phase 3 (Core Pipeline):** 7-10 days (NOT RECOMMENDED)
- **Phase 4 (ETB2 Renaming):** 2-3 days
- **Total (Phases 1-2, 4):** 9-12 days

---

## 10. RISK ASSESSMENT

### High-Risk Areas

1. **Core Pipeline Consolidation (View 04, 08-09)**
   - **Risk Level:** CRITICAL
   - **Reason:** Combines 493 LOC into single view; breaks 5 downstream views
   - **Recommendation:** DEFER indefinitely

2. **Configuration Consolidation (Views 00-03)**
   - **Risk Level:** LOW
   - **Reason:** Simple schema; 8 downstream references manageable
   - **Recommendation:** PROCEED with caution

3. **Inventory Consolidation (Views 05-06)**
   - **Risk Level:** MEDIUM
   - **Reason:** Different source tables; complex hold period logic
   - **Recommendation:** PROCEED with extensive testing

### Mitigation Strategies

1. **Comprehensive Testing:** Run full unit test suite after each consolidation
2. **Backward Compatibility:** Create synonym views for 6-month transition
3. **Staged Rollout:** Deploy to dev/test first; validate with business users
4. **Documentation:** Update all comments and dependency diagrams
5. **Rollback Plan:** Keep original views in version control; tag releases

---

## 11. DELIVERABLES CHECKLIST

- [x] Repository structure analysis
- [x] View inventory with complexity metrics
- [x] Business logic identification
- [x] Consolidation opportunities (5 targets)
- [x] ETB2 renaming impact analysis
- [x] Dependency mapping
- [x] Risk assessment
- [x] Refactoring plan with phases
- [x] Recommendations and priorities
- [ ] Implementation scripts (next phase)
- [ ] Updated test suite (next phase)
- [ ] Migration guide (next phase)

---

## APPENDIX: DETAILED CONSOLIDATION SPECIFICATIONS

### Consolidation 1: Config_Master

**Source Views:** 00, 01, 02, 03  
**Target View:** `dbo.ETB2_Config_Master` (or keep as `dbo.Rolyat_Config_Master`)

**Schema:**
```sql
Config_ID INT
Config_Type NVARCHAR(50)  -- 'SITE', 'CLIENT', 'ITEM', 'GLOBAL'
Config_Scope NVARCHAR(50) -- 'GLOBAL', 'CLIENT_ID', 'ITEMNMBR'
Scope_Value NVARCHAR(100) -- NULL for GLOBAL, Client_ID or ITEMNMBR for scoped
Config_Key NVARCHAR(100)
Config_Value NVARCHAR(100)
Data_Type NVARCHAR(20)
Description NVARCHAR(255)
Effective_Date DATETIME
Expiry_Date DATETIME
Created_Date DATETIME
Modified_Date DATETIME
Modified_By NVARCHAR(50)
Priority INT  -- 1=ITEM, 2=CLIENT, 3=GLOBAL (for hierarchy)
```

**Downstream Updates:**
- View 05: Replace 3 Config_Global lookups with single Config_Master lookup
- View 06: Replace 6 Config lookups with single Config_Master lookup
- View 08: Replace 2 Config lookups with single Config_Master lookup
- View 14: Replace 3 Config lookups with single Config_Master lookup

---

### Consolidation 2: Inventory_Master

**Source Views:** 05, 06  
**Target View:** `dbo.ETB2_Inventory_Master` (or keep as `dbo.Rolyat_Inventory_Master`)

**Schema:**
```sql
ITEMNMBR NVARCHAR(50)
Client_ID NVARCHAR(50)
Site_ID NVARCHAR(50)
Batch_ID NVARCHAR(100)
Inventory_Type NVARCHAR(20)  -- 'WC_BATCH', 'WFQ_BATCH', 'RMQTY_BATCH'
QTY_ON_HAND DECIMAL(18,5)
Receipt_Date DATE
Expiry_Date DATE
Projected_Release_Date DATE
Age_Days INT
Days_Until_Release INT
Is_Eligible_For_Release BIT
UOM NVARCHAR(20)
Bin_Location NVARCHAR(50)  -- NULL for WFQ/RMQTY
Bin_Type NVARCHAR(50)      -- NULL for WFQ/RMQTY
Row_Type NVARCHAR(20)
SortPriority INT
```

**Downstream Updates:**
- View 08: Replace WC_Inventory join with Inventory_Master join
- View 09: Replace WFQ_5 join with Inventory_Master join
- View 10: Replace WFQ_5 join with Inventory_Master join
- View 11: Replace WFQ_5 join with Inventory_Master join
- View 14: Replace Rebalancing_Layer reference

---

### Consolidation 3: Consumption_Unified

**Source Views:** 12, 13  
**Target View:** `dbo.ETB2_Consumption_Unified` (or keep as `dbo.Rolyat_Consumption_Unified`)

**Schema:** Union of both views' columns

**Downstream Updates:**
- Remove View 13 entirely
- Update any reports referencing View 13

---

### Consolidation 4: Analysis_Master

**Source Views:** 10, 11  
**Target View:** `dbo.ETB2_Analysis_Master` (or keep as `dbo.Rolyat_Analysis_Master`)

**Schema:** Union of both views' columns + combined logic

**Downstream Updates:**
- View 14: Replace both View 10 and View 11 references with Analysis_Master

---

## CONCLUSION

The Rolyat Stock-Out Intelligence Pipeline is well-structured with clear separation of concerns. Consolidation opportunities exist primarily in:

1. **Configuration layer** (low risk, high benefit)
2. **Reporting layer** (low risk, high benefit)
3. **Inventory layer** (medium risk, medium benefit)

The core pipeline (Views 04, 08-09) should NOT be consolidated due to extreme complexity and high risk of introducing bugs.

Recommended approach: Execute Phases 1-2 (9-12 days) for 6.8% LOC reduction and 47% view reduction, then reassess.

---

**Document Version:** 1.0  
**Last Updated:** 2026-01-24  
**Status:** Ready for Review
