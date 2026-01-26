# ETB2 View Optimization & Documentation

**Generated:** 2026-01-26  
**Session ID:** ETB2-OPTIMIZATION-20260126  
**Status:** COMPLETE

---

## 1. Overview

This document consolidates all ETB2 views, supporting queries, configurations, and documentation into a single organized artifact. It includes:
- Decision table for each view (Keep/Merge/Delete)
- Numbered task graph with deployment order
- SQL snippets where relevant
- Audit trail for deleted/merged views

---

## 2. Assumptions

### 2.1 Data Quality Assumptions
- **Campaign Data:** All campaign-based views operate with LOW CONFIDENCE due to missing campaign structure (campaign IDs, start/end dates)
- **Lead Times:** Default to 30 days conservative estimate
- **Pooling Classification:** Default to Dedicated (most conservative)
- **Campaign Concurrency Window (CCW):** Default to 1 due to point-in-time date inference

### 2.2 Technical Assumptions
- **Database:** SQL Server (T-SQL syntax)
- **Grain Consistency:** Each view has explicit grain defined in comments
- **Naming Convention:** `ETB2_{Domain}_{Purpose}.sql` pattern enforced
- **Dependencies:** Views must be deployed in dependency order

### 2.3 Business Assumptions
- **Campaign-Based Risk Model:** Replaces daily-usage safety stock with campaign collision buffers
- **Pooling Effects:** Part sharing across campaigns changes risk dynamics
- **Lead Time Awareness:** Supplier constraints considered in risk calculation

---

## 3. Decision Table

| # | View Name | Purpose | Necessity | Complexity | Notes |
|---|-----------|---------|-----------|------------|-------|
| 1 | ETB2_Config_Active | Multi-tier config hierarchy (Item > Client > Global) | **KEEP** | Low | Self-contained, no external dependencies |
| 2 | ETB2_Demand_Cleaned_Base | Cleaned base demand (excludes 60.x/70.x, partials) | **KEEP** | Medium | Core dependency for all planning views |
| 3 | ETB2_Inventory_WC_Batches | WC batch inventory with FEFO ordering | **KEEP** | Medium | Base inventory layer |
| 4 | ETB2_Inventory_Quarantine_Restricted | WFQ/RMQTY with hold period management | **KEEP** | Medium | Source for unified eligible view |
| 5 | ETB2_Inventory_Unified_Eligible | All eligible inventory (WC + released holds) | **KEEP** | Medium | Planner primary for "what can I allocate?" |
| 6 | ETB2_Planning_Stockout_Risk | ATP balance and shortage risk analysis | **KEEP** | Medium | Risk assessment for planners |
| 7 | ETB2_Planning_Net_Requirements | Net procurement requirements calculation | **KEEP** | High | Core procurement planning logic |
| 8 | ETB2_Planning_Rebalancing_Opportunities | Expiry-driven inventory transfer recommendations | **KEEP** | High | Optimization opportunities |
| 9 | ETB2_Campaign_Normalized_Demand | Normalize demand into campaign units (CCU) | **KEEP** | Low | Campaign model foundation |
| 10 | ETB2_Campaign_Concurrency_Window | Determine campaign overlap within lead time | **KEEP** | Low | CCW defaults to 1 (conservative) |
| 11 | ETB2_Campaign_Collision_Buffer | Calculate collision buffer (replaces safety stock) | **KEEP** | Medium | Formula: CCU × CCW × pooling_multiplier |
| 12 | ETB2_Campaign_Risk_Adequacy | Assess inventory adequacy against collision risk | **KEEP** | Medium | Risk levels: LOW/MED/HIGH |
| 13 | ETB2_Campaign_Absorption_Capacity | Executive KPI: absorbable campaigns | **KEEP** | Medium | Primary capacity metric |
| 14 | ETB2_Campaign_Model_Data_Gaps | Flag missing/inferred data in campaign model | **KEEP** | Low | Data quality transparency |
| 15 | ETB2_Config_Lead_Times | Lead time configuration table | **KEEP** | Low | Config table, populates on first run |
| 16 | ETB2_Config_Part_Pooling | Part pooling classification table | **KEEP** | Low | Config table, populates on first run |
| 17 | ETB2_Classical_Benchmark_Metrics | Classical metrics for comparison only | **DELETE** | Low | All NULL values, no practical use |
| 18 | ETB2_PAB_EventLedger_v1 | Event ledger (BEGIN_BAL, PO, DEMAND, EXPIRY) | **KEEP** | High | Complex but necessary for event tracking |

### 3.1 Summary

| Category | Count |
|----------|-------|
| **KEEP** | 17 views |
| **DELETE** | 1 view (ETB2_Classical_Benchmark_Metrics) |
| **MERGE** | 0 views (none identified for merging) |

---

## 4. Deleted Views Audit Trail

| View Name | Deleted Date | Reason | Replaced By |
|-----------|--------------|--------|-------------|
| ETB2_Classical_Benchmark_Metrics | 2026-01-26 | All values NULL; provides no practical value. Classical metrics rejected in favor of campaign collision model. | N/A - Not needed |

---

## 5. SQL & Deployment Task Graph

### 5.1 Deployment Order (Numbered by Dependency)

| Order | View Name | Dependencies | Type |
|-------|-----------|--------------|------|
| 1 | `ETB2_Config_Lead_Times.sql` | None (table) | Table |
| 2 | `ETB2_Config_Part_Pooling.sql` | None (table) | Table |
| 3 | `ETB2_Config_Active.sql` | None | View |
| 4 | `ETB2_Demand_Cleaned_Base.sql` | dbo.ETB_PAB_AUTO, Prosenthal_Vendor_Items | View |
| 5 | `ETB2_Inventory_WC_Batches.sql` | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.EXT_BINTYPE | View |
| 6 | `ETB2_Inventory_Quarantine_Restricted.sql` | dbo.IV00300, dbo.IV00101 | View |
| 7 | `ETB2_Inventory_Unified_Eligible.sql` | Views 5, 6 + external tables | View |
| 8 | `ETB2_Planning_Stockout_Risk.sql` | Views 4, 5 | View |
| 9 | `ETB2_Planning_Net_Requirements.sql` | Views 4, 5 | View |
| 10 | `ETB2_Planning_Rebalancing_Opportunities.sql` | Views 4, 5, 6 | View |
| 11 | `ETB2_Campaign_Normalized_Demand.sql` | View 4 | View |
| 12 | `ETB2_Campaign_Concurrency_Window.sql` | Views 11, 1 | View |
| 13 | `ETB2_Campaign_Collision_Buffer.sql` | Views 11, 12, 2 | View |
| 14 | `ETB2_Campaign_Risk_Adequacy.sql` | Views 7, EventLedger, 4, 13 | View |
| 15 | `ETB2_Campaign_Absorption_Capacity.sql` | Views 13, 14, 1, 2 | View |
| 16 | `ETB2_Campaign_Model_Data_Gaps.sql` | Views 1, 2 | View |
| 17 | `ETB2_PAB_EventLedger_v1.sql` | View 4, IV00102, POP10100, POP10110, POP10300 | View |

### 5.2 SQL Syntax Verification Instructions

To verify correctness in SSMS:

```sql
-- 1. Test each view individually
SELECT TOP 10 * FROM dbo.ETB2_Config_Active;
SELECT TOP 10 * FROM dbo.ETB2_Demand_Cleaned_Base;
-- Continue for each view in deployment order...

-- 2. Check for dependencies
SELECT
    v.name AS ViewName,
    OBJECT_NAME(v.object_id) AS ObjectID,
    CASE WHEN ISNULL(p.name, 'N/A') = 'N/A' THEN 'Self-Contained' ELSE p.name END AS Dependency
FROM sys.views v
LEFT JOIN sys.sql_expression_dependencies d ON v.object_id = d.referenced_id
LEFT JOIN sys.views p ON d.referenced_id = p.object_id
WHERE v.name LIKE 'ETB2_%'
ORDER BY v.name;

-- 3. Verify row counts
SELECT 
    'ETB2_Demand_Cleaned_Base' AS ViewName,
    COUNT(*) AS RowCount
FROM dbo.ETB2_Demand_Cleaned_Base
UNION ALL
SELECT 'ETB2_Inventory_Unified_Eligible', COUNT(*) FROM dbo.ETB2_Inventory_Unified_Eligible
UNION ALL
SELECT 'ETB2_Planning_Stockout_Risk', COUNT(*) FROM dbo.ETB2_Planning_Stockout_Risk;
```

---

## 6. Optimized View List

### 6.1 Configuration Layer

#### `ETB2_Config_Active.sql`
- **Purpose:** Multi-tier configuration hierarchy (Item > Client > Global)
- **Grain:** Item / Client / Site
- **Dependencies:** None (self-contained)
- **Complexity:** Low
- **Excel-Ready:** Yes

```sql
-- Core pattern (simplified)
CREATE OR ALTER VIEW dbo.ETB2_Config_Active AS
WITH GlobalConfig AS (
    SELECT Config_Key, Config_Value FROM (VALUES
        ('WFQ_Hold_Days', '14'),
        ('RMQTY_Hold_Days', '7'),
        ('Safety_Stock_Days', '14')
    ) AS g(Config_Key, Config_Value)
)
SELECT ...
```

#### `ETB2_Config_Lead_Times.sql`
- **Purpose:** Lead time configuration table
- **Grain:** Item
- **Dependencies:** None (table with auto-populate)
- **Complexity:** Low

#### `ETB2_Config_Part_Pooling.sql`
- **Purpose:** Part pooling classification table
- **Grain:** Item
- **Dependencies:** None (table with auto-populate)
- **Complexity:** Low

### 6.2 Demand Layer

#### `ETB2_Demand_Cleaned_Base.sql`
- **Purpose:** Cleaned base demand excluding partial/invalid orders
- **Grain:** Order Line
- **Exclusions:** 60.x/70.x order types, partial receives
- **Priority:** Remaining > Deductions > Expiry
- **Dependencies:** dbo.ETB_PAB_AUTO, Prosenthal_Vendor_Items

### 6.3 Inventory Layer

#### `ETB2_Inventory_WC_Batches.sql`
- **Purpose:** Work Center batch inventory with FEFO ordering
- **Grain:** WC Batch
- **Site Pattern:** `LOCNCODE LIKE 'WC[_-]%'`
- **Eligibility:** Always eligible (no hold)
- **Dependencies:** dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.EXT_BINTYPE

#### `ETB2_Inventory_Quarantine_Restricted.sql`
- **Purpose:** WFQ/RMQTY inventory with hold period management
- **Grain:** Receipt Sequence (RCTSEQNM)
- **Hold Periods:** WFQ 14 days, RMQTY 7 days
- **Dependencies:** dbo.IV00300, dbo.IV00101

#### `ETB2_Inventory_Unified_Eligible.sql`
- **Purpose:** All eligible inventory consolidated (WC + released holds)
- **Grain:** Eligible Batch
- **Priority:** WC first, then by expiry
- **Dependencies:** Views 5, 6 + external tables

### 6.4 Planning Layer

#### `ETB2_Planning_Stockout_Risk.sql`
- **Purpose:** ATP balance and shortage risk analysis
- **Grain:** Item
- **Risk Levels:** CRITICAL, HIGH, MEDIUM, LOW
- **Dependencies:** Views 4, 5

#### `ETB2_Planning_Net_Requirements.sql`
- **Purpose:** Net procurement requirements calculation
- **Grain:** Item
- **Method:** DAYS_OF_SUPPLY
- **Dependencies:** Views 4, 5

#### `ETB2_Planning_Rebalancing_Opportunities.sql`
- **Purpose:** Expiry-driven inventory transfer recommendations
- **Grain:** Batch-to-Item Opportunity
- **Threshold:** Batches <=90 days to expiry
- **Dependencies:** Views 4, 5, 6

### 6.5 Campaign Model Layer

#### `ETB2_Campaign_Normalized_Demand.sql`
- **Purpose:** Normalize demand into campaign execution units
- **Grain:** Campaign
- **CCU:** Total item quantity per campaign
- **Confidence:** LOW (dates inferred as points)

#### `ETB2_Campaign_Concurrency_Window.sql`
- **Purpose:** Determine how many campaigns can overlap within lead time
- **Grain:** Item
- **CCW:** Default 1 (conservative)

#### `ETB2_Campaign_Collision_Buffer.sql`
- **Purpose:** Calculate collision buffer to replace safety stock
- **Grain:** Item
- **Formula:** `collision_buffer_qty = CCU × CCW × pooling_multiplier`
- **Poolings:** Pooled=0.6, Semi-Pooled=1.0, Dedicated=1.4

#### `ETB2_Campaign_Risk_Adequacy.sql`
- **Purpose:** Assess inventory adequacy against campaign collision risk
- **Grain:** Item
- **Risk Levels:** LOW (can absorb), MED (at threshold), HIGH (cannot)

#### `ETB2_Campaign_Absorption_Capacity.sql`
- **Purpose:** Executive KPI - how many campaigns can be absorbed
- **Grain:** Item
- **Formula:** `absorbable_campaigns = (On-Hand + Inbound) ÷ CCU`

#### `ETB2_Campaign_Model_Data_Gaps.sql`
- **Purpose:** Flag items with missing or inferred data
- **Grain:** Item
- **Confidence:** All items flagged (LOW CONFIDENCE)

### 6.6 Event Ledger

#### `ETB2_PAB_EventLedger_v1.sql`
- **Purpose:** Atomic event ledger
- **Grain:** Event
- **Event Types:** BEGIN_BAL, PO_COMMITMENT, PO_RECEIPT, DEMAND, EXPIRY
- **Complexity:** High

---

## 7. Metric Index

| Metric | Source View | Purpose |
|--------|-------------|---------|
| Base_Demand_Quantity | ETB2_Demand_Cleaned_Base | Core demand signal |
| Available_Quantity | ETB2_Inventory_Unified_Eligible | Allocatable stock |
| ATP_Balance | ETB2_Planning_Stockout_Risk | Coverage indicator |
| Net_Requirement_Quantity | ETB2_Planning_Net_Requirements | Procurement signal |
| Recommended_Transfer_Quantity | ETB2_Planning_Rebalancing_Opportunities | Optimization action |
| campaign_consumption_unit (CCU) | ETB2_Campaign_Normalized_Demand | Campaign sizing |
| collision_buffer_qty | ETB2_Campaign_Collision_Buffer | Risk buffer |
| absorbable_campaigns | ETB2_Campaign_Absorption_Capacity | Capacity KPI |
| campaign_collision_risk | ETB2_Campaign_Risk_Adequacy | Risk classification |

---

## 8. Planner Persona Workflow

### Daily Operations
1. **Risk Assessment:** Open `ETB2_Planning_Stockout_Risk`
2. **Requirements Review:** Open `ETB2_Planning_Net_Requirements`
3. **Transfer Recommendations:** Open `ETB2_Planning_Rebalancing_Opportunities`
4. **Inventory Check:** Open `ETB2_Inventory_Unified_Eligible`
5. **Demand Validation:** Open `ETB2_Demand_Cleaned_Base`

### Campaign Risk Review (Weekly/Executive)
1. **Absorption Capacity:** Open `ETB2_Campaign_Absorption_Capacity`
2. **Risk Adequacy:** Open `ETB2_Campaign_Risk_Adequacy`
3. **Data Quality:** Open `ETB2_Campaign_Model_Data_Gaps`

---

## 9. Migration History

### Phase 1: Initial ETB2 Architecture (2026-01-24)
- Established ETB2 as primary architecture
- Eliminated legacy rolyat views (07-15, 17-19)
- Maintained foundation views (00-06)

### Phase 2: Namespace Consolidation (2026-01-25)
- Consolidated all queries under ETB2_* prefix
- Retired query_t00X_* naming

### Phase 3: View Optimization (2026-01-26)
- Deleted ETB2_Classical_Benchmark_Metrics (all NULL)
- Standardized all view headers
- Created consolidated documentation

---

## 10. File Manifest

```
/views/
├── ETB2_Config_Active.sql
├── ETB2_Config_Lead_Times.sql
├── ETB2_Config_Part_Pooling.sql
├── ETB2_Demand_Cleaned_Base.sql
├── ETB2_Inventory_WC_Batches.sql
├── ETB2_Inventory_Quarantine_Restricted.sql
├── ETB2_Inventory_Unified_Eligible.sql
├── ETB2_Planning_Stockout_Risk.sql
├── ETB2_Planning_Net_Requirements.sql
├── ETB2_Planning_Rebalancing_Opportunities.sql
├── ETB2_Campaign_Normalized_Demand.sql
├── ETB2_Campaign_Concurrency_Window.sql
├── ETB2_Campaign_Collision_Buffer.sql
├── ETB2_Campaign_Risk_Adequacy.sql
├── ETB2_Campaign_Absorption_Capacity.sql
├── ETB2_Campaign_Model_Data_Gaps.sql
└── ETB2_PAB_EventLedger_v1.sql

/docs/
└── ETB2_Optimization.md (this file)
```

---

**END OF DOCUMENT**
