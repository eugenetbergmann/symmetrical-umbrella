# Unit Test Pass/Fail Criteria for Rolyat WC-Adjusted PAB & Stock-Out Intelligence

This document defines the exact criteria for determining whether each unit test passes or fails. All tests are violation-detection queries that should return 0 rows for a PASS.

## Views Reference (with numbered suffixes)
- **dbo.Rolyat_Cleaned_Base_Demand_1** - Data cleansing + base demand (from `dbo.Rolyat_Cleaned_Base_Demand_1.sql`)
- **dbo.Rolyat_WC_Allocation_Effective_Demand_2** - Inventory matching, allocation, effective demand (from `dbo.Rolyat_WC_Allocation_Effective_Demand_2.sql`)
- **dbo.Rolyat_Final_Ledger_3** - Running balance + status flags (from `dbo.Rolyat_Final_Ledger_3.sql`)
- **dbo.Rolyat_Unit_Price_4** - Blended average cost (from `dbo.Rolyat_Unit_Price_4.sql`)
- **dbo.Rolyat_WFQ_5** - WF-Q inventory on hand (from `dbo.Rolyat_WFQ_5.sql`)

## 1. WC Demand Deprecation Tests

### Test 1.1: Demands within window with WC inventory but not suppressed
**View:** dbo.Rolyat_WC_Allocation_Effective_Demand_2
**PASS Criteria:** Query returns 0 rows
- No demand rows exist where:
  - Date_Expiry is within ±21 days of today
  - WC_Batch_ID is not null (WC inventory is available)
  - effective_demand equals Base_Demand (demand was not reduced)

**FAIL Criteria:** Query returns ≥1 rows
- Indicates WC inventory failed to suppress demand when it should have

### Test 1.2: Demands outside window incorrectly suppressed
**View:** dbo.Rolyat_WC_Allocation_Effective_Demand_2
**PASS Criteria:** Query returns 0 rows
- No demand rows exist where:
  - Date_Expiry is outside ±21 days of today
  - effective_demand is less than Base_Demand (demand was reduced when it shouldn't be)

**FAIL Criteria:** Query returns ≥1 rows
- Indicates demand was suppressed outside the active planning window

## 2. Active Planning Window Tests

### Test 2.1: Suppression outside ±21 days
**View:** dbo.Rolyat_WC_Allocation_Effective_Demand_2
**PASS Criteria:** Query returns 0 rows
- No rows exist where Date_Expiry is outside the window but wc_allocation_status != 'Outside_Active_Window'

**FAIL Criteria:** Query returns ≥1 rows
- Indicates incorrect allocation status for out-of-window demands

## 3. Inventory Age & Degradation Tests

### Test 3.1: Incorrect degradation factors
**View:** dbo.Rolyat_WC_Allocation_Effective_Demand_2
**PASS Criteria:** Query returns 0 rows
- No inventory rows exist where WC_Degradation_Factor doesn't match age rules:
  - 0-30 days: factor = 1.00
  - 31-60 days: factor = 0.75
  - 61-90 days: factor = 0.50
  - >90 days: factor = 0.00

**FAIL Criteria:** Query returns ≥1 rows
- Indicates age-based degradation calculation errors

## 4. No Double Allocation Tests

### Test 4.1: Allocated quantity exceeds batch effective qty
**View:** dbo.Rolyat_WC_Allocation_Effective_Demand_2
**PASS Criteria:** Query returns 0 rows
- No WC_Batch_ID groups exist where SUM(allocated) > MAX(WC_Effective_Qty)

**FAIL Criteria:** Query returns ≥1 rows
- Indicates inventory was over-allocated to demands (double-spent)

## 5. Running Balance Tests

### Test 5.1: Non-monotonic balance changes
**View:** dbo.Rolyat_Final_Ledger_3
**PASS Criteria:** Query returns 0 rows
- No balance rows exist where current balance > previous balance for the same item
- Balances should only decrease or stay the same over time

**FAIL Criteria:** Query returns ≥1 rows
- Indicates balance calculation errors causing unexpected increases

## 6. Intelligence Tests

### Test 6.1: Invalid stock-out signals
**Views:** dbo.Rolyat_Final_Ledger_3 joined with dbo.Rolyat_WFQ_5
**PASS Criteria:** Query returns 0 rows
- No DEMAND_EVENT records exist where:
  - Adjusted_Running_Balance < 0 (negative balance)
  - QTY_ON_HAND > 0 (inventory available to resolve)

**FAIL Criteria:** Query returns ≥1 rows
- Indicates false negative stock-out signals (deficits that could be resolved)

## General Test Execution Guidelines

- **Run Order:** Execute tests in numerical order (1.1 through 6.1)
- **Expected Result:** All queries should return 0 rows
- **Data Source:** Tests run on existing production data in ETB_PAB_AUTO and ETB_WC_INV
- **Performance:** Queries are designed to be efficient and safe for production databases
- **Interpretation:** Any returned rows represent specific failures with full context for debugging

## Failure Analysis Template

For any test that FAILs (returns rows):
1. Examine the returned data to identify the specific violation
2. Check the view logic implicated
3. Determine root cause (data issue vs. logic bug)
4. Propose minimal fix if logic error confirmed