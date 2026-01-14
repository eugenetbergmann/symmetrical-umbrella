# Unit Test Scenarios for Rolyat WC-Adjusted PAB & Stock-Out Intelligence

## 1. WC Demand Deprecation

### Scenario 1.1: Valid WC Inventory Reduces Demand Within Window
- **View**: Rolyat_WC_PAB_effective_demand
- **Setup**: Demand with Date_Expiry = GETDATE() + 10 days, Base_Demand = 100. WC inventory available, unexpired, within 21 days, effective qty = 50.
- **Expected**: effective_demand = 50, wc_allocation_status = 'WC_Suppressed'
- **Assertion Query**:
```sql
SELECT effective_demand, wc_allocation_status
FROM Rolyat_WC_PAB_effective_demand
WHERE ITEMNMBR = 'TEST_ITEM' AND ORDERNUMBER = 'TEST_ORDER'
-- Expected: effective_demand = 50, status = 'WC_Suppressed'
```

### Scenario 1.2: WC Inventory Does Not Reduce Demand Outside Window
- **View**: Rolyat_WC_PAB_effective_demand
- **Setup**: Demand with Date_Expiry = GETDATE() + 25 days, Base_Demand = 100. WC inventory available.
- **Expected**: effective_demand = 100, wc_allocation_status = 'Outside_Active_Window'
- **Assertion Query**:
```sql
SELECT effective_demand, wc_allocation_status
FROM Rolyat_WC_PAB_effective_demand
WHERE ITEMNMBR = 'TEST_ITEM' AND ORDERNUMBER = 'TEST_ORDER2'
-- Expected: effective_demand = 100, status = 'Outside_Active_Window'
```

## 2. Active Planning Window Enforcement

### Scenario 2.1: Edge at -21 Days
- **View**: Rolyat_WC_PAB_effective_demand
- **Setup**: Date_Expiry = GETDATE() - 21 days
- **Expected**: effective_demand = Base_Demand (no suppression)

### Scenario 2.2: Edge at +21 Days
- **Setup**: Date_Expiry = GETDATE() + 21 days
- **Expected**: effective_demand = Base_Demand (no suppression)

## 3. Inventory Age & Degradation Accuracy

### Scenario 3.1: Age 15 Days (100% Degradation)
- **View**: Rolyat_WC_PAB_with_prioritized_inventory
- **Setup**: WC inventory received 15 days ago
- **Expected**: WC_Degradation_Factor = 1.00

### Scenario 3.2: Age 45 Days (75% Degradation)
- **Setup**: Received 45 days ago
- **Expected**: WC_Degradation_Factor = 0.75

### Scenario 3.3: Age 95 Days (0% Degradation)
- **Setup**: Received 95 days ago
- **Expected**: WC_Effective_Qty = 0

## 4. No Double Allocation

### Scenario 4.1: Single Lot Covers Multiple Demands
- **View**: Rolyat_WC_PAB_with_allocation
- **Setup**: One WC lot with qty 100, two demands of 60 each
- **Expected**: Total allocated <= 100

## 5. Running Balance Correctness

### Scenario 5.1: Balance Monotonic
- **View**: Rolyat_Final_Ledger
- **Setup**: Multiple rows per item
- **Expected**: Adjusted_Running_Balance decreases or stays, no sudden jumps

## 6. Stale Demand Suppression

### Scenario 6.1: Demand After Inventory Arrival
- **Setup**: Inventory arrives before demand date
- **Expected**: Demand suppressed only once

## 7. Stock-Out Intelligence

### Scenario 7.1: Real Deficit
- **View**: Rolyat_StockOut_Analysis_v2
- **Setup**: Adjusted_Running_Balance < 0, no WC or WFQ coverage
- **Expected**: Coverage_Classification = 'NONE', Action_Priority = 'URGENT_PURCHASE'