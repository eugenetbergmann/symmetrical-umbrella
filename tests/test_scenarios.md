# Violation Detection Tests for Rolyat WC-Adjusted PAB & Stock-Out Intelligence
# These queries run on existing data to detect failures in the views

## 1. WC Demand Deprecation Violations

### Test 1.1: Demands within window with WC inventory but not suppressed
- **View**: Rolyat_WC_PAB_effective_demand
- **Violation**: Rows where Date_Expiry within ±21 days, WC_Batch_ID exists, but effective_demand = Base_Demand
- **Query**: Returns rows that should be suppressed but aren't

### Test 1.2: Demands outside window incorrectly suppressed
- **View**: Rolyat_WC_PAB_effective_demand
- **Violation**: Rows where Date_Expiry outside ±21 days, but effective_demand < Base_Demand
- **Query**: Returns rows incorrectly suppressed

## 2. Active Planning Window Violations

### Test 2.1: Suppression outside ±21 days
- **Violation**: Any row with Date_Expiry outside window but wc_allocation_status != 'Outside_Active_Window'
- **Query**: Detects incorrect status

## 3. Inventory Age & Degradation Violations

### Test 3.1: Incorrect degradation factors
- **View**: Rolyat_WC_PAB_with_prioritized_inventory
- **Violation**: Rows where WC_Degradation_Factor doesn't match age rules
- **Query**: Checks factor accuracy

## 4. Double Allocation Violations

### Test 4.1: Allocated quantity exceeds batch effective qty
- **View**: Rolyat_WC_PAB_with_allocation
- **Violation**: Sum(allocated) per WC_Batch_ID > WC_Effective_Qty
- **Query**: Returns over-allocated batches

## 5. Running Balance Violations

### Test 5.1: Non-monotonic balance changes
- **View**: Rolyat_Final_Ledger
- **Violation**: Balance increases unexpectedly or duplicates
- **Query**: Detects balance anomalies per item

## 6. Stale Demand Suppression Violations

### Test 6.1: Demand suppressed multiple times
- **Violation**: Same demand event reducing inventory more than once
- **Query**: Checks for duplicate suppression

## 7. Stock-Out Intelligence Violations

### Test 7.1: Invalid negative balances
- **View**: Rolyat_StockOut_Analysis_v2
- **Violation**: Negative balances that can be resolved by available inventory
- **Query**: Finds false negatives