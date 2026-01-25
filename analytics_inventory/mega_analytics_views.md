# ETB2 Analytics Inventory: Comprehensive View Documentation

**Generated:** 2026-01-25  
**Repository State:** ETB2 Architecture Migration Complete  
**Total Views Documented:** 18 (7 Foundation + 11 ETB2)

---

## 1. Repository Context

### Purpose
This repository implements a unified supply chain planning and analytics system built on the **ETB2 (Enterprise Tactical Business 2)** architecture. The system consolidates demand planning, inventory management, allocation, and supply chain optimization into a cohesive analytical framework.

### Analytics Domains Present
1. **Configuration Management** - Multi-tier config hierarchy (Item > Client > Global)
2. **Demand Planning** - Base demand calculation, demand cleansing, event sequencing
3. **Inventory Management** - WC (Work Center), WFQ (Quarantine), RMQTY (Restricted Material) batches
4. **Allocation Engine** - FEFO (First Expiry First Out) batch allocation against demand
5. **Supply Chain Analysis** - ATP (Available To Promise), stockout risk, net requirements
6. **Rebalancing & Optimization** - Expiry-driven inventory transfers, risk mitigation
7. **Reporting & Dashboards** - Executive, planner, and expiry-focused presentation layers

### Architecture Layers
- **Foundation Layer (Views 00-06):** Configuration and raw inventory data (Rolyat-prefixed)
- **ETB2 Core Layer:** Unified views implementing ETB2 consolidation strategy
- **Deleted Legacy Views (07-15, 17-19):** Consolidated into ETB2 equivalents

---

## 2. View Inventory

### FOUNDATION LAYER (Rolyat-Prefixed)

#### View: `dbo.Rolyat_Site_Config`
**File Path:** `views/00_dbo.Rolyat_Site_Config.sql`  
**Intended Persona:** System Administrator, Configuration Manager  
**Grain:** Site (Location Code)  
**Source Tables:** Static configuration (no external dependencies)  
**Metrics Produced:** None (configuration only)  
**Time Logic:** None (static)  
**Filters/Exclusions:** None  
**Notable Assumptions:**
- WF-Q location is hardcoded for WFQ inventory
- RMQTY location is hardcoded for restricted material inventory
- All sites are active by default (Active = 1)

**Open Questions/Ambiguity:**
- Are there other WFQ or RMQTY locations that should be added?
- Is the site configuration meant to be dynamic or truly static?

---

#### View: `dbo.Rolyat_Config_Clients`
**File Path:** `views/01_dbo.Rolyat_Config_Clients.sql`  
**Intended Persona:** Configuration Manager  
**Grain:** Client (Client_ID)  
**Source Tables:** None (empty schema definition)  
**Metrics Produced:** None (configuration only)  
**Time Logic:** Effective_Date, Expiry_Date (temporal validity)  
**Filters/Exclusions:** WHERE 1 = 0 (returns no rows - placeholder)  
**Notable Assumptions:**
- Client-specific overrides are intended but not yet populated
- Priority hierarchy: Item > Client > Global (Client is middle tier)
- Supports multiple config keys per client

**Open Questions/Ambiguity:**
- What client-specific overrides are planned?
- Is this view meant to be populated from external data source?

---

#### View: `dbo.Rolyat_Config_Global`
**File Path:** `views/02_dbo.Rolyat_Config_Global.sql`  
**Intended Persona:** System Administrator  
**Grain:** Configuration Key (Config_Key)  
**Source Tables:** Static VALUES clause  
**Metrics Produced:** None (configuration only)  
**Time Logic:** Effective_Date (1900-01-01 = always active), Expiry_Date (NULL = no expiry)  
**Filters/Exclusions:** None  
**Notable Assumptions:**
- Degradation tiers: Tier1 (0-30 days, 1.00 factor), Tier2 (31-60 days, 0.75), Tier3 (61-90 days, 0.50), Tier4 (>90 days, 0.00)
- WFQ hold period: 14 days before release eligibility
- RMQTY hold period: 7 days before release eligibility
- Active planning window: ±21 days from current date
- Safety stock method: DAYS_OF_SUPPLY (default)
- WC batch shelf life: 180 days (if no explicit expiry)

**Open Questions/Ambiguity:**
- Are degradation factors applied to inventory value or quantity?
- How is "Degradation_Tier4_Factor = 0.00" used (complete write-off)?
- What is the business logic for different hold periods (WFQ vs RMQTY)?

---

#### View: `dbo.Rolyat_Config_Items`
**File Path:** `views/03_dbo.Rolyat_Config_Items.sql`  
**Intended Persona:** Configuration Manager, Planner  
**Grain:** Item (ITEMNMBR)  
**Source Tables:** None (empty schema definition)  
**Metrics Produced:** None (configuration only)  
**Time Logic:** Effective_Date, Expiry_Date (temporal validity)  
**Filters/Exclusions:** WHERE 1 = 0 (returns no rows - placeholder)  
**Notable Assumptions:**
- Item-specific overrides have highest priority in config hierarchy
- Supports per-item customization of all global parameters
- Temporal validity allows time-based config changes

**Open Questions/Ambiguity:**
- What item-specific overrides are planned?
- Are there items that require different hold periods or shelf life?

---

#### View: `dbo.Rolyat_Cleaned_Base_Demand_1`
**File Path:** `views/04_dbo.Rolyat_Cleaned_Base_Demand_1.sql`  
**Intended Persona:** Demand Planner, Supply Planner  
**Grain:** Order Line (ORDERNUMBER + ITEMNMBR)  
**Source Tables:** `dbo.ETB_PAB_AUTO` (raw demand data)  
**Metrics Produced:**
- `Base_Demand` - Priority-based demand (Remaining > Deductions > Expiry)
- `SortPriority` - Event ordering (1=BEG_BAL, 2=POs, 3=Demand, 4=Expiry, 5=Other)
- `IsActiveWindow` - Flag for records within ±21 day planning window

**Time Logic:**
- DUEDATE: Order due date (converted to DATE type)
- Date_Expiry, Expiry_Dates: Expiry dates (converted to DATE type)
- MRP_IssueDate: MRP issue date
- Active window: DUEDATE BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())

**Filters/Exclusions:**
- Excludes items with prefixes 60.x and 70.x (IN-PROCESS MATERIALS - excluded here, included in ETB2_PAB_EventLedger)
- Excludes partially received orders (STSDESCR <> 'Partially Received')
- Excludes records with invalid dates (TRY_CONVERT(DATE, [Date + Expiry]) IS NOT NULL)

**Notable Assumptions:**
- Base_Demand priority: Remaining (highest) > Deductions > Expiry (lowest)
- CleanOrder removes special characters (MO, -, /, ., #) for standardization
- Quantity fields default to 0.0 if NULL or conversion fails
- SortPriority is deterministic for event ordering in downstream views

**Open Questions/Ambiguity:**
- Why are 60.x and 70.x items excluded here but included in ETB2_PAB_EventLedger?
- What is the business logic for Base_Demand priority (why Remaining > Deductions)?
- Are there other item prefixes that should be excluded?
- How is "Partially Received" status determined upstream?

---

#### View: `dbo.Rolyat_WC_Inventory`
**File Path:** `views/05_dbo.Rolyat_WC_Inventory.sql`  
**Intended Persona:** Inventory Manager, Allocation Planner  
**Grain:** WC Batch (LOT_Number + Bin)  
**Source Tables:**
- `dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE` (bin quantities)
- `dbo.EXT_BINTYPE` (bin type information)
- `dbo.Rolyat_Config_Items` (item-specific config)
- `dbo.Rolyat_Config_Global` (global config)

**Metrics Produced:**
- `Available_Qty` - QTY_Available from bin
- `Batch_Age_Days` - DATEDIFF(DAY, DATERECD, GETDATE())
- `SortPriority` - ROW_NUMBER() OVER (PARTITION BY ITEMNMBR ORDER BY Batch_Expiry_Date ASC, Batch_Receipt_Date ASC) - FEFO ordering

**Time Logic:**
- Batch_Receipt_Date: DATERECD (receipt date)
- Batch_Expiry_Date: COALESCE(EXPNDATE, DATEADD(DAY, Shelf_Life_Days, DATERECD))
  - If explicit expiry exists, use it
  - Otherwise, receipt date + configurable shelf life (default 180 days)

**Filters/Exclusions:**
- Only includes records with SITE LIKE 'WC[_-]%' (Work Center sites only)
- Only includes records with QTY_Available > 0
- Only includes records with valid LOT_Number (NOT NULL and <> '')

**Notable Assumptions:**
- Client_ID extracted from SITE before first '-' or '_' delimiter
- WC batches are always eligible for allocation (no hold period)
- Degradation not yet implemented (Degraded_Qty = 0, Usable_Qty = Available_Qty)
- Bin type information is optional (ISNULL to 'UNKNOWN')

**Open Questions/Ambiguity:**
- How is Client_ID extraction used downstream?
- When will degradation logic be implemented?
- Are there WC sites with prefixes other than 'WC[_-]%'?
- What is the business logic for shelf life configuration (item vs global)?

---

#### View: `dbo.Rolyat_WFQ_5`
**File Path:** `views/06_dbo.Rolyat_WFQ_5.sql`  
**Intended Persona:** Inventory Manager, QC Manager  
**Grain:** WFQ/RMQTY Batch (RCTSEQNM)  
**Source Tables:**
- `dbo.IV00300` (Inventory Lot Master)
- `dbo.IV00101` (Item Master)
- `dbo.Rolyat_Site_Config` (site configuration)
- `dbo.Rolyat_Config_Items` (item-specific config)
- `dbo.Rolyat_Config_Global` (global config)

**Metrics Produced:**
- `QTY_ON_HAND` - SUM(QTYRECVD - QTYSOLD)
- `Age_Days` - DATEDIFF(DAY, Receipt_Date, GETDATE())
- `Days_Until_Release` - DATEDIFF(DAY, GETDATE(), Projected_Release_Date)
- `Is_Eligible_For_Release` - Flag (1 if hold period elapsed, 0 otherwise)

**Time Logic:**
- Receipt_Date: MAX(CAST(DATERECD AS DATE))
- Expiry_Date: MAX(CAST(EXPNDATE AS DATE))
- Projected_Release_Date: DATEADD(DAY, Hold_Days, Receipt_Date)
  - WFQ: Hold_Days from config (default 14 days)
  - RMQTY: Hold_Days from config (default 7 days)
- Expiry filter: EXPNDATE > DATEADD(DAY, Expiry_Filter_Days, GETDATE())
  - WFQ: Expiry_Filter_Days from config (default 90 days)
  - RMQTY: Expiry_Filter_Days from config (default 90 days)

**Filters/Exclusions:**
- WFQ section: LOCNCODE IN (SELECT LOCNCODE FROM Rolyat_Site_Config WHERE Site_Type = 'WFQ' AND Active = 1)
- RMQTY section: LOCNCODE IN (SELECT LOCNCODE FROM Rolyat_Site_Config WHERE Site_Type = 'RMQTY' AND Active = 1)
- Both: (QTYRECVD - QTYSOLD <> 0) - non-zero quantity
- Both: Expiry filter excludes soon-to-expire inventory

**Notable Assumptions:**
- WFQ and RMQTY are separate inventory types with different hold periods
- Hold period is configurable per item or uses global default
- Expiry filter prevents allocation of inventory expiring within configurable window
- Batches are grouped by RCTSEQNM (receipt sequence number)

**Open Questions/Ambiguity:**
- What is the business logic for different hold periods (WFQ 14 days vs RMQTY 7 days)?
- Why is expiry filtering applied (what is the business impact of near-expiry inventory)?
- Are there other inventory types besides WFQ and RMQTY?
- How are WFQ and RMQTY batches released to normal inventory?

---

### ETB2 CORE LAYER

#### View: `dbo.ETB2_PAB_EventLedger_v1`
**File Path:** `views/16_dbo.ETB2_PAB_EventLedger_v1.sql`  
**Intended Persona:** Demand Planner, Supply Planner, Analyst  
**Grain:** Event (ORDERNUMBER + ITEMNMBR + DUEDATE + EventType)  
**Source Tables:**
- `dbo.ETB_PAB_AUTO` (raw demand data)
- `dbo.Rolyat_Cleaned_Base_Demand_1` (cleaned demand)
- `dbo.IV00102` (inventory on hand)
- `dbo.POP10100`, `dbo.POP10110` (PO lines and headers)
- `dbo.POP10300` (PO receipts)
- `dbo.Prosenthal_Vendor_Items` (item master)

**Metrics Produced:**
- `Running_Balance` - Cumulative sum of all event quantities (SUM(BEG_BAL + Deductions + Expiry + [PO's]) OVER (...))
- `EventSeq` - Row number for event sequencing

**Time Logic:**
- Event ordering: DUEDATE ASC, SortPriority ASC, ORDERNUMBER ASC
- PO date range: REQDATE >= DATEADD(MONTH, -12, GETDATE()) AND REQDATE <= DATEADD(MONTH, 18, GETDATE())
- PO receipt date range: RECPTDATE >= DATEADD(MONTH, -12, GETDATE())
- Expiry events: Expiry_Dates BETWEEN GETDATE() AND DATEADD(MONTH, 6, GETDATE())

**Event Structure:**
| Event Type | SortPriority | Column | Sign | Notes |
|---|---|---|---|---|
| BEGIN_BAL | 1 | BEG_BAL | + | One row per item/site with inventory |
| PO_COMMITMENT | 2 | [PO's] | + | Full ordered qty minus cancellations |
| PO_RECEIPT | 2 | [PO's] | + | Additive, not subtractive from commitment |
| DEMAND | 3 | Deductions | - | De-duplicated to earliest date per MO/item |
| EXPIRY | 4 | Expiry | - | If expiry data exists in cleaned demand |

**Filters/Exclusions:**
- Includes 60.x and 70.x items (IN-PROCESS MATERIALS - explicitly included)
- PO status: POSTATUS IN (2, 4) - Released or Change Order
- PO quantity: (QTYORDER - QTYCANCE) > 0
- PO receipt: QTYRECVD > 0
- Demand: Base_Demand > 0
- Expiry: Expiry > 0 AND Expiry_Dates IS NOT NULL

**Notable Assumptions:**
- 60.x and 70.x items are IN-PROCESS MATERIALS and should be included (opposite of Rolyat_Cleaned_Base_Demand_1)
- PO commitments and receipts are separate additive events (not netted)
- MOs with multiple due dates are de-duplicated to earliest date per item/MO
- Running balance is cumulative across all event types per item/site
- Event sequencing is deterministic for reproducible ordering

**Open Questions/Ambiguity:**
- Why are 60.x and 70.x items excluded from Rolyat_Cleaned_Base_Demand_1 but included here?
- How are PO commitments and receipts used downstream (are they both allocated)?
- What is the business logic for de-duplicating MOs to earliest date?
- Are there other event types that should be included (e.g., returns, adjustments)?

---

#### View: `dbo.ETB2_Config_Engine_v1`
**File Path:** `views/ETB2_Config_Engine_v1.sql`  
**Intended Persona:** System Administrator, Configuration Manager  
**Grain:** Configuration (ITEMNMBR + Client_ID + Site_ID + Config_Key)  
**Source Tables:**
- `dbo.Rolyat_Site_Config` (site configuration)
- `dbo.Rolyat_Config_Items` (item-specific overrides)
- `dbo.Rolyat_Config_Clients` (client-specific overrides)
- `dbo.Rolyat_Config_Global` (global defaults)

**Metrics Produced:** None (configuration only)  
**Time Logic:** Effective_Date, Expiry_Date (temporal validity)  
**Filters/Exclusions:**
- Item config: Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())
- Client config: Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())
- Global config: Effective_Date <= GETDATE() AND (Expiry_Date IS NULL OR Expiry_Date > GETDATE())

**Notable Assumptions:**
- Config hierarchy (priority order):
  1. Item-specific config (highest priority = 1)
  2. Client-specific config (priority = 2)
  3. Global default config (lowest priority = 3)
  4. Site configs (separate handling)
- All configs pivoted into columns for easy joining
- Eliminates 11+ duplicate config lookups across downstream views

**Configuration Parameters Exposed:**
- Hold periods: WFQ_Hold_Days, RMQTY_Hold_Days
- Expiry filters: WFQ_Expiry_Filter_Days, RMQTY_Expiry_Filter_Days
- Active window: ActiveWindow_Past_Days, ActiveWindow_Future_Days
- Shelf life: WC_Batch_Shelf_Life_Days
- Safety stock: Safety_Stock_Days, Safety_Stock_Method
- Degradation tiers: Degradation_Tier1_Days, Degradation_Tier2_Days, Degradation_Tier3_Days, Degradation_Tier1_Factor, Degradation_Tier2_Factor, Degradation_Tier3_Factor, Degradation_Tier4_Factor
- Location codes: WFQ_Locations, RMQTY_Locations
- Backward suppression: BackwardSuppression_Lookback_Days, BackwardSuppression_Extended_Lookback_Days

**Open Questions/Ambiguity:**
- How is Config_Source used downstream (is it for audit/debugging)?
- Are there other config parameters that should be exposed?
- How are site configs used in the hierarchy?

---

#### View: `dbo.ETB2_Inventory_Unified_v1`
**File Path:** `views/ETB2_Inventory_Unified_v1.sql`  
**Intended Persona:** Inventory Manager, Allocation Planner  
**Grain:** Batch (Batch_ID)  
**Source Tables:**
- `dbo.Prosenthal_INV_BIN_QTY` (WC batch data)
- `dbo.IV00300` (inventory lot master)
- `dbo.IV00101` (item master)
- `dbo.Rolyat_Site_Config` (site configuration)
- `dbo.ETB2_Config_Engine_v1` (configuration engine)

**Metrics Produced:**
- `QTY_ON_HAND` - Available quantity per batch
- `Age_Days` - DATEDIFF(DAY, Receipt_Date, GETDATE())
- `Days_Until_Release` - Days remaining until hold period expires
- `Is_Eligible_For_Release` - Flag (1 if eligible, 0 if on hold)

**Time Logic:**
- Receipt_Date: DATERECD (receipt date)
- Expiry_Date: COALESCE(EXPNDATE, DATEADD(DAY, Shelf_Life_Days, DATERECD))
- Projected_Release_Date: DATEADD(DAY, Hold_Days, Receipt_Date)
- Days_Until_Release: Hold_Days - Age_Days

**Inventory Types:**
| Type | Hold Period | Eligibility | SortPriority | Source |
|---|---|---|---|---|
| WC_BATCH | None (0 days) | Always eligible | 1 | Prosenthal_INV_BIN_QTY |
| WFQ_BATCH | 14 days (config) | After hold period | 2 | IV00300 (WFQ sites) |
| RMQTY_BATCH | 7 days (config) | After hold period | 3 | IV00300 (RMQTY sites) |

**Filters/Exclusions:**
- WC: QTY_ON_HAND > 0
- WFQ: ATYALLOC > 0 AND LOCNCODE IN (WFQ sites from config)
- RMQTY: QTY_RM_I > 0 AND LOCNCODE IN (RMQTY sites from config)

**Notable Assumptions:**
- WC batches are always eligible for allocation (no hold period)
- WFQ and RMQTY batches have configurable hold periods
- Batch_ID is constructed for uniqueness (e.g., 'WC-LOCNCODE-BIN-ITEMNMBR-DATERECD')
- SortPriority determines allocation order (WC first, then WFQ, then RMQTY)

**Open Questions/Ambiguity:**
- How is Shelf_Life_Days determined (item-specific vs global)?
- Are there other inventory types besides WC, WFQ, RMQTY?
- How are batches released from WFQ/RMQTY to normal inventory?

---

#### View: `dbo.ETB2_Allocation_Engine_v1`
**File Path:** `views/ETB2_Allocation_Engine_v1.sql`  
**Intended Persona:** Allocation Planner, Supply Planner  
**Grain:** Batch-Demand Pair (Batch_ID + Demand_Date)  
**Source Tables:**
- `dbo.ETB2_Inventory_Unified_v1` (unified inventory)
- `dbo.Rolyat_Cleaned_Base_Demand_1` (cleaned demand)

**Metrics Produced:**
- `Allocated_Qty` - Quantity allocated from batch to demand
- `Total_Allocated_Per_Batch` - Total allocated across all demands for batch
- `Remaining_Demand` - Unmet demand after allocation
- `Allocation_Status` - FULLY_ALLOCATED, PARTIALLY_ALLOCATED, NOT_ALLOCATED

**Time Logic:**
- Batch ordering: Expiry_Date ASC, SortPriority ASC (FEFO)
- Demand ordering: Demand_Date ASC, Demand_SortPriority ASC

**Allocation Logic:**
- Only allocates eligible WC batches (Is_Eligible_For_Release = 1)
- Allocates sequentially by FEFO (First Expiry First Out)
- Allocation per batch-demand pair: LEAST(Base_Demand, Remaining_Batch_Qty)
- Running balance tracks cumulative allocation per batch

**Filters/Exclusions:**
- Only WC_BATCH inventory type (Inventory_Type = 'WC_BATCH')
- Only eligible batches (Is_Eligible_For_Release = 1)
- Only positive quantities (QTY_ON_HAND > 0, Base_Demand > 0)

**Notable Assumptions:**
- FEFO allocation is deterministic and reproducible
- Allocation is sequential (batch 1 exhausted before batch 2 used)
- Remaining demand is tracked for downstream analysis
- Allocation status is per batch-demand pair

**Open Questions/Ambiguity:**
- How are WFQ and RMQTY batches allocated (are they allocated separately)?
- What happens to unmet demand after all batches are exhausted?
- Are there other allocation strategies besides FEFO?
- How is allocation priority determined if multiple batches have same expiry date?

---

#### View: `dbo.ETB2_Final_Ledger_v1`
**File Path:** `views/ETB2_Final_Ledger_v1.sql`  
**Intended Persona:** Inventory Manager, Analyst  
**Grain:** Batch (Batch_ID)  
**Source Tables:**
- `dbo.ETB2_Inventory_Unified_v1` (unified inventory)
- `dbo.ETB2_Allocation_Engine_v1` (allocation data)

**Metrics Produced:**
- `Starting_Qty` - QTY_ON_HAND from inventory
- `Allocated_Qty` - Total allocated from batch
- `Remaining_Qty` - Starting_Qty - Allocated_Qty
- `Utilization_Pct` - (Allocated_Qty / Starting_Qty) * 100
- `Days_Until_Expiry` - DATEDIFF(DAY, GETDATE(), Expiry_Date)

**Time Logic:**
- Snapshot_Date: GETDATE()
- Days_Until_Expiry: DATEDIFF(DAY, GETDATE(), Expiry_Date)

**Status Classifications:**
| Status | Condition | Ledger_Category |
|---|---|---|
| EXHAUSTED | Remaining_Qty <= 0 | CONSUMED |
| ON_HOLD | Is_Eligible_For_Release = 0 | HELD |
| EXPIRING_SOON | Days_Until_Expiry <= 30 | EXPIRING |
| AVAILABLE | Otherwise | AVAILABLE |

**Expiry Risk Tiers:**
| Tier | Days Until Expiry | Risk Level |
|---|---|---|
| EXPIRED | <= 0 | Critical |
| CRITICAL | 1-30 | Critical |
| HIGH | 31-60 | High |
| MEDIUM | 61-90 | Medium |
| LOW | > 90 | Low |
| NO_EXPIRY | NULL | N/A |

**Filters/Exclusions:**
- Only batches with QTY_ON_HAND > 0

**Notable Assumptions:**
- Remaining_Qty can be negative (over-allocated)
- Utilization_Pct is 0 if Starting_Qty = 0
- Expiry risk tiers are used for prioritization downstream

**Open Questions/Ambiguity:**
- How are over-allocated batches (Remaining_Qty < 0) handled?
- What is the business logic for expiry risk tier thresholds (30, 60, 90 days)?
- Are there other status classifications needed?

---

#### View: `dbo.ETB2_StockOut_Analysis_v1`
**File Path:** `views/ETB2_StockOut_Analysis_v1.sql`  
**Intended Persona:** Supply Planner, Demand Planner  
**Grain:** Item-Date (ITEMNMBR + Client_ID + Site_ID + Demand_Date)  
**Source Tables:**
- `dbo.Rolyat_Cleaned_Base_Demand_1` (demand data)
- `dbo.ETB2_Allocation_Engine_v1` (allocation data)
- `dbo.ETB2_Final_Ledger_v1` (inventory ledger)

**Metrics Produced:**
- `ATP_Balance` - Total_Allocated - Total_Demand
- `Unmet_Demand` - Total_Demand - Total_Allocated
- `Effective_ATP_Balance` - ATP_Balance + Available_Alternate_Qty
- `Available_Alternate_Qty` - WFQ + RMQTY eligible inventory

**Time Logic:**
- Demand_Date: Aggregation date for demand
- Snapshot_Date: GETDATE()

**Risk Classification:**
| Risk Level | ATP_Balance | Alternate Stock | Action |
|---|---|---|---|
| CRITICAL_STOCKOUT | <= 0 | <= 0 | URGENT_PURCHASE |
| HIGH_RISK | <= 0 | > 0 | RELEASE_ALTERNATE_STOCK |
| MEDIUM_RISK | 1-49 | Any | EXPEDITE_OPEN_POS |
| LOW_RISK | 50-99 | Any | MONITOR |
| HEALTHY | >= 100 | Any | MONITOR |

**Action Priority:**
| Priority | Risk Level |
|---|---|
| 1 | CRITICAL_STOCKOUT |
| 2 | HIGH_RISK |
| 3 | MEDIUM_RISK |
| 4 | LOW_RISK |
| 5 | HEALTHY |

**Filters/Exclusions:**
- Demand: Base_Demand > 0 AND Demand_Date IS NOT NULL
- Alternate stock: Inventory_Type IN ('WFQ_BATCH', 'RMQTY_BATCH') AND Is_Eligible_For_Release = 1 AND Remaining_Qty > 0

**Notable Assumptions:**
- ATP balance is calculated per demand date
- Alternate stock (WFQ/RMQTY) is evaluated separately from WC inventory
- Risk classification is based on ATP balance thresholds
- Action priority is inversely correlated with ATP balance

**Open Questions/Ambiguity:**
- How are risk thresholds (0, 50, 100) determined?
- What is the business logic for evaluating alternate stock separately?
- Are there other risk factors besides ATP balance?

---

#### View: `dbo.ETB2_Net_Requirements_v1`
**File Path:** `views/ETB2_Net_Requirements_v1.sql`  
**Intended Persona:** Supply Planner, Procurement  
**Grain:** Item (ITEMNMBR + Client_ID + Site_ID)  
**Source Tables:**
- `dbo.ETB2_Config_Engine_v1` (configuration)
- `dbo.ETB2_StockOut_Analysis_v1` (stockout analysis)
- `dbo.ETB2_Final_Ledger_v1` (inventory ledger)

**Metrics Produced:**
- `Net_Requirement_Qty` - How much to order
- `Safety_Stock_Level` - Minimum inventory target
- `Days_Of_Supply` - Available_Inventory * Demand_Days / Total_Demand

**Time Logic:**
- Snapshot_Date: GETDATE()

**Requirement Status Classification:**
| Status | Condition | Priority |
|---|---|---|
| CRITICAL_SHORTAGE | ATP_Balance < 0 | 1 |
| BELOW_SAFETY_STOCK | ATP_Balance < Safety_Stock_Level | 2 |
| FORECASTED_SHORTAGE | Unmet_Demand > 0 | 3 |
| ADEQUATE | Otherwise | 4 |

**Net Requirement Calculation:**
```
IF ATP_Balance < 0:
  Net_Requirement = ABS(ATP_Balance) + Safety_Stock_Level
ELSE IF ATP_Balance < Safety_Stock_Level:
  Net_Requirement = Safety_Stock_Level - ATP_Balance
ELSE IF Unmet_Demand > 0:
  Net_Requirement = Unmet_Demand
ELSE:
  Net_Requirement = 0
```

**Safety Stock Calculation:**
```
IF Safety_Stock_Method = 'DAYS_OF_SUPPLY':
  Safety_Stock_Level = (Total_Demand / Demand_Days) * Safety_Stock_Days
ELSE:
  Safety_Stock_Level = Safety_Stock_Days
```

**Filters/Exclusions:**
- Only items with ITEMNMBR IS NOT NULL in config

**Notable Assumptions:**
- Safety stock is calculated as days of supply (default method)
- Days of supply is calculated as (Available_Inventory * Demand_Days) / Total_Demand
- Net requirement is cumulative (shortage + safety stock)

**Open Questions/Ambiguity:**
- How is Safety_Stock_Days configured (item vs global)?
- What is the business logic for different safety stock methods?
- How are net requirements used for procurement decisions?

---

#### View: `dbo.ETB2_PO_Detail_v1`
**File Path:** `views/ETB2_PO_Detail_v1.sql`  
**Intended Persona:** Procurement, Supply Planner  
**Grain:** PO Line (PONUMBER + LNITMSEQ)  
**Source Tables:**
- `dbo.POP10100` (PO Header)
- `dbo.POP10110` (PO Lines)

**Metrics Produced:**
- `Quantity_Remaining` - QTYORDER - QTYRCEIV - QTYCNCLD
- `Days_Until_Due` - DATEDIFF(DAY, GETDATE(), PROMDATE)
- `Receipt_Completion_Pct` - (QTYRCEIV / QTYORDER) * 100

**Time Logic:**
- PODATE: PO creation date
- PROMDATE: Promised delivery date
- Days_Until_Due: DATEDIFF(DAY, GETDATE(), PROMDATE)
- Snapshot_Date: GETDATE()

**Delivery Status Classification:**
| Status | Condition |
|---|---|
| COMPLETED | POSTATUS = 4 OR Quantity_Remaining <= 0 |
| PAST_DUE | Days_Until_Due < 0 AND Quantity_Remaining > 0 |
| DUE_SOON | Days_Until_Due BETWEEN 0 AND 7 AND Quantity_Remaining > 0 |
| ON_TIME | Otherwise |

**Filters/Exclusions:**
- Excludes fully closed POs (POSTATUS NOT IN (4))
- Final output: Quantity_Remaining > 0 OR Delivery_Status = 'COMPLETED'

**Notable Assumptions:**
- Quantity_Remaining is calculated as ordered minus received minus cancelled
- Delivery status is based on promised date and remaining quantity
- Receipt completion percentage is 0 if QTYORDER = 0

**Open Questions/Ambiguity:**
- What is the business logic for "DUE_SOON" threshold (7 days)?
- How are past-due POs escalated?
- Are there other PO statuses that should be tracked?

---

#### View: `dbo.ETB2_Unit_Price_v1`
**File Path:** `views/ETB2_Unit_Price_v1.sql`  
**Intended Persona:** Finance, Supply Planner  
**Grain:** Item-Location (ITEMNMBR + Site_ID)  
**Source Tables:**
- `dbo.IV00108` (Item Price List)
- `dbo.IV00101` (Item Master)

**Metrics Produced:**
- `Effective_Unit_Price` - Fallback hierarchy: List_Price > Current_Cost > Standard_Cost
- `Gross_Margin_Pct` - (List_Price - Current_Cost) / List_Price * 100
- `Price_Tier` - Classification (1=RETAIL, 2=WHOLESALE, 3=DISTRIBUTOR, 4=COST_PLUS, 5=OTHER)

**Time Logic:**
- Snapshot_Date: GETDATE()

**Price Tier Mapping:**
| Tier | Price_Level | Priority |
|---|---|---|
| 1 | RETAIL | Highest |
| 2 | WHOLESALE | High |
| 3 | DISTRIBUTOR | Medium |
| 4 | COST_PLUS | Low |
| 5 | OTHER | Lowest |

**Effective Price Hierarchy:**
1. List_Price (if > 0)
2. Current_Cost (if > 0)
3. Standard_Cost (if > 0)
4. 0 (default)

**Filters/Exclusions:**
- Only items with UNITPRCE > 0 OR CURRCOST > 0 OR STNDCOST > 0

**Notable Assumptions:**
- Effective price uses fallback hierarchy for robustness
- Gross margin is calculated only if both List_Price and Current_Cost exist
- Price tier is based on Price_Level field

**Open Questions/Ambiguity:**
- How is Price_Level determined upstream?
- What is the business logic for price tier hierarchy?
- Are there other pricing metrics needed?

---

#### View: `dbo.ETB2_Rebalancing_v1`
**File Path:** `views/ETB2_Rebalancing_v1.sql`  
**Intended Persona:** Supply Planner, Inventory Manager  
**Grain:** Rebalancing Opportunity (Batch_ID + Risk_Level)  
**Source Tables:**
- `dbo.ETB2_Final_Ledger_v1` (inventory ledger)
- `dbo.ETB2_StockOut_Analysis_v1` (stockout analysis)

**Metrics Produced:**
- `Recommended_Transfer_Qty` - LEAST(Remaining_Qty, Unmet_Demand)
- `Transfer_Priority` - 1-4 (1=urgent, 4=monitor)
- `Business_Impact` - HIGH, MEDIUM, LOW

**Time Logic:**
- Snapshot_Date: GETDATE()

**Transfer Priority Matrix:**
| Priority | Expiry | Risk Level |
|---|---|---|
| 1 | <= 30 days | CRITICAL_STOCKOUT |
| 2 | <= 60 days | CRITICAL_STOCKOUT or HIGH_RISK |
| 3 | <= 90 days | Any risk level |
| 4 | > 90 days | Any risk level |

**Rebalancing Type Classification:**
| Type | Condition |
|---|---|
| URGENT_TRANSFER | Days_Until_Expiry <= 30 AND Risk_Level = CRITICAL_STOCKOUT |
| EXPEDITE_TRANSFER | Days_Until_Expiry <= 60 AND Risk_Level IN (CRITICAL_STOCKOUT, HIGH_RISK) |
| PLANNED_TRANSFER | Days_Until_Expiry <= 90 AND Risk_Level IN (CRITICAL_STOCKOUT, HIGH_RISK, MEDIUM_RISK) |
| MONITOR | Otherwise |

**Business Impact Assessment:**
| Impact | Condition |
|---|---|
| HIGH | Days_Until_Expiry <= 60 AND Risk_Level IN (CRITICAL_STOCKOUT, HIGH_RISK) |
| MEDIUM | Days_Until_Expiry <= 90 AND Risk_Level = MEDIUM_RISK |
| LOW | Otherwise |

**Filters/Exclusions:**
- Expiring inventory: Days_Until_Expiry <= 90 AND Days_Until_Expiry > 0 AND Remaining_Qty > 0
- Stockout demand: Risk_Level IN (CRITICAL_STOCKOUT, HIGH_RISK, MEDIUM_RISK) AND Unmet_Demand > 0
- Cross-match: INNER JOIN on ITEMNMBR, Client_ID, Site_ID

**Notable Assumptions:**
- Rebalancing matches expiring inventory with stockout demand
- Transfer quantity is limited by available inventory and unmet demand
- Priority is based on expiry urgency and demand risk
- Business impact is assessed for decision-making

**Open Questions/Ambiguity:**
- How are rebalancing recommendations executed?
- What is the business logic for priority thresholds (30, 60, 90 days)?
- Are there other rebalancing strategies besides expiry-driven transfers?

---

#### View: `dbo.ETB2_Presentation_Dashboard_v1`
**File Path:** `views/ETB2_Presentation_Dashboard_v1.sql`  
**Intended Persona:** Executive, Supply Planner, Inventory Manager  
**Grain:** Dashboard Item (varies by Dashboard_Type)  
**Source Tables:**
- `dbo.Rolyat_StockOut_Analysis_v2` (stockout analysis)
- `dbo.ETB2_Inventory_Unified_v1` (unified inventory)
- `dbo.Rolyat_PO_Detail` (PO details)

**Metrics Produced:** Multiple per dashboard type (see below)  
**Time Logic:** Snapshot_Date: GETDATE()

**Dashboard Types:**

**1. STOCKOUT_RISK (Executive View)**
- **Grain:** Item (CleanItem)
- **Risk Levels:** CRITICAL_STOCKOUT, HIGH_RISK, MEDIUM_RISK, HEALTHY
- **Recommended Actions:** URGENT_PURCHASE, EXPEDITE_OPEN_POS, TRANSFER_FROM_OTHER_SITES, MONITOR
- **Filters:** Risk_Level <> 'HEALTHY'
- **Metrics:**
  - Current_ATP_Balance: effective_demand
  - Available_Alternate_Stock_Qty: Alternate_Stock
  - Forecast_Balance_Before_Allocation: Original_Running_Balance
  - WFQ_QTY, RMQTY_QTY: Alternate stock quantities

**2. BATCH_EXPIRY (Inventory View)**
- **Grain:** Batch (Batch_ID)
- **Risk Levels:** EXPIRED, CRITICAL, HIGH, MEDIUM, LOW
- **Recommended Actions:** USE_FIRST, RELEASE_AFTER_HOLD, HOLD_IN_WFQ, HOLD_IN_RMQTY, UNKNOWN
- **Filters:** Expiry_Date IS NOT NULL AND Days_Until_Expiry <= 90
- **Metrics:**
  - Days_Until_Expiry: DATEDIFF(DAY, GETDATE(), Expiry_Date)
  - Batch_Qty: QTY_ON_HAND
  - Business_Impact: HIGH, MEDIUM, LOW (based on qty * 100)

**3. PLANNER_ACTIONS (Operational View)**
- **Grain:** Item or Batch (varies by priority)
- **Priority Levels:** 1-4 (1=critical, 4=past due)
- **Sub-types:**
  - Priority 1: Critical stock-outs (effective_demand <= 0)
  - Priority 2: High risk items (effective_demand < 50)
  - Priority 3: Critical expiry batches (Days_Until_Expiry BETWEEN 0 AND 30)
  - Priority 4: Past due POs (PO_Due_Date < GETDATE())

**Filters/Exclusions:**
- STOCKOUT_RISK: Risk_Level <> 'HEALTHY'
- BATCH_EXPIRY: Expiry_Date IS NOT NULL AND Days_Until_Expiry <= 90
- PLANNER_ACTIONS: Multiple conditions per priority level

**Notable Assumptions:**
- Dashboard consolidates 3 separate views into single intelligent view
- Smart filtering allows different audiences to see relevant data
- Risk categorization is consistent across dashboard types
- Action recommendations prioritize urgency

**Open Questions/Ambiguity:**
- How are risk thresholds determined (CRITICAL_STOCKOUT <= 0, HIGH_RISK < 50)?
- What is the business logic for different dashboard types?
- How are dashboard items prioritized for display?

---

#### View: `dbo.ETB2_Consumption_Detail_v1`
**File Path:** `views/ETB2_Consumption_Detail_v1.sql`  
**Intended Persona:** Analyst, SSRS Report Consumer  
**Grain:** Order Line (ORDERNUMBER + ITEMNMBR)  
**Source Tables:**
- `dbo.Rolyat_Final_Ledger_3` (final ledger data)

**Metrics Produced:** All metrics from final ledger with dual naming  
**Time Logic:** Inherits from Rolyat_Final_Ledger_3  
**Filters/Exclusions:** None (pass-through view)

**Notable Assumptions:**
- Consolidates Rolyat_Consumption_Detail_v1 and Rolyat_Consumption_SSRS_v1
- Provides both technical and business-friendly column names
- Single view serves both detailed analysis and SSRS reporting

**Open Questions/Ambiguity:**
- What is the relationship between this view and Rolyat_Final_Ledger_3?
- Are there other consumption metrics needed?

---

#### View: `dbo.ETB2_Supply_Chain_Master_v1`
**File Path:** `views/ETB2_Supply_Chain_Master_v1.sql`  
**Intended Persona:** Executive, Supply Chain Manager  
**Grain:** Item-Date (ITEMNMBR + Client_ID + Site_ID + Demand_Date)  
**Source Tables:**
- `dbo.ETB2_StockOut_Analysis_v1` (demand baseline)
- `dbo.ETB2_Final_Ledger_v1` (inventory position)
- `dbo.ETB2_Net_Requirements_v1` (requirements)
- `dbo.ETB2_Unit_Price_v1` (pricing)
- `dbo.ETB2_PO_Detail_v1` (PO tracking)
- `dbo.ETB2_Rebalancing_v1` (rebalancing opportunities)

**Metrics Produced:**
- **Demand Metrics:** Total_Demand, Total_Allocated, ATP_Balance, Unmet_Demand, Effective_ATP_Balance
- **Inventory Metrics:** Available_Inventory, Total_Starting_Qty, Total_Allocated_Qty, Total_Remaining_Qty, Batch_Count, Min_Days_Until_Expiry, Max_Days_Until_Expiry
- **Requirements Metrics:** Net_Requirement_Qty, Requirement_Status, Requirement_Priority, Days_Of_Supply, Safety_Stock_Level
- **Pricing Metrics:** Effective_Unit_Price, List_Price, Current_Cost, Standard_Cost, Gross_Margin_Pct
- **PO Metrics:** PO_Quantity_Remaining, PO_Past_Due_Qty, PO_Due_Soon_Qty, PO_Count
- **Rebalancing Metrics:** Rebalancing_Transfer_Qty, Rebalancing_Priority, Has_Urgent_Rebalancing
- **Extended Values:** Gross_Demand_Value, Stockout_Risk_Value, Net_Requirement_Cost, Available_Inventory_Value

**Time Logic:**
- Snapshot_Date: GETDATE()
- Demand_Date: From demand baseline

**Extended Value Calculations:**
```
Gross_Demand_Value = Total_Demand * Effective_Unit_Price
Stockout_Risk_Value = Unmet_Demand * Effective_Unit_Price
Net_Requirement_Cost = Net_Requirement_Qty * Standard_Cost
Available_Inventory_Value = Available_Inventory * Effective_Unit_Price
```

**Filters/Exclusions:** None (comprehensive view)

**Notable Assumptions:**
- Master view combines all supply chain dimensions
- Extended values enable financial analysis
- Enables holistic supply chain analysis from single view

**Open Questions/Ambiguity:**
- How is this view used for executive reporting?
- What are the key performance indicators derived from this view?
- Are there other extended value calculations needed?

---

## 3. Metric Index

### Demand Metrics
- **Base_Demand** - Priority-based demand (Remaining > Deductions > Expiry)
  - Views: Rolyat_Cleaned_Base_Demand_1, ETB2_PAB_EventLedger_v1, ETB2_Allocation_Engine_v1, ETB2_StockOut_Analysis_v1
  - Definition: CASE WHEN Remaining > 0 THEN Remaining WHEN Deductions > 0 THEN Deductions WHEN Expiry > 0 THEN Expiry ELSE 0 END

- **Total_Demand** - Aggregated demand per item/date/site
  - Views: ETB2_StockOut_Analysis_v1, ETB2_Net_Requirements_v1, ETB2_Supply_Chain_Master_v1
  - Definition: SUM(Base_Demand) GROUP BY ITEMNMBR, Client_ID, Site_ID, Demand_Date

- **Unmet_Demand** - Demand not covered by allocation
  - Views: ETB2_StockOut_Analysis_v1, ETB2_Net_Requirements_v1, ETB2_Rebalancing_v1, ETB2_Supply_Chain_Master_v1
  - Definition: Total_Demand - Total_Allocated

### Inventory Metrics
- **QTY_ON_HAND** - Available quantity per batch
  - Views: Rolyat_WC_Inventory, Rolyat_WFQ_5, ETB2_Inventory_Unified_v1, ETB2_Final_Ledger_v1
  - Definition: SUM(QTYRECVD - QTYSOLD) for WFQ/RMQTY, QTY_Available for WC

- **Available_Inventory** - Total available inventory per item
  - Views: ETB2_Net_Requirements_v1, ETB2_Supply_Chain_Master_v1
  - Definition: SUM(Remaining_Qty) WHERE Inventory_Status = 'AVAILABLE'

- **Remaining_Qty** - Starting_Qty - Allocated_Qty
  - Views: ETB2_Final_Ledger_v1, ETB2_Rebalancing_v1, ETB2_Supply_Chain_Master_v1
  - Definition: Starting_Qty - Allocated_Qty

- **Allocated_Qty** - Quantity allocated from batch
  - Views: ETB2_Allocation_Engine_v1, ETB2_Final_Ledger_v1
  - Definition: LEAST(Base_Demand, Remaining_Batch_Qty) per FEFO sequence

### ATP & Balance Metrics
- **ATP_Balance** - Available To Promise balance
  - Views: ETB2_StockOut_Analysis_v1, ETB2_Net_Requirements_v1, ETB2_Supply_Chain_Master_v1
  - Definition: Total_Allocated - Total_Demand
  - Conflicting Definitions: None identified

- **Effective_ATP_Balance** - ATP balance including alternate stock
  - Views: ETB2_StockOut_Analysis_v1, ETB2_Supply_Chain_Master_v1
  - Definition: ATP_Balance + Available_Alternate_Qty

- **Running_Balance** - Cumulative sum of all event quantities
  - Views: ETB2_PAB_EventLedger_v1
  - Definition: SUM(BEG_BAL + Deductions + Expiry + [PO's]) OVER (PARTITION BY ITEMNMBR, Site ORDER BY DUEDATE, SortPriority)

### Pricing Metrics
- **Effective_Unit_Price** - Fallback hierarchy price
  - Views: ETB2_Unit_Price_v1, ETB2_Supply_Chain_Master_v1
  - Definition: CASE WHEN List_Price > 0 THEN List_Price WHEN Current_Cost > 0 THEN Current_Cost WHEN Standard_Cost > 0 THEN Standard_Cost ELSE 0 END

- **Gross_Margin_Pct** - Gross margin percentage
  - Views: ETB2_Unit_Price_v1, ETB2_Supply_Chain_Master_v1
  - Definition: (List_Price - Current_Cost) / List_Price * 100

### Requirements Metrics
- **Net_Requirement_Qty** - How much to order
  - Views: ETB2_Net_Requirements_v1, ETB2_Supply_Chain_Master_v1
  - Definition: Complex logic based on ATP_Balance, Safety_Stock_Level, Unmet_Demand

- **Safety_Stock_Level** - Minimum inventory target
  - Views: ETB2_Net_Requirements_v1, ETB2_Supply_Chain_Master_v1
  - Definition: (Total_Demand / Demand_Days) * Safety_Stock_Days (if DAYS_OF_SUPPLY method)

- **Days_Of_Supply** - Available inventory in days of demand
  - Views: ETB2_Net_Requirements_v1, ETB2_Supply_Chain_Master_v1
  - Definition: (Available_Inventory * Demand_Days) / Total_Demand

### PO Metrics
- **Quantity_Remaining** - Undelivered PO quantity
  - Views: ETB2_PO_Detail_v1, ETB2_Supply_Chain_Master_v1
  - Definition: QTYORDER - QTYRCEIV - QTYCNCLD

- **Days_Until_Due** - Days until PO promised date
  - Views: ETB2_PO_Detail_v1
  - Definition: DATEDIFF(DAY, GETDATE(), PROMDATE)

- **Receipt_Completion_Pct** - Percentage of PO received
  - Views: ETB2_PO_Detail_v1
  - Definition: (QTYRCEIV / QTYORDER) * 100

### Rebalancing Metrics
- **Recommended_Transfer_Qty** - Suggested transfer quantity
  - Views: ETB2_Rebalancing_v1, ETB2_Supply_Chain_Master_v1
  - Definition: LEAST(Remaining_Qty, Unmet_Demand)

- **Transfer_Priority** - Rebalancing urgency (1-4)
  - Views: ETB2_Rebalancing_v1, ETB2_Supply_Chain_Master_v1
  - Definition: Based on Days_Until_Expiry and Risk_Level

### Extended Value Metrics
- **Gross_Demand_Value** - Total demand in currency
  - Views: ETB2_Supply_Chain_Master_v1
  - Definition: Total_Demand * Effective_Unit_Price

- **Stockout_Risk_Value** - Unmet demand in currency
  - Views: ETB2_Supply_Chain_Master_v1
  - Definition: Unmet_Demand * Effective_Unit_Price

- **Net_Requirement_Cost** - Cost of net requirements
  - Views: ETB2_Supply_Chain_Master_v1
  - Definition: Net_Requirement_Qty * Standard_Cost

- **Available_Inventory_Value** - Available inventory in currency
  - Views: ETB2_Supply_Chain_Master_v1
  - Definition: Available_Inventory * Effective_Unit_Price

---

## 4. Time & Calendar Logic Summary

### Bucketing Approaches

**1. Active Planning Window (±21 days)**
- **Configuration:** ActiveWindow_Past_Days, ActiveWindow_Future_Days (default 21 each)
- **Usage:** Flags records within planning window for WC allocation gating
- **Views:** Rolyat_Cleaned_Base_Demand_1, ETB2_Config_Engine_v1
- **Logic:** DUEDATE BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())

**2. Degradation Tiers (Age-Based)**
- **Tier 1:** 0-30 days, Factor 1.00 (full value)
- **Tier 2:** 31-60 days, Factor 0.75 (75% value)
- **Tier 3:** 61-90 days, Factor 0.50 (50% value)
- **Tier 4:** >90 days, Factor 0.00 (no value)
- **Configuration:** Degradation_Tier1_Days, Degradation_Tier2_Days, Degradation_Tier3_Days, Degradation_Tier1_Factor, Degradation_Tier2_Factor, Degradation_Tier3_Factor, Degradation_Tier4_Factor
- **Views:** Rolyat_Config_Global, ETB2_Config_Engine_v1
- **Status:** Not yet implemented in allocation logic

**3. Hold Periods (Quarantine/Restricted Material)**
- **WFQ Hold Period:** 14 days (configurable)
- **RMQTY Hold Period:** 7 days (configurable)
- **Configuration:** WFQ_Hold_Days, RMQTY_Hold_Days
- **Views:** Rolyat_WFQ_5, ETB2_Inventory_Unified_v1, ETB2_Config_Engine_v1
- **Logic:** Projected_Release_Date = DATEADD(DAY, Hold_Days, Receipt_Date)

**4. Expiry Risk Tiers (Days Until Expiry)**
- **EXPIRED:** <= 0 days
- **CRITICAL:** 1-30 days
- **HIGH:** 31-60 days
- **MEDIUM:** 61-90 days
- **LOW:** > 90 days
- **Views:** ETB2_Final_Ledger_v1, ETB2_Presentation_Dashboard_v1
- **Logic:** DATEDIFF(DAY, GETDATE(), Expiry_Date)

**5. PO Date Ranges**
- **Historical:** DATEADD(MONTH, -12, GETDATE()) (last 12 months)
- **Future:** DATEADD(MONTH, 18, GETDATE()) (next 18 months)
- **Views:** ETB2_PAB_EventLedger_v1
- **Logic:** REQDATE >= DATEADD(MONTH, -12, GETDATE()) AND REQDATE <= DATEADD(MONTH, 18, GETDATE())

**6. Expiry Event Window**
- **Range:** GETDATE() to DATEADD(MONTH, 6, GETDATE()) (next 6 months)
- **Views:** ETB2_PAB_EventLedger_v1
- **Logic:** Expiry_Dates BETWEEN GETDATE() AND DATEADD(MONTH, 6, GETDATE())

**7. Shelf Life (WC Batch Expiry)**
- **Default:** 180 days
- **Configuration:** WC_Batch_Shelf_Life_Days
- **Views:** Rolyat_WC_Inventory, ETB2_Inventory_Unified_v1, ETB2_Config_Engine_v1
- **Logic:** Batch_Expiry_Date = COALESCE(EXPNDATE, DATEADD(DAY, Shelf_Life_Days, DATERECD))

### Calendars Used
- **Gregorian Calendar:** All date calculations use standard SQL Server GETDATE() and DATEADD functions
- **No Custom Calendars:** No fiscal calendars, work calendars, or custom period definitions identified

### Inconsistencies
1. **Expiry Filter Inconsistency:** Rolyat_WFQ_5 excludes inventory expiring within 90 days, but ETB2_Presentation_Dashboard_v1 includes inventory expiring within 90 days for batch expiry dashboard
2. **Hold Period Inconsistency:** WFQ hold period (14 days) vs RMQTY hold period (7 days) - business logic not documented
3. **Degradation Tier Thresholds:** Tier boundaries (30, 60, 90 days) match expiry risk tiers but degradation logic not implemented
4. **Active Window Symmetry:** ActiveWindow_Past_Days and ActiveWindow_Future_Days are both 21 days - is this intentional?

---

## 5. Planner / Persona Notes

### Buyer-Specific Logic
- **Not explicitly identified** in current views
- **Potential areas:** ETB2_Unit_Price_v1 (pricing tiers), ETB2_PO_Detail_v1 (PO tracking)
- **Gap:** No buyer-specific filtering or prioritization logic found

### Supply Planner Logic
- **Primary Views:** ETB2_StockOut_Analysis_v1, ETB2_Net_Requirements_v1, ETB2_Rebalancing_v1, ETB2_Presentation_Dashboard_v1
- **Key Metrics:**
  - ATP_Balance (Available To Promise)
  - Unmet_Demand (shortage identification)
  - Net_Requirement_Qty (procurement guidance)
  - Risk_Level (CRITICAL_STOCKOUT, HIGH_RISK, MEDIUM_RISK, HEALTHY)
  - Recommended_Action (URGENT_PURCHASE, EXPEDITE_OPEN_POS, TRANSFER_FROM_OTHER_SITES, MONITOR)
- **Workflow:**
  1. Monitor ETB2_Presentation_Dashboard_v1 for PLANNER_ACTIONS
  2. Identify critical shortages (ATP_Balance <= 0)
  3. Evaluate alternate stock (WFQ/RMQTY availability)
  4. Calculate net requirements (how much to order)
  5. Execute rebalancing transfers (expiring inventory to shortage items)
  6. Track PO delivery status (past due, due soon)

### Demand Planner Logic
- **Primary Views:** Rolyat_Cleaned_Base_Demand_1, ETB2_PAB_EventLedger_v1, ETB2_StockOut_Analysis_v1
- **Key Metrics:**
  - Base_Demand (priority-based demand calculation)
  - SortPriority (event ordering)
  - IsActiveWindow (planning window flag)
  - Total_Demand (aggregated demand)
  - Unmet_Demand (shortage identification)
- **Workflow:**
  1. Cleanse raw demand from ETB_PAB_AUTO
  2. Calculate Base_Demand using priority logic
  3. Flag records within active planning window
  4. Build event ledger with PO commitments and receipts
  5. Calculate running balance across all events
  6. Identify demand patterns and anomalies

### Inventory Manager Logic
- **Primary Views:** Rolyat_WC_Inventory, Rolyat_WFQ_5, ETB2_Inventory_Unified_v1, ETB2_Final_Ledger_v1
- **Key Metrics:**
  - QTY_ON_HAND (available quantity)
  - Batch_Age_Days (age calculation)
  - Days_Until_Expiry (expiry risk)
  - Is_Eligible_For_Release (hold period status)
  - Inventory_Status (AVAILABLE, ON_HOLD, EXPIRING_SOON, EXHAUSTED)
- **Workflow:**
  1. Monitor inventory across WC, WFQ, RMQTY locations
  2. Track batch age and expiry dates
  3. Manage hold periods (WFQ 14 days, RMQTY 7 days)
  4. Identify expiring inventory (CRITICAL, HIGH, MEDIUM risk tiers)
  5. Execute rebalancing transfers
  6. Monitor utilization percentage per batch

### Executive Logic
- **Primary Views:** ETB2_Presentation_Dashboard_v1 (STOCKOUT_RISK), ETB2_Supply_Chain_Master_v1
- **Key Metrics:**
  - Risk_Level (CRITICAL_STOCKOUT, HIGH_RISK, MEDIUM_RISK, HEALTHY)
  - Recommended_Action (high-level guidance)
  - Gross_Demand_Value (financial impact)
  - Stockout_Risk_Value (financial risk)
  - Available_Inventory_Value (asset value)
- **Workflow:**
  1. Review executive dashboard for risk summary
  2. Identify critical stockouts and high-risk items
  3. Assess financial impact of shortages
  4. Monitor supply chain health metrics
  5. Escalate critical issues to supply planner

---

## 6. Known Gaps & Ambiguities

### Missing Grain Definitions
1. **ETB2_Consumption_Detail_v1:** Grain not explicitly defined (appears to be Order Line, but inherits from Rolyat_Final_Ledger_3)
2. **ETB2_Supply_Chain_Master_v1:** Grain is Item-Date, but some metrics are aggregated at Item level (e.g., Batch_Count)
3. **ETB2_Presentation_Dashboard_v1:** Grain varies by Dashboard_Type (Item for STOCKOUT_RISK, Batch for BATCH_EXPIRY, Item/Batch for PLANNER_ACTIONS)

### Undefined Assumptions
1. **Base_Demand Priority Logic:** Why is Remaining > Deductions > Expiry? What is the business logic?
2. **60.x and 70.x Item Handling:** Why are these items excluded from Rolyat_Cleaned_Base_Demand_1 but included in ETB2_PAB_EventLedger_v1?
3. **Degradation Factors:** Are degradation factors applied to inventory value or quantity? Not implemented in current views.
4. **Hold Period Rationale:** Why is WFQ hold period 14 days and RMQTY hold period 7 days?
5. **Expiry Filter Inconsistency:** Why does Rolyat_WFQ_5 exclude inventory expiring within 90 days, but ETB2_Presentation_Dashboard_v1 includes it?
6. **Risk Thresholds:** How are risk thresholds determined (ATP_Balance <= 0 for CRITICAL, < 50 for HIGH, < 100 for MEDIUM)?
7. **Safety Stock Method:** Only DAYS_OF_SUPPLY is implemented - are there other methods?

### Incomplete Logic
1. **Degradation Implementation:** Degradation tiers are configured but not applied in allocation or valuation logic
2. **Backward Suppression:** BackwardSuppression_Lookback_Days and BackwardSuppression_Extended_Lookback_Days are configured but not used in any view
3. **Client-Specific Config:** Rolyat_Config_Clients is empty (WHERE 1 = 0) - no client-specific overrides implemented
4. **Item-Specific Config:** Rolyat_Config_Items is empty (WHERE 1 = 0) - no item-specific overrides implemented
5. **WFQ/RMQTY Release Logic:** How are batches released from WFQ/RMQTY to normal inventory? Not documented.
6. **Allocation Strategy:** Only FEFO (First Expiry First Out) is implemented - are there other strategies?
7. **Rebalancing Execution:** How are rebalancing recommendations executed? Not documented.

### Data Quality Issues
1. **Null Handling:** Many views use COALESCE with defaults (0, 0.0, 'UNKNOWN') - are these appropriate?
2. **Type Conversions:** Multiple TRY_CAST and TRY_CONVERT operations - what happens to failed conversions?
3. **Partial Data:** Rolyat_Config_Clients and Rolyat_Config_Items return no rows - are these intentional placeholders?

### Missing Metrics
1. **Forecast Accuracy:** No metrics for comparing actual vs forecasted demand
2. **Inventory Turnover:** No metrics for inventory turnover or velocity
3. **Lead Time Variance:** No metrics for PO lead time variance
4. **Stockout Duration:** No metrics for how long items are in stockout
5. **Rebalancing Effectiveness:** No metrics for rebalancing success rate

### Ambiguous Business Rules
1. **Allocation Priority:** How are WFQ and RMQTY batches allocated relative to WC batches?
2. **Demand Sequencing:** How are multiple demand records for same item/date sequenced?
3. **PO Commitment vs Receipt:** Are both PO commitments and receipts allocated, or just receipts?
4. **Expiry Event Inclusion:** Why are expiry events included in event ledger if they're not allocated?
5. **Risk Classification Thresholds:** Are thresholds (0, 50, 100) based on days of supply or absolute quantities?

### Missing Documentation
1. **ETB_PAB_AUTO Source:** What is the upstream source for ETB_PAB_AUTO? How is it populated?
2. **Prosenthal Tables:** What is the relationship between Prosenthal tables and GP tables (IV00101, IV00300)?
3. **EXT_BINTYPE:** What is the source and purpose of EXT_BINTYPE?
4. **Rolyat_Final_Ledger_3:** This view is referenced but not documented - what is its structure?
5. **Rolyat_StockOut_Analysis_v2:** This view is referenced but not documented - what is its structure?

---

## 7. Forensic Observations

### Architecture Patterns
1. **Layered Design:** Foundation (config + raw data) → Core (unified views) → Analysis (specialized views) → Presentation (dashboards)
2. **Configuration Hierarchy:** Item > Client > Global (3-tier priority system)
3. **Inventory Type Segregation:** WC (work center), WFQ (quarantine), RMQTY (restricted material) - separate handling per type
4. **Event-Based Ledger:** All supply/demand events sequenced deterministically for reproducible ordering
5. **FEFO Allocation:** First Expiry First Out allocation strategy for batch sequencing

### Data Flow
```
ETB_PAB_AUTO (raw demand)
  ↓
Rolyat_Cleaned_Base_Demand_1 (cleansed demand)
  ↓
ETB2_PAB_EventLedger_v1 (event sequencing)
  ↓
ETB2_Allocation_Engine_v1 (FEFO allocation)
  ↓
ETB2_Final_Ledger_v1 (inventory ledger)
  ↓
ETB2_StockOut_Analysis_v1 (ATP & risk)
  ↓
ETB2_Net_Requirements_v1 (procurement guidance)
  ↓
ETB2_Supply_Chain_Master_v1 (integrated analysis)
  ↓
ETB2_Presentation_Dashboard_v1 (executive view)
```

### Configuration Consolidation
- **Before:** 11+ duplicate config lookups across downstream views
- **After:** Single ETB2_Config_Engine_v1 with pivoted columns
- **Benefit:** Eliminates redundant lookups and ensures consistency

### View Consolidation
- **Deleted Views (07-15, 17-19):** 12 legacy views consolidated into 5 ETB2 views
- **Consolidation Examples:**
  - Rolyat_Consumption_Detail_v1 + Rolyat_Consumption_SSRS_v1 → ETB2_Consumption_Detail_v1
  - Rolyat_StockOut_Risk_Dashboard + Rolyat_Batch_Expiry_Risk_Dashboard + Rolyat_Supply_Planner_Action_List → ETB2_Presentation_Dashboard_v1
  - Rolyat_Unit_Price_4 → ETB2_Unit_Price_v1
  - Rolyat_WC_Allocation_Effective_2 → ETB2_Allocation_Engine_v1
  - Rolyat_Final_Ledger_3 → ETB2_Final_Ledger_v1
  - Rolyat_Net_Requirements_v1 → ETB2_Net_Requirements_v1
  - Rolyat_PO_Detail → ETB2_PO_Detail_v1
  - Rolyat_Rebalancing_Layer → ETB2_Rebalancing_v1
  - Rolyat_StockOut_Analysis_v2 → ETB2_StockOut_Analysis_v1

### Temporal Validity
- **Configuration:** All config views support Effective_Date and Expiry_Date for time-based changes
- **Snapshots:** All analysis views include Snapshot_Date for point-in-time analysis
- **Event Sequencing:** All events are ordered by date and priority for deterministic processing

### Risk Stratification
- **Demand Risk:** CRITICAL_STOCKOUT, HIGH_RISK, MEDIUM_RISK, LOW_RISK, HEALTHY
- **Expiry Risk:** EXPIRED, CRITICAL, HIGH, MEDIUM, LOW, NO_EXPIRY
- **Requirement Status:** CRITICAL_SHORTAGE, BELOW_SAFETY_STOCK, FORECASTED_SHORTAGE, ADEQUATE
- **Delivery Status:** COMPLETED, PAST_DUE, DUE_SOON, ON_TIME

### Metric Duality
- **Technical Names:** Base_Demand, suppressed_demand, effective_demand, Original_Running_Balance
- **Business Names:** Demand_Qty, ATP_Demand_Qty, ATP_Balance, Forecast_Balance
- **Purpose:** Support both technical analysis and business reporting from single view

---

## 8. Summary Statistics

| Category | Count |
|---|---|
| Total Views | 18 |
| Foundation Views (Rolyat) | 7 |
| ETB2 Core Views | 11 |
| Configuration Views | 4 |
| Inventory Views | 3 |
| Demand/Allocation Views | 2 |
| Analysis Views | 4 |
| Presentation Views | 2 |
| Master/Integration Views | 1 |
| **Total Metrics** | **50+** |
| **Configuration Parameters** | **18** |
| **Risk Classifications** | **3 types** |
| **Event Types** | **5** |
| **Inventory Types** | **3** |
| **Dashboard Types** | **3** |

---

## END OF MEGA ANALYTICS VIEWS DOCUMENTATION

**Document Purpose:** Forensic artifact for system understanding without opening code  
**Intended Audience:** Architects, LLMs, Auditors  
**Completeness:** Exhaustive extraction of analytics logic, assumptions, and ambiguities  
**Last Updated:** 2026-01-25  
**Repository State:** ETB2 Architecture Migration Complete
