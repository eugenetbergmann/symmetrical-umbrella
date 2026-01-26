# ETB2 Deployment Order - STRICT SEQUENCE REQUIRED

## ⚠️ Why Order Matters

Each view depends on previous views. Deploying out of order causes "Invalid object name" errors.

---

## Corrected Deployment Sequence

```
01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10 → 11 → 12 → 13 → 17 → 14 → 15 → 16
```

**IMPORTANT:** File 17 (EventLedger) deploys BETWEEN files 13 and 14!

---

## Phase 1: Foundation (Files 01-03)

### File 01: Config_Lead_Times (TABLE)
- **Type:** Table creation
- **Dependencies:** None
- **Purpose:** Store lead time per item
- **Action:** Create table, run INSERT to populate defaults

### File 02: Config_Part_Pooling (TABLE)  
- **Type:** Table creation
- **Dependencies:** None
- **Purpose:** Store pooling classification per item
- **Action:** Create table, run INSERT to populate defaults

### File 03: Config_Active (VIEW)
- **Type:** View
- **Dependencies:** 
  - ✓ ETB2_Config_Lead_Times (from file 01)
  - ✓ ETB2_Config_Part_Pooling (from file 02)
- **Purpose:** Multi-tier config hierarchy
- **Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Config_Active` should return > 0

---

## Phase 2: Data Foundation (Files 04-06)

### File 04: Demand_Cleaned_Base (VIEW)
- **Dependencies:**
  - ✓ dbo.ETB_PAB_AUTO (external table)
  - ✓ dbo.Prosenthal_Vendor_Items (external table)
- **Purpose:** Cleaned base demand
- **Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Demand_Cleaned_Base`

### File 05: Inventory_WC_Batches (VIEW)
- **Dependencies:**
  - ✓ dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE (external)
  - ✓ dbo.EXT_BINTYPE (external)
- **Purpose:** Work center inventory with FEFO
- **Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Inventory_WC_Batches`

### File 06: Inventory_Quarantine_Restricted (VIEW)
- **Dependencies:**
  - ✓ dbo.IV00300 (external)
  - ✓ dbo.IV00101 (external)
- **Purpose:** WFQ/RMQTY with hold periods
- **Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Inventory_Quarantine_Restricted`

---

## Phase 3: Unified Inventory (File 07)

### File 07: Inventory_Unified_Eligible (VIEW)
- **Dependencies:**
  - ✓ ETB2_Inventory_WC_Batches (file 05)
  - ✓ ETB2_Inventory_Quarantine_Restricted (file 06)
  - ✓ External tables
- **Purpose:** All eligible inventory
- **Validation:** `SELECT Source_Type, COUNT(*) FROM dbo.ETB2_Inventory_Unified_Eligible GROUP BY Source_Type`

---

## Phase 4: Planning (Files 08-10)

### File 08: Planning_Stockout_Risk (VIEW)
- **Dependencies:**
  - ✓ ETB2_Demand_Cleaned_Base (file 04)
  - ✓ ETB2_Inventory_WC_Batches (file 05)
- **Purpose:** ATP and shortage risk
- **Validation:** `SELECT Risk_Classification, COUNT(*) FROM dbo.ETB2_Planning_Stockout_Risk GROUP BY Risk_Classification`

### File 09: Planning_Net_Requirements (VIEW)
- **Dependencies:**
  - ✓ ETB2_Demand_Cleaned_Base (file 04)
  - ✓ ETB2_Inventory_WC_Batches (file 05)
- **Purpose:** Procurement requirements
- **Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Planning_Net_Requirements WHERE Net_Requirement_Quantity > 0`

### File 10: Planning_Rebalancing_Opportunities (VIEW)
- **Dependencies:**
  - ✓ ETB2_Demand_Cleaned_Base (file 04)
  - ✓ ETB2_Inventory_WC_Batches (file 05)
  - ✓ ETB2_Inventory_Quarantine_Restricted (file 06)
- **Purpose:** Transfer recommendations
- **Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Planning_Rebalancing_Opportunities WHERE Days_To_Expiry <= 90`

---

## Phase 5: Campaign Foundation (Files 11-13)

### File 11: Campaign_Normalized_Demand (VIEW)
- **Dependencies:**
  - ✓ ETB2_Demand_Cleaned_Base (file 04)
- **Purpose:** Campaign consumption units
- **Validation:** `SELECT TOP 10 * FROM dbo.ETB2_Campaign_Normalized_Demand ORDER BY campaign_consumption_unit DESC`

### File 12: Campaign_Concurrency_Window (VIEW)
- **Dependencies:**
  - ✓ ETB2_Campaign_Normalized_Demand (file 11)
  - ✓ ETB2_Config_Active (file 03)
- **Purpose:** Campaign overlap calculation
- **Validation:** `SELECT AVG(campaign_concurrency_window) FROM dbo.ETB2_Campaign_Concurrency_Window`

### File 13: Campaign_Collision_Buffer (VIEW)
- **Dependencies:**
  - ✓ ETB2_Campaign_Normalized_Demand (file 11)
  - ✓ ETB2_Campaign_Concurrency_Window (file 12)
  - ✓ ETB2_Config_Part_Pooling (file 02)
- **Purpose:** Buffer quantity calculation
- **Formula:** CCU × CCW × Pooling Multiplier
- **Validation:** `SELECT TOP 10 * FROM dbo.ETB2_Campaign_Collision_Buffer ORDER BY collision_buffer_qty DESC`

---

## ⚠️ Phase 5.5: Event Ledger (File 17)

### File 17: PAB_EventLedger_v1 (VIEW)
- **Type:** Complex UNION ALL view
- **Dependencies:**
  - ✓ ETB2_Demand_Cleaned_Base (file 04)
  - ✓ dbo.IV00102 (external)
  - ✓ dbo.POP10100 (external)
  - ✓ dbo.POP10110 (external)
  - ✓ dbo.POP10300 (external)
- **Purpose:** Atomic event ledger
- **⚠️ DEPLOY AFTER FILE 13 BUT BEFORE FILE 14**
- **Validation:** `SELECT Event_Type, COUNT(*) FROM dbo.ETB2_PAB_EventLedger_v1 GROUP BY Event_Type`

---

## Phase 6: Campaign Analytics (Files 14-16)

### File 14: Campaign_Risk_Adequacy (VIEW)
- **Dependencies:**
  - ✓ ETB2_Inventory_Unified_Eligible (file 07)
  - ✓ ETB2_PAB_EventLedger_v1 (file 17 - **DEPLOYED**)
  - ✓ ETB2_Demand_Cleaned_Base (file 04)
  - ✓ ETB2_Campaign_Collision_Buffer (file 13)
- **Purpose:** Risk adequacy assessment
- **Validation:** `SELECT campaign_collision_risk, COUNT(*) FROM dbo.ETB2_Campaign_Risk_Adequacy GROUP BY campaign_collision_risk`

### File 15: Campaign_Absorption_Capacity (VIEW)
- **Dependencies:**
  - ✓ ETB2_Campaign_Collision_Buffer (file 13)
  - ✓ ETB2_Campaign_Risk_Adequacy (file 14)
  - ✓ ETB2_Config_Active (file 03)
  - ✓ ETB2_Config_Part_Pooling (file 02)
- **Purpose:** Executive capacity KPI
- **Validation:** `SELECT AVG(absorbable_campaigns) FROM dbo.ETB2_Campaign_Absorption_Capacity`

### File 16: Campaign_Model_Data_Gaps (VIEW)
- **Dependencies:**
  - ✓ ETB2_Config_Active (file 03)
  - ✓ ETB2_Config_Part_Pooling (file 02)
- **Purpose:** Data quality flags
- **Validation:** `SELECT COUNT(*) FROM dbo.ETB2_Campaign_Model_Data_Gaps WHERE data_confidence = 'LOW'`

---

## Quick Reference Dependency Tree

```
01 Config_Lead_Times (TABLE)
02 Config_Part_Pooling (TABLE)
03 Config_Active ← (01, 02)
04 Demand_Cleaned_Base ← (external tables)
05 Inventory_WC_Batches ← (external tables)
06 Inventory_Quarantine_Restricted ← (external tables)
07 Inventory_Unified_Eligible ← (05, 06)
08 Planning_Stockout_Risk ← (04, 05)
09 Planning_Net_Requirements ← (04, 05)
10 Planning_Rebalancing_Opportunities ← (04, 05, 06)
11 Campaign_Normalized_Demand ← (04)
12 Campaign_Concurrency_Window ← (11, 03)
13 Campaign_Collision_Buffer ← (11, 12, 02)
17 PAB_EventLedger_v1 ← (04, external tables) ⚠️ DEPLOY HERE
14 Campaign_Risk_Adequacy ← (07, 17, 04, 13)
15 Campaign_Absorption_Capacity ← (13, 14, 03, 02)
16 Campaign_Model_Data_Gaps ← (03, 02)
```

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
└───┘
```
