# ETB2 Complete Documentation

**Generated:** 2026-01-26  
**Session ID:** ETB2-OPTIMIZATION-20260126  
**Status:** COMPLETE

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Assumptions](#2-assumptions)
3. [Decision Table](#3-decision-table)
4. [Deleted Views Audit Trail](#4-deleted-views-audit-trail)
5. [Deployment Task Graph](#5-deployment-task-graph)
6. [Optimized View List](#6-optimized-view-list)
7. [Metric Index](#7-metric-index)
8. [Campaign Risk Model](#8-campaign-risk-model)
9. [Planner Workflow](#9-planner-workflow)
10. [Migration History](#10-migration-history)
11. [File Manifest](#11-file-manifest)
12. [Dependency Audit](#12-dependency-audit)

---

## 1. Executive Summary

ETB2 (Enterprise Tactical Business 2) is a unified supply chain planning and analytics system. This document consolidates all views, configurations, and documentation into a single organized artifact.

### Key Metrics

| Metric | Value |
|--------|-------|
| Total Views | 17 |
| Config Tables | 2 |
| Deleted Views | 1 |
| Migration Reduction | 55% (from 35 to 16 views) |

### Analytics Domains

1. **Configuration Management** - Multi-tier config hierarchy (Item > Client > Global)
2. **Demand Planning** - Base demand calculation, demand cleansing
3. **Inventory Management** - WC, WFQ, RMQTY batches with eligibility and expiry
4. **Supply Chain Analysis** - ATP, stockout risk, net requirements
5. **Rebalancing & Optimization** - Expiry-driven inventory transfers, risk mitigation
6. **Campaign Risk Model** - Campaign-based buffer calculations
7. **Reporting & Dashboards** - Planner-focused risk, requirements, and rebalancing

---

## 2. Assumptions

### 2.1 Data Quality Assumptions

| Assumption | Default | Notes |
|------------|---------|-------|
| Campaign Data | LOW CONFIDENCE | Missing campaign structure (IDs, dates) |
| Lead Times | 30 days | Conservative estimate for novel-modality CDMO |
| Pooling Classification | Dedicated | Most conservative classification |
| Campaign Concurrency Window (CCW) | 1 | Due to point-in-time date inference |
| WFQ Hold Period | 14 days | Quality hold before release |
| RMQTY Hold Period | 7 days | Raw material quality hold |
| WC Shelf Life | 180 days | Default if no expiry date |

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
| 1 | ETB2_Config_Active | Multi-tier config hierarchy | **KEEP** | Low | Self-contained, no external dependencies |
| 2 | ETB2_Demand_Cleaned_Base | Cleaned base demand | **KEEP** | Medium | Core dependency for all planning views |
| 3 | ETB2_Inventory_WC_Batches | WC batch inventory with FEFO | **KEEP** | Medium | Base inventory layer |
| 4 | ETB2_Inventory_Quarantine_Restricted | WFQ/RMQTY with holds | **KEEP** | Medium | Source for unified eligible view |
| 5 | ETB2_Inventory_Unified_Eligible | All eligible inventory | **KEEP** | Medium | Planner primary view |
| 6 | ETB2_Planning_Stockout_Risk | ATP & shortage analysis | **KEEP** | Medium | Risk assessment |
| 7 | ETB2_Planning_Net_Requirements | Procurement requirements | **KEEP** | High | Core procurement logic |
| 8 | ETB2_Planning_Rebalancing_Opportunities | Transfer recommendations | **KEEP** | High | Optimization |
| 9 | ETB2_Campaign_Normalized_Demand | Campaign units (CCU) | **KEEP** | Low | Campaign model foundation |
| 10 | ETB2_Campaign_Concurrency_Window | Campaign overlap | **KEEP** | Low | CCW defaults to 1 |
| 11 | ETB2_Campaign_Collision_Buffer | Collision buffer | **KEEP** | Medium | Formula: CCU × CCW × pooling |
| 12 | ETB2_Campaign_Risk_Adequacy | Risk adequacy | **KEEP** | Medium | Risk levels: LOW/MED/HIGH |
| 13 | ETB2_Campaign_Absorption_Capacity | Executive KPI | **KEEP** | Medium | Primary capacity metric |
| 14 | ETB2_Campaign_Model_Data_Gaps | Data quality flags | **KEEP** | Low | Data transparency |
| 15 | ETB2_Config_Lead_Times | Lead time config | **KEEP** | Low | Auto-populates |
| 16 | ETB2_Config_Part_Pooling | Pooling config | **KEEP** | Low | Auto-populates |
| 17 | ETB2_PAB_EventLedger_v1 | Event ledger | **KEEP** | High | Complex but necessary |
| 18 | ETB2_Classical_Benchmark_Metrics | Classical metrics | **DELETE** | Low | All NULL values |

### 3.1 Summary

| Category | Count |
|----------|-------|
| **KEEP** | 17 views |
| **DELETE** | 1 view |
| **MERGE** | 0 views |

---

## 4. Deleted Views Audit Trail

| View Name | Deleted Date | Reason | Replaced By |
|-----------|--------------|--------|-------------|
| ETB2_Classical_Benchmark_Metrics | 2026-01-26 | All values NULL; provides no practical value. Classical metrics rejected in favor of campaign collision model. | N/A |

### Rationale for Deletion

The classical metrics view contained:
- NULL for EOQ (continuous demand assumption invalid)
- NULL for Classical Safety Stock (Z-score approach rejected)
- NULL for Reorder Point (daily usage model rejected)

These metrics assume continuous demand patterns that don't apply to campaign-based CDMO operations. The campaign collision model provides the correct risk framework.

---

## 5. Deployment Task Graph

### 5.1 Deployment Order (Numbered by Dependency)

| Order | View Name | Dependencies | Type |
|-------|-----------|--------------|------|
| 1 | `ETB2_Config_Lead_Times.sql` | None (table) | Table |
| 2 | `ETB2_Config_Part_Pooling.sql` | None (table) | Table |
| 3 | `ETB2_Config_Active.sql` | None | View |
| 4 | `ETB2_Demand_Cleaned_Base.sql` | dbo.ETB_PAB_AUTO, Prosenthal_Vendor_Items | View |
| 5 | `ETB2_Inventory_WC_Batches.sql` | Prosenthal_INV_BIN_QTY_wQTYTYPE, EXT_BINTYPE | View |
| 6 | `ETB2_Inventory_Quarantine_Restricted.sql` | IV00300, IV00101 | View |
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

```sql
-- Test each view individually
SELECT TOP 10 * FROM dbo.ETB2_Config_Active;
SELECT TOP 10 * FROM dbo.ETB2_Demand_Cleaned_Base;

-- Check dependencies
SELECT v.name AS ViewName, p.name AS Dependency
FROM sys.views v
LEFT JOIN sys.sql_expression_dependencies d ON v.object_id = d.referenced_id
LEFT JOIN sys.views p ON d.referenced_id = p.object_id
WHERE v.name LIKE 'ETB2_%'
ORDER BY v.name;

-- Verify row counts
SELECT 'ETB2_Demand_Cleaned_Base' AS ViewName, COUNT(*) AS RowCount
FROM dbo.ETB2_Demand_Cleaned_Base
UNION ALL
SELECT 'ETB2_Inventory_Unified_Eligible', COUNT(*)
FROM dbo.ETB2_Inventory_Unified_Eligible;
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

#### `ETB2_Config_Lead_Times.sql`
- **Purpose:** Lead time configuration table
- **Grain:** Item
- **Defaults:** 30 days
- **Auto-populate:** Yes

#### `ETB2_Config_Part_Pooling.sql`
- **Purpose:** Part pooling classification table
- **Grain:** Item
- **Defaults:** Dedicated (1.4 multiplier)
- **Auto-populate:** Yes

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

## 8. Campaign Risk Model

### 8.1 Why Daily Usage Was Rejected

Traditional supply chain models assume continuous demand that can be averaged into "daily usage" rates. This doesn't apply here:

- **Novel-Modality CDMO Context:** Demand arrives in discrete campaigns, not continuous flows
- **Contracted Nature:** Orders are committed in advance for specific production runs
- **Non-Continuous Reality:** Extended periods of zero demand followed by sudden campaign spikes
- **False Precision:** Daily rates imply predictability that doesn't exist

### 8.2 Why Z-Scores Were Abandoned

Z-score safety stock assumes normally distributed demand variability. Campaign demand violates this:

- **Campaign Overlap Risk:** Relevant risk is how many campaigns might collide within a lead time window
- **Non-Normal Demand:** Campaign demand is lumpy and scheduled, not randomly distributed
- **Pooling Effects:** Part sharing changes risk dynamics in ways Z-scores can't capture

### 8.3 Why Campaign Collision Is the Correct Risk Unit

The campaign collision model directly addresses: "Do we have enough inventory for the maximum number of campaigns that could collide?"

**Key Concepts:**
- **CCU (Campaign Consumption Unit):** Total quantity needed per campaign for an item
- **CCW (Campaign Concurrency Window):** How many campaigns can overlap within lead time
- **Collision Buffer:** CCU × CCW × Pooling Multiplier
- **Absorbable Campaigns:** How many campaigns current inventory can support

---

## 9. Planner Workflow

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

## 10. Migration History

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

## 11. File Manifest

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
└── ETB2_Complete_Documentation.md (this file)

/analytics_inventory/
└── mega_analytics_views.md
```

---

## 12. Dependency Audit

### ETB2 Object Inventory

| Object Name | Dependency Group | External Dependencies | Analytics Readiness |
|-------------|------------------|----------------------|---------------------|
| ETB2_Config_Active | ETB2_SELF_CONTAINED | None | READY |
| ETB2_Demand_Cleaned_Base | ETB2_EXTERNAL_DEPENDENCY | dbo.ETB_PAB_AUTO, Prosenthal_Vendor_Items | READY |
| ETB2_Inventory_Quarantine_Restricted | ETB2_EXTERNAL_DEPENDENCY | dbo.IV00300, dbo.IV00101 | READY |
| ETB2_Inventory_Unified_Eligible | ETB2_EXTERNAL_DEPENDENCY | Prosenthal_INV_BIN_QTY_wQTYTYPE, EXT_BINTYPE, IV00300, IV00101 | READY |
| ETB2_Inventory_WC_Batches | ETB2_EXTERNAL_DEPENDENCY | Prosenthal_INV_BIN_QTY_wQTYTYPE, EXT_BINTYPE | READY |
| ETB2_Planning_Net_Requirements | ETB2_EXTERNAL_DEPENDENCY | dbo.ETB_PAB_AUTO | READY |
| ETB2_Planning_Rebalancing_Opportunities | ETB2_EXTERNAL_DEPENDENCY | Prosenthal_INV_BIN_QTY_wQTYTYPE, IV00300 | READY |
| ETB2_Planning_Stockout_Risk | ETB2_EXTERNAL_DEPENDENCY | Prosenthal_INV_BIN_QTY_wQTYTYPE | READY |

### External Dependency Validation Queue

The following objects require validation of external dependencies before production use:

1. ETB2_Demand_Cleaned_Base (dbo.ETB_PAB_AUTO, Prosenthal_Vendor_Items)
2. ETB2_Inventory_Quarantine_Restricted (dbo.IV00300, dbo.IV00101)
3. ETB2_Inventory_Unified_Eligible (Prosenthal_INV_BIN_QTY_wQTYTYPE, EXT_BINTYPE, IV00300, IV00101)
4. ETB2_Inventory_WC_Batches (Prosenthal_INV_BIN_QTY_wQTYTYPE, EXT_BINTYPE)
5. ETB2_Planning_Net_Requirements (dbo.ETB_PAB_AUTO)
6. ETB2_Planning_Rebalancing_Opportunities (Prosenthal_INV_BIN_QTY_wQTYTYPE, IV00300)
7. ETB2_Planning_Stockout_Risk (Prosenthal_INV_BIN_QTY_wQTYTYPE)

---

## END OF DOCUMENT

**Document Purpose:** Single authoritative source for all ETB2 views, configurations, and documentation  
**Intended Audience:** Architects, Planners, LLMs, Auditors  
**Completeness:** Complete snapshot post-optimization  
**Last Updated:** 2026-01-26
