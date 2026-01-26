# ETB2 Deployment Order - Dependency Reference

## Overview

All 17 objects are **views**. Deploy in numerical order to satisfy dependencies.

**Exception:** View 17 deploys between 13 and 14 (not at the end).

---

## Deployment Sequence

```
01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10 → 11 → 12 → 13 → 17 → 14 → 15 → 16
```

---

## Phase 1: Configuration Views (01-03)

### 01. ETB2_Config_Lead_Times
**Type:** View  
**Dependencies:** 
- dbo.IV00101 (Item master - external)

**Purpose:** 30-day lead time defaults per item

**Query Pattern:**
```sql
SELECT DISTINCT ITEMNMBR, 30 AS Lead_Time_Days
FROM dbo.IV00101
```

**Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Config_Lead_Times`

---

### 02. ETB2_Config_Part_Pooling
**Type:** View  
**Dependencies:**
- dbo.IV00101 (Item master - external)

**Purpose:** Pooling classification defaults (Dedicated = 1.4x multiplier)

**Query Pattern:**
```sql
SELECT DISTINCT 
    ITEMNMBR, 
    'Dedicated' AS Pooling_Classification,
    1.4 AS Pooling_Multiplier
FROM dbo.IV00101
```

**Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Config_Part_Pooling`

---

### 03. ETB2_Config_Active
**Type:** View  
**Dependencies:**
- ✓ ETB2_Config_Lead_Times (view 01)
- ✓ ETB2_Config_Part_Pooling (view 02)

**Purpose:** Unified config with COALESCE logic

**Query Pattern:**
```sql
SELECT 
    COALESCE(lt.ITEMNMBR, pp.ITEMNMBR) AS ITEMNMBR,
    COALESCE(lt.Lead_Time_Days, 30) AS Lead_Time_Days,
    COALESCE(pp.Pooling_Multiplier, 1.4) AS Pooling_Multiplier
FROM ETB2_Config_Lead_Times lt
FULL OUTER JOIN ETB2_Config_Part_Pooling pp ON lt.ITEMNMBR = pp.ITEMNMBR
```

**Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Config_Active`

---

## Phase 2: Data Foundation (04-06)

### 04. ETB2_Demand_Cleaned_Base
**Type:** View  
**Dependencies:**
- dbo.ETB_PAB_AUTO (demand data - external)
- dbo.Prosenthal_Vendor_Items (vendor mapping - external)

**Purpose:** Cleaned demand excluding partial/invalid orders

**Exclusions:**
- Order types 60.x, 70.x
- Partial receives
- Cancelled orders

**Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Demand_Cleaned_Base`

---

### 05. ETB2_Inventory_WC_Batches
**Type:** View  
**Dependencies:**
- dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (inventory - external)
- dbo.EXT_BINTYPE (bin types - external)

**Purpose:** Work center batches with FEFO, expiry calculation

**Pattern:** `LOCNCODE LIKE 'WC[_-]%'`

**Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Inventory_WC_Batches`

---

### 06. ETB2_Inventory_Quarantine_Restricted
**Type:** View  
**Dependencies:**
- dbo.IV00300 (receipts - external)
- dbo.IV00101 (item master - external)

**Purpose:** WFQ/RMQTY inventory with hold periods

**Hold Periods:**
- WFQ: 14 days
- RMQTY: 7 days

**Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Inventory_Quarantine_Restricted`

---

## Phase 3: Unified Inventory (07)

### 07. ETB2_Inventory_Unified_Eligible
**Type:** View  
**Dependencies:**
- ✓ ETB2_Inventory_WC_Batches (view 05)
- ✓ ETB2_Inventory_Quarantine_Restricted (view 06)
- External tables

**Purpose:** All eligible inventory (WC + released holds)

**Query Pattern:** UNION ALL of WC batches + released quarantine

**Validation:** `SELECT Source_Type, COUNT(*) FROM dbo.ETB2_Inventory_Unified_Eligible GROUP BY Source_Type`

---

## Phase 4: Planning Core (08-10)

### 08. ETB2_Planning_Stockout_Risk
**Type:** View  
**Dependencies:**
- ✓ ETB2_Demand_Cleaned_Base (view 04)
- ✓ ETB2_Inventory_WC_Batches (view 05)

**Purpose:** ATP balance, shortage risk classification

**Risk Levels:** CRITICAL, HIGH, MEDIUM, LOW

**Validation:** `SELECT Risk_Classification, COUNT(*) FROM dbo.ETB2_Planning_Stockout_Risk GROUP BY Risk_Classification`

---

### 09. ETB2_Planning_Net_Requirements
**Type:** View  
**Dependencies:**
- ✓ ETB2_Demand_Cleaned_Base (view 04)
- ✓ ETB2_Inventory_WC_Batches (view 05)
- ✓ ETB2_Config_Active (view 03)

**Purpose:** Procurement requirements calculation

**Method:** Net demand minus on-hand

**Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Planning_Net_Requirements WHERE Net_Requirement > 0`

---

### 10. ETB2_Planning_Rebalancing_Opportunities
**Type:** View  
**Dependencies:**
- ✓ ETB2_Demand_Cleaned_Base (view 04)
- ✓ ETB2_Inventory_WC_Batches (view 05)
- ✓ ETB2_Inventory_Quarantine_Restricted (view 06)

**Purpose:** Expiry-driven transfer recommendations

**Threshold:** Batches ≤90 days to expiry

**Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Planning_Rebalancing_Opportunities WHERE Days_To_Expiry < 90`

---

## Phase 5: Campaign Foundation (11-13)

### 11. ETB2_Campaign_Normalized_Demand
**Type:** View  
**Dependencies:**
- ✓ ETB2_Demand_Cleaned_Base (view 04)

**Purpose:** Campaign consumption units (CCU)

**CCU Formula:** Total item quantity per campaign

**Validation:** `SELECT TOP 10 * FROM dbo.ETB2_Campaign_Normalized_Demand ORDER BY CCU DESC`

---

### 12. ETB2_Campaign_Concurrency_Window
**Type:** View  
**Dependencies:**
- ✓ ETB2_Campaign_Normalized_Demand (view 11)
- ✓ ETB2_Config_Active (view 03)

**Purpose:** How many campaigns can overlap within lead time

**Default CCW:** 1 (conservative, due to missing campaign dates)

**Validation:** `SELECT AVG(CCW) FROM dbo.ETB2_Campaign_Concurrency_Window`

---

### 13. ETB2_Campaign_Collision_Buffer
**Type:** View  
**Dependencies:**
- ✓ ETB2_Campaign_Normalized_Demand (view 11)
- ✓ ETB2_Campaign_Concurrency_Window (view 12)
- ✓ ETB2_Config_Part_Pooling (view 02)

**Purpose:** Collision buffer quantity calculation

**Formula:** `collision_buffer_qty = CCU × CCW × pooling_multiplier`

**Validation:** `SELECT TOP 10 * FROM dbo.ETB2_Campaign_Collision_Buffer ORDER BY collision_buffer_qty DESC`

---

## Phase 5.5: Event Ledger (17) - DEPLOY HERE

### 17. ETB2_PAB_EventLedger_v1
**Type:** View (Complex UNION ALL)  
**Dependencies:**
- ✓ ETB2_Demand_Cleaned_Base (view 04)
- dbo.IV00102 (transactions - external)
- dbo.POP10100 (PO header - external)
- dbo.POP10110 (PO lines - external)
- dbo.POP10300 (PO receipts - external)

**Purpose:** Atomic event ledger for audit trail

**Event Types:**
- BEGIN_BAL
- PO_COMMITMENT
- PO_RECEIPT
- DEMAND
- EXPIRY

**Complexity:** HIGH - Multiple UNION ALL with CTEs

⚠️ **Deploy this AFTER view 13 but BEFORE view 14**

**Validation:** `SELECT Event_Type, COUNT(*) FROM dbo.ETB2_PAB_EventLedger_v1 GROUP BY Event_Type`

---

## Phase 6: Campaign Analytics (14-16)

### 14. ETB2_Campaign_Risk_Adequacy
**Type:** View  
**Dependencies:**
- ✓ ETB2_Inventory_Unified_Eligible (view 07)
- ✓ ETB2_PAB_EventLedger_v1 (view 17) ← **Requires EventLedger**
- ✓ ETB2_Demand_Cleaned_Base (view 04)
- ✓ ETB2_Campaign_Collision_Buffer (view 13)

**Purpose:** Inventory adequacy vs collision risk

**Risk Classifications:**
- LOW: Can absorb collision buffer
- MEDIUM: At threshold
- HIGH: Cannot absorb

**Validation:** `SELECT campaign_collision_risk, COUNT(*) FROM dbo.ETB2_Campaign_Risk_Adequacy GROUP BY campaign_collision_risk`

---

### 15. ETB2_Campaign_Absorption_Capacity
**Type:** View  
**Dependencies:**
- ✓ ETB2_Campaign_Collision_Buffer (view 13)
- ✓ ETB2_Campaign_Risk_Adequacy (view 14)
- ✓ ETB2_Config_Active (view 03)
- ✓ ETB2_Config_Part_Pooling (view 02)

**Purpose:** Executive KPI - campaigns absorbable

**Formula:** `absorbable_campaigns = (On-Hand + Inbound) ÷ CCU`

**Validation:** `SELECT AVG(absorbable_campaigns) FROM dbo.ETB2_Campaign_Absorption_Capacity`

---

### 16. ETB2_Campaign_Model_Data_Gaps
**Type:** View  
**Dependencies:**
- ✓ ETB2_Config_Active (view 03)
- ✓ ETB2_Config_Part_Pooling (view 02)

**Purpose:** Data quality flags and confidence levels

**Confidence:** All items = LOW (missing campaign structure data)

**Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Campaign_Model_Data_Gaps WHERE data_confidence = 'LOW'`

---

## Dependency Tree Visual

```
01 Config_Lead_Times (external only)
02 Config_Part_Pooling (external only)
03 Config_Active ← (01, 02)
04 Demand_Cleaned_Base (external only)
05 Inventory_WC_Batches (external only)
06 Inventory_Quarantine_Restricted (external only)
07 Inventory_Unified_Eligible ← (05, 06)
08 Planning_Stockout_Risk ← (04, 05)
09 Planning_Net_Requirements ← (04, 05)
10 Planning_Rebalancing_Opportunities ← (04, 05, 06)
11 Campaign_Normalized_Demand ← (04)
12 Campaign_Concurrency_Window ← (11, 03)
13 Campaign_Collision_Buffer ← (11, 12, 02)
17 PAB_EventLedger_v1 ← (04, external)  ⚠️ DEPLOY HERE
14 Campaign_Risk_Adequacy ← (07, 17, 04, 13)
15 Campaign_Absorption_Capacity ← (13, 14, 03, 02)
16 Campaign_Model_Data_Gaps ← (03, 02)
```

---

## External Tables Required

All 17 views depend on these external tables existing:

1. `dbo.ETB_PAB_AUTO` - Base demand data
2. `dbo.Prosenthal_Vendor_Items` - Vendor item mapping
3. `dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE` - Inventory quantities
4. `dbo.EXT_BINTYPE` - Bin type classifications
5. `dbo.IV00300` - Receipt data
6. `dbo.IV00101` - Item master
7. `dbo.IV00102` - Transaction history
8. `dbo.POP10100` - Purchase order headers
9. `dbo.POP10110` - Purchase order line items
10. `dbo.POP10300` - Purchase receipts

**Verify before deploying:**
```sql
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME IN (
    'ETB_PAB_AUTO', 'Prosenthal_Vendor_Items', 
    'Prosenthal_INV_BIN_QTY_wQTYTYPE', 'EXT_BINTYPE',
    'IV00300', 'IV00101', 'IV00102',
    'POP10100', 'POP10110', 'POP10300'
)
ORDER BY TABLE_NAME;
```
All 10 must exist.

---

## Visual Timeline

```
PHASE 1          PHASE 2        PHASE 3    PHASE 4       PHASE 5                  ⚠️      PHASE 6
Foundation       Data           Unified    Planning      Campaign          Event   Analytics
                 Foundation     Inventory  Analytics     Foundation         Ledger  (Final)

┌───┐
│ 01│
├───┤
│ 02│
├───┤
│ 03│
├───┤
│ 04│
├───┤
│ 05│
├───┤
│ 06│
├───┤
│ 07│
├───┤
│ 08│
├───┤
│ 09│
├───┤
│ 10│
├───┤
│ 11│
├───┤
│ 12│
├───┤
│ 13│
├───┤
│ 17│ ← DEPLOY HERE
├───┤
│ 14│
├───┤
│ 15│
├───┤
│ 16│ ← LAST
└───┘
```
