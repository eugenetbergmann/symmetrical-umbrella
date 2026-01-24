# ETB2_Presentation_Dashboard_v1 - Unified Dashboard Guide

## Overview

`dbo.ETB2_Presentation_Dashboard_v1` consolidates three separate dashboard views into a single intelligent view with audience-specific filtering. This eliminates duplicate risk scoring and action recommendation logic while providing flexible presentation layers for different stakeholders.

## Replaces

- **View 17**: `dbo.Rolyat_StockOut_Risk_Dashboard` (Executive risk overview)
- **View 18**: `dbo.Rolyat_Batch_Expiry_Risk_Dashboard` (Expiry risk tracking)
- **View 19**: `dbo.Rolyat_Supply_Planner_Action_List` (Planner action prioritization)

## Architecture

### Single Source of Truth

The unified view consolidates metrics from:
- `dbo.Rolyat_StockOut_Analysis_v2` - Stock-out analysis with ATP and alternate stock
- `dbo.ETB2_Inventory_Unified_v1` - Batch-level inventory with expiry tracking
- `dbo.Rolyat_PO_Detail` - Purchase order supply information
- `dbo.ETB2_PAB_EventLedger_v1` - Event ledger for PO tracking

### Filtering Strategy

The view uses `Dashboard_Type` column to segment data for different audiences:

| Dashboard_Type | Audience | Purpose | Filter |
|---|---|---|---|
| `STOCKOUT_RISK` | Executive | Risk overview | `WHERE Dashboard_Type = 'STOCKOUT_RISK'` |
| `BATCH_EXPIRY` | Inventory Manager | Batch-level expiry | `WHERE Dashboard_Type = 'BATCH_EXPIRY'` |
| `PLANNER_ACTIONS` | Supply Planner | Prioritized actions | `WHERE Dashboard_Type = 'PLANNER_ACTIONS'` |

## Usage Examples

### Executive Dashboard (Stock-Out Risk)

```sql
SELECT 
  Item_Number,
  Client_ID,
  Current_ATP_Balance,
  Risk_Level,
  Recommended_Action,
  Available_Alternate_Stock_Qty,
  Forecast_Balance_Before_Allocation,
  Action_Priority
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'STOCKOUT_RISK'
ORDER BY Action_Priority, Item_Number;
```

**Output**: 8 columns max, executive-level visibility
- **Risk_Level**: CRITICAL_STOCKOUT, HIGH_RISK, MEDIUM_RISK, HEALTHY
- **Recommended_Action**: URGENT_PURCHASE, EXPEDITE_OPEN_POS, TRANSFER_FROM_OTHER_SITES, MONITOR
- **Action_Priority**: 1 (most urgent) to 4 (least urgent)

### Inventory Manager Dashboard (Batch Expiry)

```sql
SELECT 
  Item_Number,
  Site_ID,
  Batch_ID,
  Batch_Type,
  Batch_Qty,
  Days_Until_Expiry,
  Expiry_Risk_Tier,
  Recommended_Action,
  Business_Impact
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'BATCH_EXPIRY'
ORDER BY Days_Until_Expiry, Item_Number;
```

**Output**: 10 columns max, batch-level visibility
- **Batch_Type**: WC_BATCH, WFQ_BATCH, RMQTY_BATCH
- **Expiry_Risk_Tier**: EXPIRED, CRITICAL (≤30 days), HIGH (≤60 days), MEDIUM (≤90 days), LOW
- **Recommended_Action**: USE_FIRST, RELEASE_AFTER_HOLD, HOLD_IN_WFQ, HOLD_IN_RMQTY

### Supply Planner Dashboard (Action List)

```sql
SELECT 
  Item_Number,
  Client_ID,
  Current_ATP_Balance,
  Risk_Level,
  Recommended_Action,
  Days_Until_Expiry,
  Batch_ID,
  Business_Impact,
  Action_Priority
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'PLANNER_ACTIONS'
ORDER BY Action_Priority, Item_Number;
```

**Output**: 7 columns max, prioritized action list
- **Action_Priority**: 1 (Critical stock-outs) → 2 (High risk) → 3 (Critical expiry) → 4 (Past due POs)
- **Business_Impact**: HIGH, MEDIUM, LOW
- **Risk_Level**: CRITICAL_STOCKOUT, HIGH_RISK_STOCK, CRITICAL_EXPIRY, PAST_DUE_PO

## Risk Scoring Logic

### Stock-Out Risk Levels

| ATP Balance | Risk_Level | Recommended_Action |
|---|---|---|
| ≤ 0 | CRITICAL_STOCKOUT | URGENT_PURCHASE |
| 1-49 | HIGH_RISK | EXPEDITE_OPEN_POS |
| 50-99 | MEDIUM_RISK | TRANSFER_FROM_OTHER_SITES |
| ≥ 100 | HEALTHY | MONITOR |

### Expiry Risk Tiers

| Days Until Expiry | Expiry_Risk_Tier | Recommended_Disposition |
|---|---|---|
| < 0 | EXPIRED | Immediate action |
| 0-30 | CRITICAL | USE_FIRST (WC), RELEASE_AFTER_HOLD (WFQ/RMQTY) |
| 31-60 | HIGH | HOLD_IN_WFQ/RMQTY |
| 61-90 | MEDIUM | Monitor |
| > 90 | LOW | Standard allocation |

### Planner Action Priorities

| Priority | Condition | Action |
|---|---|---|
| 1 | ATP ≤ 0 | URGENT_PURCHASE |
| 2 | ATP 1-49 | EXPEDITE_OPEN_POS |
| 3 | Expiry 0-30 days | USE_FIRST |
| 4 | PO due date < TODAY | FOLLOW_UP |

## Column Reference

### Common Columns (All Dashboard Types)

| Column | Type | Description |
|---|---|---|
| `Dashboard_Type` | VARCHAR | STOCKOUT_RISK, BATCH_EXPIRY, PLANNER_ACTIONS |
| `Display_Priority` | INT | 1 (STOCKOUT), 2 (BATCH_EXPIRY), 3 (PLANNER_ACTIONS) |
| `Item_Number` | VARCHAR | Item identifier |
| `Client_ID` | VARCHAR | Client identifier (NULL for some types) |
| `Site_ID` | VARCHAR | Site/location identifier |
| `Current_ATP_Balance` | DECIMAL | Available quantity |
| `Risk_Level` | VARCHAR | Risk categorization |
| `Recommended_Action` | VARCHAR | Action guidance |
| `Action_Priority` | INT | 1 (most urgent) to 4 (least urgent) |

### Stock-Out Specific Columns

| Column | Type | Description |
|---|---|---|
| `Available_Alternate_Stock_Qty` | DECIMAL | WFQ + RMQTY quantities |
| `Forecast_Balance_Before_Allocation` | DECIMAL | Balance before batch constraints |
| `WFQ_QTY` | DECIMAL | Quarantine hold quantity |
| `RMQTY_QTY` | DECIMAL | Restricted material quantity |

### Batch Expiry Specific Columns

| Column | Type | Description |
|---|---|---|
| `Batch_ID` | VARCHAR | Unique batch identifier |
| `Batch_Type` | VARCHAR | WC_BATCH, WFQ_BATCH, RMQTY_BATCH |
| `Days_Until_Expiry` | INT | Days remaining before expiry |
| `Expiry_Risk_Tier` | VARCHAR | EXPIRED, CRITICAL, HIGH, MEDIUM, LOW |
| `Batch_Qty` | DECIMAL | Quantity in batch |
| `Business_Impact` | VARCHAR | HIGH, MEDIUM, LOW |

## Performance Considerations

### Indexing Strategy

Recommended indexes for optimal query performance:

```sql
-- Stock-out risk queries
CREATE INDEX idx_Dashboard_Type_StockOut 
  ON dbo.ETB2_Presentation_Dashboard_v1(Dashboard_Type, Action_Priority, Item_Number);

-- Batch expiry queries
CREATE INDEX idx_Dashboard_Type_Expiry 
  ON dbo.ETB2_Presentation_Dashboard_v1(Dashboard_Type, Days_Until_Expiry, Item_Number);

-- Planner action queries
CREATE INDEX idx_Dashboard_Type_Planner 
  ON dbo.ETB2_Presentation_Dashboard_v1(Dashboard_Type, Action_Priority, Item_Number);
```

### Query Optimization Tips

1. **Always filter by Dashboard_Type first** - This reduces result set significantly
2. **Use Action_Priority for sorting** - Avoids expensive ORDER BY operations
3. **Limit columns selected** - Only retrieve columns needed for display
4. **Consider materialized view** - For high-frequency queries, consider creating indexed view

## Migration Path

### From View 17 (StockOut_Risk_Dashboard)

**Old Query:**
```sql
SELECT * FROM dbo.Rolyat_StockOut_Risk_Dashboard;
```

**New Query:**
```sql
SELECT 
  Item_Number, Client_ID, Current_ATP_Balance, Risk_Level,
  Recommended_Action, Available_Alternate_Stock_Qty,
  Forecast_Balance_Before_Allocation
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'STOCKOUT_RISK'
ORDER BY Action_Priority, Item_Number;
```

### From View 18 (Batch_Expiry_Risk_Dashboard)

**Old Query:**
```sql
SELECT * FROM dbo.Rolyat_Batch_Expiry_Risk_Dashboard;
```

**New Query:**
```sql
SELECT 
  Batch_Type, Item_Number, Batch_ID, Client_ID, Batch_Qty,
  Expiry_Date, Days_Until_Expiry, Expiry_Risk_Tier,
  Recommended_Action, Site_ID
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'BATCH_EXPIRY'
ORDER BY Days_Until_Expiry, Item_Number;
```

### From View 19 (Supply_Planner_Action_List)

**Old Query:**
```sql
SELECT * FROM dbo.Rolyat_Supply_Planner_Action_List;
```

**New Query:**
```sql
SELECT 
  Action_Priority, Item_Number, Risk_Level, Recommended_Action,
  Current_ATP_Balance, Business_Impact, Client_ID
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'PLANNER_ACTIONS'
ORDER BY Action_Priority, Item_Number;
```

## Validation Queries

### Verify Data Completeness

```sql
-- Check row counts by dashboard type
SELECT 
  Dashboard_Type,
  COUNT(*) AS Row_Count,
  COUNT(DISTINCT Item_Number) AS Unique_Items,
  COUNT(DISTINCT Client_ID) AS Unique_Clients
FROM dbo.ETB2_Presentation_Dashboard_v1
GROUP BY Dashboard_Type;
```

### Verify Risk Scoring Consistency

```sql
-- Verify stock-out risk levels match ATP thresholds
SELECT 
  Item_Number,
  Current_ATP_Balance,
  Risk_Level,
  CASE 
    WHEN Current_ATP_Balance <= 0 THEN 'CRITICAL_STOCKOUT'
    WHEN Current_ATP_Balance < 50 THEN 'HIGH_RISK'
    WHEN Current_ATP_Balance < 100 THEN 'MEDIUM_RISK'
    ELSE 'HEALTHY'
  END AS Expected_Risk_Level,
  CASE 
    WHEN Risk_Level = CASE 
      WHEN Current_ATP_Balance <= 0 THEN 'CRITICAL_STOCKOUT'
      WHEN Current_ATP_Balance < 50 THEN 'HIGH_RISK'
      WHEN Current_ATP_Balance < 100 THEN 'MEDIUM_RISK'
      ELSE 'HEALTHY'
    END THEN 'VALID'
    ELSE 'INVALID'
  END AS Validation_Status
FROM dbo.ETB2_Presentation_Dashboard_v1
WHERE Dashboard_Type = 'STOCKOUT_RISK';
```

### Verify Action Priority Ordering

```sql
-- Verify action priorities are sequential and correct
SELECT 
  Dashboard_Type,
  Action_Priority,
  COUNT(*) AS Count,
  MIN(Item_Number) AS First_Item,
  MAX(Item_Number) AS Last_Item
FROM dbo.ETB2_Presentation_Dashboard_v1
GROUP BY Dashboard_Type, Action_Priority
ORDER BY Dashboard_Type, Action_Priority;
```

## Troubleshooting

### No Results for Dashboard_Type

**Issue**: Query returns no rows for specific Dashboard_Type

**Solution**:
1. Verify Dashboard_Type value is exact match (case-sensitive)
2. Check underlying source views have data
3. Verify WHERE clause filters are correct

### Inconsistent Risk Levels

**Issue**: Risk_Level doesn't match Current_ATP_Balance

**Solution**:
1. Run validation query above
2. Check if underlying data changed
3. Verify view definition hasn't been modified

### Performance Issues

**Issue**: Queries are slow

**Solution**:
1. Add recommended indexes
2. Filter by Dashboard_Type first
3. Consider materialized view for frequent queries
4. Check query execution plan

## Future Enhancements

1. **Materialized View**: Create indexed view for high-frequency queries
2. **Real-time Alerts**: Add trigger-based notifications for critical items
3. **Historical Tracking**: Archive daily snapshots for trend analysis
4. **Custom Thresholds**: Support client-specific risk thresholds
5. **Mobile Dashboard**: Create mobile-optimized view subset

## Support

For questions or issues with this view, refer to:
- View definition: `views/ETB2_Presentation_Dashboard_v1.sql`
- Dependency documentation: See individual view READMEs
- Validation tests: `validation/view_consolidation_validation.sql`
