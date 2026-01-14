# Unit Testing Framework for Rolyat WC-Adjusted PAB & Stock-Out Intelligence

This directory contains the complete unit testing framework for validating the 5 merged SQL views on existing production data.

## Overview

The testing framework uses **violation-detection queries** that identify failures by finding rows that violate expected behaviors. All tests are designed to run on existing data in `ETB_PAB_AUTO` and `ETB_WC_INV` tables without requiring synthetic data insertion.

## Files in This Directory

- **`assertions.sql`** - SQL queries for each unit test (violation detection)
- **`test_scenarios.md`** - Detailed description of each test scenario
- **`test_criteria.md`** - Pass/fail criteria for interpreting test results
- **`README.md`** - This file with execution instructions

## Views Under Test

1. **dbo.Rolyat_Cleaned_Base_Demand_1** - Data cleansing + base demand calculation (from `dbo.Rolyat_Cleaned_Base_Demand_1.sql`)
2. **dbo.Rolyat_WC_Allocation_Effective_Demand_2** - Inventory matching, allocation logic, effective demand + window enforcement (from `dbo.Rolyat_WC_Allocation_Effective_Demand_2.sql`)
3. **dbo.Rolyat_Final_Ledger_3** - Running balance + status flags (from `dbo.Rolyat_Final_Ledger_3.sql`)
4. **dbo.Rolyat_Unit_Price_4** - Blended average cost calculation (from `dbo.Rolyat_Unit_Price_4.sql`)
5. **dbo.Rolyat_WFQ_5** - WF-Q inventory on hand (from `dbo.Rolyat_WFQ_5.sql`)

## How to Run the Unit Tests

### Prerequisites
- Access to SQL Server with the MED database
- The 5 views must be deployed as named views (with numbered suffixes)
- Existing data in `ETB_PAB_AUTO`, `ETB_WC_INV`, `IV00300`, and `IV00101` tables

### Execution Steps

1. **Open SQL Studio** and connect to the MED database
2. **Deploy the views** if not already done (wrap each SELECT in CREATE VIEW):
   - Run `dbo.Rolyat_Cleaned_Base_Demand_1.sql` as `CREATE VIEW dbo.Rolyat_Cleaned_Base_Demand_1 AS ...`
   - Run `dbo.Rolyat_WC_Allocation_Effective_Demand_2.sql` as `CREATE VIEW dbo.Rolyat_WC_Allocation_Effective_Demand_2 AS ...`
   - Run `dbo.Rolyat_Final_Ledger_3.sql` as `CREATE VIEW dbo.Rolyat_Final_Ledger_3 AS ...`
   - Run `dbo.Rolyat_Unit_Price_4.sql` as `CREATE VIEW dbo.Rolyat_Unit_Price_4 AS ...`
   - Run `dbo.Rolyat_WFQ_5.sql` as `CREATE VIEW dbo.Rolyat_WFQ_5 AS ...`

3. **Execute the test queries** from `assertions.sql` in order:
   - Test 1.1: WC Demand Deprecation - Valid Reduction
   - Test 1.2: WC Demand Deprecation - No Reduction Outside Window
   - Test 3.1: Inventory Degradation Factors
   - Test 4.1: No Double Allocation
   - Test 5.1: Running Balance Correctness
   - Test 6.1: Intelligence - Valid Stock-Out Signals

4. **Interpret Results:**
   - **PASS**: Query returns 0 rows (no violations found)
   - **FAIL**: Query returns ≥1 rows (violations detected)

### Expected Results

All tests should return **0 rows** for a complete PASS. If any test returns rows, examine the data to identify the specific failure and determine if it's a data issue or logic bug.

## Test Coverage

The tests validate:
- ✅ WC inventory correctly suppresses demand within ±21 day window
- ✅ Demand is not suppressed outside active planning window
- ✅ Inventory degradation factors are calculated correctly by age
- ✅ No inventory is double-allocated across demands
- ✅ Running balances are calculated correctly without inflation
- ✅ Stock-out signals correspond to real deficits

## Troubleshooting

### Common Issues
- **Views not found**: Ensure all 5 views are deployed in the correct order with correct names:
  - `dbo.Rolyat_Cleaned_Base_Demand_1`
  - `dbo.Rolyat_WC_Allocation_Effective_Demand_2`
  - `dbo.Rolyat_Final_Ledger_3`
  - `dbo.Rolyat_Unit_Price_4`
  - `dbo.Rolyat_WFQ_5`
- **Permission errors**: Ensure SELECT access to the views and base tables
- **Unexpected failures**: Check `test_criteria.md` for detailed pass/fail criteria

### Performance Considerations
- Tests are designed to be efficient on production data
- All queries use appropriate indexes and avoid full table scans
- Run during low-traffic periods if concerned about performance impact

## Maintenance

When views are updated:
1. Review `test_scenarios.md` to ensure test logic still applies
2. Update `assertions.sql` if view column names or logic changes
3. Update `test_criteria.md` if pass/fail conditions change
4. Re-run all tests to validate

## Support

For questions about test results or failures:
1. Refer to `test_criteria.md` for detailed criteria
2. Examine the returned rows for specific violation details
3. Check view logic against the PRD requirements
4. Document any confirmed logic bugs with minimal fix proposals