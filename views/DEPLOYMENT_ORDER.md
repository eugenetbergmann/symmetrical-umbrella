# ETB2 SQL Views - Deployment Order

## Folder Structure

```
views/
├── background_workers/          # Intermediate/processing views (foundation layers)
└── consumption/                 # End-user facing views
```

---

## Deployment Order (by dependency)

### Phase 1: Foundation / Background Workers

Deploy in exact order as they form the base for all other views.

| Order | View File | Purpose |
|-------|-----------|---------|
| 1 | `background_workers/16_dbo.ETB2_PAB_EventLedger_v1.sql` | Event ledger for audit tracking |
| 2 | `background_workers/ETB2_Config_Active.sql` | Active configuration settings |
| 3 | `background_workers/ETB2_Config_Lead_Times.sql` | Lead time configuration |
| 4 | `background_workers/ETB2_Config_Part_Pooling.sql` | Part pooling configuration |
| 5 | `background_workers/ETB2_Demand_Cleaned_Base.sql` | Cleaned demand data foundation |
| 6 | `background_workers/ETB2_Inventory_WC_Batches.sql` | Work center batch processing |

---

### Phase 2: Campaign Views (Consumption)

Build on Phase 1 to provide campaign analytics.

| Order | View File | Purpose |
|-------|-----------|---------|
| 7 | `consumption/ETB2_Campaign_Normalized_Demand.sql` | Normalized demand per campaign |
| 8 | `consumption/ETB2_Campaign_Absorption_Capacity.sql` | Campaign absorption capacity analysis |
| 9 | `consumption/ETB2_Campaign_Collision_Buffer.sql` | Campaign collision buffer calculation |
| 10 | `consumption/ETB2_Campaign_Concurrency_Window.sql` | Campaign concurrency windows |
| 11 | `consumption/ETB2_Campaign_Model_Data_Gaps.sql` | Model data gap identification |
| 12 | `consumption/ETB2_Campaign_Risk_Adequacy.sql` | Campaign risk adequacy assessment |

---

### Phase 3: Inventory Views (Consumption)

Build on Phase 1 & 2 for inventory insights.

| Order | View File | Purpose |
|-------|-----------|---------|
| 13 | `consumption/ETB2_Inventory_Unified_Eligible.sql` | Unified eligible inventory |
| 14 | `consumption/ETB2_Inventory_Quarantine_Restricted.sql` | Quarantine and restricted inventory |

---

### Phase 4: Planning Views (Consumption)

Build on all previous phases for planning decisions.

| Order | View File | Purpose |
|-------|-----------|---------|
| 15 | `consumption/ETB2_Planning_Net_Requirements.sql` | Net requirements calculation |
| 16 | `consumption/ETB2_Planning_Stockout_Risk.sql` | Stockout risk analysis |
| 17 | `consumption/ETB2_Planning_Rebalancing_Opportunities.sql` | Rebalancing opportunity identification |

---

## Dependency Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           PHASE 1: FOUNDATION                               │
│  ┌─────────────────┐                                                        │
│  │ EventLedger     │◄──── Utility/Audit                                     │
│  └────────┬────────┘                                                        │
│           ▼                                                                  │
│  ┌─────────────────────────────────────────┐                                │
│  │ Config Views (Active, LeadTimes, Pooling)│◄──── Configuration Base       │
│  └────────┬────────────────────────────────┘                                │
│           ▼                                                                  │
│  ┌─────────────────────┐  ┌─────────────────────┐                          │
│  │ Demand_Cleaned_Base │  │ Inventory_WC_Batches│                          │
│  └──────────┬──────────┘  └─────────────────────┘                          │
└─────────────┼────────────────────────────────────────────────────────────────┘
              │                                  │
              ▼                                  ▼
┌─────────────┼────────────────────────────────────────────────────────────────┐
│                    PHASE 2: CAMPAIGN VIEWS                                  │
│  ┌──────────────────────────────────────────────────────────────────────┐   │
│  │ Campaign_Normalized_Demand → Absorption → Collision → Concurrency    │   │
│  │                                              → Model_Gaps → Risk      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────┼────────────────────────────────────────────┐
│                    PHASE 3: INVENTORY VIEWS                                 │
│  ┌──────────────────────────────────────┐                                  │
│  │ Inventory_Unified_Eligible           │                                  │
│  └──────────────────────────────────────┘                                  │
│  ┌──────────────────────────────────────┐                                  │
│  │ Inventory_Quarantine_Restricted      │                                  │
│  └──────────────────────────────────────┘                                  │
└─────────────────────────────────┬────────────────────────────────────────────┘
                                  │
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    PHASE 4: PLANNING VIEWS                                  │
│  ┌────────────────────────┐  ┌────────────────────┐  ┌───────────────────┐ │
│  │ Planning_Net_Reqs      │  │ Planning_Stockout  │  │ Planning_Rebalance│ │
│  └────────────────────────┘  └────────────────────┘  └───────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Rollback Order

If needed, rollback in reverse order:

1. Phase 4 Planning Views (17 → 15)
2. Phase 3 Inventory Views (14 → 13)
3. Phase 2 Campaign Views (12 → 7)
4. Phase 1 Foundation Views (6 → 1)
