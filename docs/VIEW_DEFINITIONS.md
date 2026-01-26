# ETB2 View Definitions

This document provides detailed information about each view's purpose, columns, and formulas.

---

## Foundation Views (01-03)

### 01: ETB2_Config_Lead_Times (TABLE)

Stores lead time configuration per item with hierarchy support.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number or 'GLOBAL_DEFAULT' |
| Lead_Time_Days | INT | Lead time in days |
| Client | VARCHAR(50) | Client code or NULL for global |
| Created_Date | DATETIME | Record creation timestamp |

### 02: ETB2_Config_Part_Pooling (TABLE)

Stores pooling classification per item.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Pooling_Classification | VARCHAR(20) | 'Dedicated', 'Pooled', 'Mixed' |
| Client | VARCHAR(50) | Client code or NULL for global |
| Created_Date | DATETIME | Record creation timestamp |

### 03: ETB2_Config_Active (VIEW)

Multi-tier configuration with Item > Client > Global hierarchy.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Client | VARCHAR(50) | Client code or 'GLOBAL' |
| Lead_Time_Days | INT | Effective lead time |
| Pooling_Classification | VARCHAR(20) | Effective pooling classification |
| Config_Level | VARCHAR(10) | 'Item', 'Client', or 'Global' |

---

## Data Foundation Views (04-06)

### 04: ETB2_Demand_Cleaned_Base (VIEW)

Cleans and normalizes raw demand data from external tables.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Demand_Date | DATE | Date of demand |
| Quantity | DECIMAL(18,2) | Demand quantity |
| Source | VARCHAR(50) | Source system |
| Campaign_ID | VARCHAR(50) | Associated campaign |

### 05: ETB2_Inventory_WC_Batches (VIEW)

Work center inventory batches with FEFO (First Expired, First Out) ordering.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Work_Center | VARCHAR(50) | Work center code |
| Batch_Number | VARCHAR(50) | Batch identifier |
| Quantity | DECIMAL(18,2) | Available quantity |
| Expiry_Date | DATE | Batch expiration date |
| FEFO_Rank | INT | FEFO ordering rank |

### 06: ETB2_Inventory_Quarantine_Restricted (VIEW)

Identifies inventory in quarantine or with restrictions.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Location | VARCHAR(50) | Storage location |
| Quantity | DECIMAL(18,2) | Quarantined quantity |
| Restriction_Type | VARCHAR(50) | 'WFQ', 'RMQTY', 'HOLD' |
| Hold_Until | DATE | Release date if applicable |
| Reason_Code | VARCHAR(50) | Restriction reason |

---

## Unified Inventory View (07)

### 07: ETB2_Inventory_Unified_Eligible (VIEW)

Combines all eligible inventory sources into a single view.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Source_Type | VARCHAR(50) | 'WC_Batch', 'Quarantine', 'Restricted' |
| Available_Qty | DECIMAL(18,2) | Quantity available |
| Location | VARCHAR(50) | Storage location |
| Status | VARCHAR(20) | 'Eligible', 'Quarantine', 'Restricted' |

---

## Planning Views (08-10)

### 08: ETB2_Planning_Stockout_Risk (VIEW)

Calculates ATP (Available to Promise) and identifies shortage risks.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Current_Inventory | DECIMAL(18,2) | Available inventory |
| Projected_Demand | DECIMAL(18,2) | Future demand |
| ATP | DECIMAL(18,2) | Available to promise |
| Days_Coverage | INT | Days of inventory coverage |
| Risk_Classification | VARCHAR(20) | 'High', 'Medium', 'Low' |

### 09: ETB2_Planning_Net_Requirements (VIEW)

Calculates net procurement requirements.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Projected_Shortage | DECIMAL(18,2) | Forecasted shortage |
| Lead_Time_Adjustment | INT | Lead time days |
| Recommended_Order_Qty | DECIMAL(18,2) | Suggested order quantity |
| Net_Requirement_Quantity | DECIMAL(18,2) | Final requirement |
| Priority_Score | INT | Urgency ranking |

### 10: ETB2_Planning_Rebalancing_Opportunities (VIEW)

Identifies inventory transfer opportunities between locations.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Source_Location | VARCHAR(50) | Location with excess |
| Target_Location | VARCHAR(50) | Location with shortage |
| Transfer_Qty | DECIMAL(18,2) | Recommended transfer |
| Days_To_Expiry | INT | Days until expiration |
| Savings_Potential | DECIMAL(18,2) | Cost savings estimate |

---

## Campaign Foundation Views (11-13)

### 11: ETB2_Campaign_Normalized_Demand (VIEW)

Normalizes campaign consumption to standard units.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Campaign_ID | VARCHAR(50) | Campaign identifier |
| ITEMNMBR | VARCHAR(50) | Part number |
| Consumption_Pay | DECIMALer_D(18,4) | Daily consumption rate |
| campaign_consumption_unit | VARCHAR(20) | Normalized unit |
| Peak_Period_Start | DATE | Peak consumption start |
| Peak_Period_End | DATE | Peak consumption end |

### 12: ETB2_Campaign_Concurrency_Window (VIEW)

Calculates overlapping campaign windows.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Campaign_ID | VARCHAR(50) | Primary campaign |
| Overlapping_Campaign | VARCHAR(50) | Concurrent campaign |
| campaign_concurrency_window | DECIMAL(10,2) | Overlap duration (days) |
| Overlap_Start | DATE | Overlap start date |
| Overlap_End | DATE | Overlap end date |

### 13: ETB2_Campaign_Collision_Buffer (VIEW)

Calculates safety buffer quantities based on collision risk.

**Formula:** `collision_buffer_qty = CCU × CCW × Pooling_Multiplier`

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Campaign_ID | VARCHAR(50) | Campaign identifier |
| CCU | DECIMAL(18,4) | Campaign consumption unit |
| CCW | DECIMAL(10,2) | Concurrency window (days) |
| Pooling_Multiplier | DECIMAL(5,2) | From config table |
| collision_buffer_qty | DECIMAL(18,2) | Calculated buffer |

---

## Event Ledger View (17)

### 17: ETB2_PAB_EventLedger_v1 (VIEW)

Atomic event ledger combining all inventory movements.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| Event_ID | UNIQUEIDENTIFIER | Unique event identifier |
| Event_Type | VARCHAR(50) | 'Demand', 'Receipt', 'Transfer', 'Adjustment' |
| ITEMNMBR | VARCHAR(50) | Part number |
| Event_Date | DATETIME | Transaction date |
| Quantity | DECIMAL(18,2) | Movement quantity |
| Source_System | VARCHAR(50) | Origin system |
| Reference_ID | VARCHAR(100) | Source document reference |

---

## Campaign Analytics Views (14-16)

### 14: ETB2_Campaign_Risk_Adequacy (VIEW)

Assess collision risk against available inventory.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Campaign_ID | VARCHAR(50) | Campaign identifier |
| Available_Inventory | DECIMAL(18,2) | Total available |
| Required_Buffer | DECIMAL(18,2) | Collision buffer needed |
| campaign_collision_risk | VARCHAR(20) | 'High', 'Medium', 'Low' |
| Adequacy_Score | DECIMAL(5,2) | Risk adequacy ratio |

### 15: ETB2_Campaign_Absorption_Capacity (VIEW)

Executive KPI for maximum absorbable campaigns.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| absorbable_campaigns | INT | Max campaigns manageable |
| Total_Buffer_Required | DECIMAL(18,2) | Combined buffer needs |
| Utilization_Pct | DECIMAL(5,2) | Capacity utilization |
| Risk_Status | VARCHAR(20) | 'Green', 'Yellow', 'Red' |

### 16: ETB2_Campaign_Model_Data_Gaps (VIEW)

Identifies data quality issues in the model.

**Columns:**
| Column | Type | Description |
|--------|------|-------------|
| ITEMNMBR | VARCHAR(50) | Part number |
| Missing_Config | BIT | Lead time missing |
| Missing_Inventory | BIT | No inventory data |
| Missing_Demand | BIT | No demand history |
| data_confidence | VARCHAR(10) | 'HIGH', 'MEDIUM', 'LOW' |
| Gap_Description | VARCHAR(500) | Details of gaps |
