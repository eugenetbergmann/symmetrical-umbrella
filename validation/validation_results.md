# Rolyat Stock-Out Intelligence Pipeline Validation Results

**Validation Date:** YYYY-MM-DD  
**Pipeline Version:** 2.0.0  
**Environment:** [Production/Staging/Development]  
**Executed By:** [Your Name]  

## Executive Summary

[Brief summary of validation results - PASS/FAIL/WARNING]

## Test Results

### 1. Smoke Test (`01_smoke_test.sql`)
- **Status:** [PASS/FAIL]
- **Details:**
  - dbo.Rolyat_Cleaned_Base_Demand_1: [row count] rows
  - dbo.Rolyat_WC_Inventory: [row count] rows
  - dbo.Rolyat_WFQ_5: [row count] rows
  - dbo.Rolyat_WC_Allocation_Effective_2: [row count] rows
  - dbo.Rolyat_Unit_Price_4: [row count] rows
  - dbo.Rolyat_Final_Ledger_3: [row count] rows
  - dbo.Rolyat_StockOut_Analysis_v2: [row count] rows
  - dbo.Rolyat_Rebalancing_Layer: [row count] rows

### 2. Data Quality Checks (`02_data_quality_checks.sql`)
- **Status:** [PASS/FAIL]
- **Issues Found:**
  - [List any data quality issues with counts]

### 3. Business Logic Validation (`03_business_logic_validation.sql`)
- **Status:** [PASS/FAIL]
- **ATP/Forecast Logic:**
  - [Results of ATP/Forecast separation checks]
- **SortPriority Enforcement:**
  - [Results of ordering checks]
- **Active Window Filtering:**
  - [Results of window filtering validation]

### 4. Config Coverage Test (`04_config_coverage_test.sql`)
- **Status:** [PASS/FAIL]
- **Config Tables:**
  - Rolyat_Config_Global: [status]
  - Rolyat_Config_Clients: [status]
  - Rolyat_Config_Items: [status]
  - fn_GetConfig: [status]
- **Key Coverage:**
  - [List coverage of required config keys]

## Detailed Findings

[Section for detailed error messages, warnings, or additional observations]

## Recommendations

[Action items for any issues found]

## Sign-off

**Validated By:** ___________________________  
**Date:** ___________________________  
**Approval:** ___________________________