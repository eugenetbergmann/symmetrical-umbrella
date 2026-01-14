# Violation Detection Tests for Rolyat WC-Adjusted PAB & Stock-Out Intelligence
# These queries run on existing data to detect failures in the 5 views

## Views Reference (with numbered suffixes)
- **dbo.Rolyat_Cleaned_Base_Demand_1** - Data cleansing + base demand (from `dbo.Rolyat_Cleaned_Base_Demand_1.sql`)
- **dbo.Rolyat_WC_Allocation_Effective_2** - Inventory matching, allocation, effective demand (from `dbo.Rolyat_WC_Allocation_Effective_2.sql`)
- **dbo.Rolyat_Final_Ledger_3** - Running balance + status flags (from `dbo.Rolyat_Final_Ledger_3.sql`)
- **dbo.Rolyat_Unit_Price_4** - Blended average cost (from `dbo.Rolyat_Unit_Price_4.sql`)
- **dbo.Rolyat_WFQ_5** - WF-Q inventory on hand (from `dbo.Rolyat_WFQ_5.sql`)

## 1. WC Demand Deprecation Violations

### Test 1.1: Demands within window with WC inventory but not suppressed
- **View**: dbo.Rolyat_WC_Allocation_Effective_2
- **Violation**: Rows where Date_Expiry within ±21 days, WC_Batch_ID exists, but effective_demand = Base_Demand
- **Query**: Returns rows that should be suppressed but aren't

### Test 1.2: Demands outside window incorrectly suppressed
- **View**: dbo.Rolyat_WC_Allocation_Effective_2
- **Violation**: Rows where Date_Expiry outside ±21 days, but effective_demand < Base_Demand
- **Query**: Returns rows incorrectly suppressed

## 2. Active Planning Window Violations

### Test 2.1: Suppression outside ±21 days
- **View**: dbo.Rolyat_WC_Allocation_Effective_2
- **Violation**: Any row with Date_Expiry outside window but wc_allocation_status != 'Outside_Active_Window'
- **Query**: Detects incorrect status

## 3. Inventory Age & Degradation Violations

### Test 3.1: Incorrect degradation factors
- **View**: dbo.Rolyat_WC_Allocation_Effective_2
- **Violation**: Rows where WC_Degradation_Factor doesn't match age rules
- **Query**: Checks factor accuracy

## 4. No Double Allocation Violations

### Test 4.1: Allocated quantity exceeds batch effective qty
- **View**: dbo.Rolyat_WC_Allocation_Effective_2
- **Violation**: Sum(allocated) per WC_Batch_ID > WC_Effective_Qty
- **Query**: Returns over-allocated batches

## 5. Running Balance Violations

### Test 5.1: Non-monotonic balance changes
- **View**: dbo.Rolyat_Final_Ledger_3
- **Violation**: Balance increases unexpectedly or duplicates
- **Query**: Detects balance anomalies per item

## 6. Intelligence Violations

### Test 6.1: Invalid stock-out signals
- **Views**: dbo.Rolyat_Final_Ledger_3 joined with dbo.Rolyat_WFQ_5
- **Violation**: DEMAND_EVENT records with negative balances that can be resolved by WFQ inventory
- **Query**: Finds false negatives