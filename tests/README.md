# Unit Testing Framework for Rolyat Pipeline

This directory contains the complete unit testing framework for validating the Rolyat Stock-Out Intelligence Pipeline views.

## Overview

The testing framework uses **violation-detection queries** that identify failures by finding rows that violate expected behaviors. All tests are designed to run on existing data or synthetic test data.

## Test Files

| File | Description |
|------|-------------|
| `unit_tests.sql` | Comprehensive stored procedure with 25+ unit tests |
| `assertions.sql` | Standalone assertion queries for manual validation |
| `test_harness.sql` | Iterative test harness with synthetic data generation |
| `synthetic_data_generation.sql` | Synthetic demand/supply data generation |
| `generate_synthetic_bom_data.sql` | BOM-specific synthetic data |
| `run_all_bom_tests.sql` | BOM test execution procedure |
| `BOM_Event_Sequence_Validation.sql` | BOM sequence validation view |
| `BOM_Material_Balance_Test.sql` | BOM material balance test view |
| `Historical_Reconstruction_BOM.sql` | BOM historical reconstruction view |
| `Rolyat_BOM_Health_Monitor.sql` | BOM health monitoring view |

## Views Under Test

1. **dbo.Rolyat_Cleaned_Base_Demand_1** - Data cleansing + base demand calculation
2. **dbo.Rolyat_WC_Allocation_Effective_2** - WC allocation with FEFO logic
3. **dbo.Rolyat_Final_Ledger_3** - Running balance calculations
4. **dbo.Rolyat_Unit_Price_4** - Blended average cost
5. **dbo.Rolyat_WFQ_5** - WFQ/RMQTY inventory tracking
6. **dbo.Rolyat_StockOut_Analysis_v2** - Stock-out intelligence
7. **dbo.Rolyat_Rebalancing_Layer** - Rebalancing analysis
8. **dbo.Rolyat_WC_Inventory** - WC batch inventory
9. **dbo.Rolyat_Consumption_Detail_v1** - Detailed consumption
10. **dbo.Rolyat_Consumption_SSRS_v1** - SSRS reporting view

## Test Categories

### 1. Running Balance Tests
- Forecast Running Balance Identity
- ATP Running Balance Identity
- Adjusted Balance equals ATP Balance

### 2. Event Ordering Tests
- SortPriority not NULL
- SortPriority valid range (1-5)
- Beginning Balance has SortPriority = 1

### 3. Active Window Tests
- Active window flagging correctness (±21 days)
- IsActiveWindow is binary (0 or 1)

### 4. WC Allocation Tests
- Effective demand never exceeds base demand
- No suppression outside active window
- No double allocation
- Allocation status consistency
- Degradation factor valid range (0-1)

### 5. Supply Event Tests
- Forecast supply non-negative
- ATP supply non-negative
- ATP supply ≤ Forecast supply (conservative)

### 6. Stock-Out Intelligence Tests
- Stock_Out_Flag consistency
- Action tag validity
- Deficit calculation correctness
- QC review condition

### 7. Data Integrity Tests
- No NULL ITEMNMBR
- No NULL ORDERNUMBER
- Valid Date_Expiry
- Base_Demand non-negative
- Excluded item prefixes filtered

### 8. Edge Case Tests
- WFQ eligibility flag consistency
- WC inventory positive quantity
- WC allocation applied flag consistency

## How to Run Tests

### Prerequisites

- SQL Server with MED database
- Views deployed in correct order
- Test schema created: `CREATE SCHEMA tests;`

### Run All Unit Tests

```sql
-- Execute comprehensive unit test suite
EXEC tests.sp_run_unit_tests;
```

**Output:**
- Detailed results per test
- Summary by category
- Overall pass percentage

### Run Iterative Test Harness

```sql
-- Run up to 25 iterations with synthetic data
EXEC tests.sp_run_test_iterations 
    @max_iterations = 25, 
    @seed_start = 1000,
    @target_pass_percentage = 100.0;
```

**Features:**
- Generates synthetic data per iteration
- Logs results to `tests.TestIterationLog`
- Stops on 100% pass rate
- Generates readout on success or diagnostics on failure

### Run Quick Single Test

```sql
-- Quick test with specific seed
EXEC tests.sp_quick_test @seed = 1000;
```

### Run Standalone Assertions

Execute queries from `assertions.sql` individually:

```sql
-- Each query should return 0 rows for PASS
-- Example: Test 1.1 - Unsuppressed demand within window
SELECT 'FAILURE: Test 1.1' AS Failure_Type, ...
FROM dbo.Rolyat_WC_Allocation_Effective_2
WHERE ...;
```

### Run BOM Tests

```sql
-- Execute BOM test suite
EXEC tests.sp_run_bom_tests;
```

## Interpreting Results

### Unit Test Results

| Result | Meaning |
|--------|---------|
| PASS | Test assertion validated successfully |
| FAIL | Test found violations - review `rows_affected` and `message` |

### Pass Criteria

- **100% Pass Rate**: All tests pass - ready for deployment
- **<100% Pass Rate**: Review failures before deployment

### Failure Investigation

1. Check `message` column for failure details
2. Check `rows_affected` for violation count
3. Run corresponding assertion query for sample data
4. Review view logic against test expectations

## Test Harness Logging

Test iterations are logged to `tests.TestIterationLog`:

```sql
SELECT * FROM tests.TestIterationLog ORDER BY iteration_id DESC;
```

| Column | Description |
|--------|-------------|
| iteration_id | Unique iteration identifier |
| timestamp | Execution timestamp |
| seed | Random seed used |
| scenario | Test scenario name |
| total_tests | Number of tests executed |
| passed_tests | Number of tests passed |
| pass_percentage | Pass rate percentage |
| status | SUCCESS, FAILED, TIMEOUT, ERROR |
| diagnostics | Failure details |

## Synthetic Data Generation

### Generate Demand/Supply Data

```sql
EXEC stg.sp_generate_synthetic 
    @seed = 1000, 
    @scenario = 'DEFAULT', 
    @scale_factor = 1;
```

### Generate BOM Data

```sql
EXEC stg.sp_generate_synthetic_bom 
    @seed = 1000, 
    @scenario = 'DEFAULT', 
    @scale_factor = 1;
```

### Staging Tables

| Table | Description |
|-------|-------------|
| `stg.Synthetic_Demand` | Demand events |
| `stg.Synthetic_PO` | Purchase orders |
| `stg.Synthetic_WFQ` | WFQ inventory |
| `stg.Synthetic_RMQTY` | RMQTY inventory |
| `stg.Synthetic_BeginningBalance` | Beginning balances |
| `stg.BOM_Hierarchy` | BOM structure |
| `stg.BOM_Events_Test` | BOM events |

## Adding New Tests

### To Unit Test Suite

1. Add test logic to `tests.sp_run_unit_tests`
2. Follow pattern:
   ```sql
   SET @start_time = GETDATE();
   SELECT @mismatches = COUNT(*) FROM ... WHERE <violation_condition>;
   
   INSERT INTO #TestResults (test_category, test_name, pass, message, rows_affected, execution_time_ms)
   VALUES (
       'Category',
       'test_name',
       CASE WHEN @mismatches = 0 THEN 1 ELSE 0 END,
       CASE WHEN @mismatches = 0 THEN 'Success message' ELSE 'Failure message' END,
       @mismatches,
       DATEDIFF(MILLISECOND, @start_time, GETDATE())
   );
   ```

### To Assertions

1. Add query to `assertions.sql`
2. Follow pattern:
   ```sql
   SELECT 'FAILURE: Test X.X - Description' AS Failure_Type, columns...
   FROM view
   WHERE <violation_condition>;
   ```

## Maintenance

### When Views Change

1. Review test logic for compatibility
2. Update column references if renamed
3. Add tests for new functionality
4. Re-run full test suite

### Performance Considerations

- Tests use efficient queries with appropriate indexes
- Run during low-traffic periods for large datasets
- Monitor `execution_time_ms` for slow tests

## Troubleshooting

### Common Issues

**"Object not found"**
- Ensure views are deployed in correct order
- Check schema names (dbo vs tests)

**"Permission denied"**
- Grant EXECUTE on test procedures
- Grant SELECT on views

**Tests timing out**
- Reduce `@max_time_per_iteration`
- Check for missing indexes
- Review execution plans

### Getting Help

1. Run diagnostics: `EXEC tests.sp_generate_diagnostics;`
2. Check iteration log: `SELECT * FROM tests.TestIterationLog;`
3. Review specific test failures in detail

---

*Last Updated: 2026-01-16*
