# BOM Event Ledger Testing Framework

This directory contains the BOM (Bill of Materials) Event Ledger Testing Framework for validating BOM events, sequencing, and material balances in the symmetrical-umbrella repository.

## Overview

The framework uses violation-detection views and procedures to ensure BOM integrity, similar to the existing Rolyat testing framework.

## Files in This Directory

- **BOM_Event_Sequence_Validation.sql** - View for enforcing monotonic event sequences
- **BOM_Material_Balance_Test.sql** - View for validating component consumption against BOM
- **Historical_Reconstruction_BOM.sql** - View for evaluating BOM accuracy via event replay
- **generate_synthetic_bom_data.sql** - Procedure for generating synthetic BOM hierarchies and events
- **run_all_bom_tests.sql** - Master procedure to run all BOM tests
- **Rolyat_BOM_Health_Monitor.sql** - View for real-time BOM health reports
- **bom_readme.md** - This file

## Views Under Test

1. **dbo.BOM_Event_Sequence_Validation** - Detects duplicates, gaps, non-monotonic sequences
2. **dbo.BOM_Material_Balance_Test** - Flags over-/under-consumption mismatches
3. **dbo.Historical_Reconstruction_BOM** - Validates quantity reconstructions
4. **dbo.Rolyat_BOM_Health_Monitor** - Aggregates violation counts with status

## How to Run the BOM Tests

1. Deploy the views by executing the .sql files
2. Generate synthetic data: `EXEC stg.sp_generate_synthetic_bom @seed = 1000, @scenario = 'BOM_TEST'`
3. Run tests: `EXEC tests.sp_run_bom_tests`
4. Check health: `SELECT * FROM dbo.Rolyat_BOM_Health_Monitor`

## Pass/Fail Criteria

- **PASS**: Views return 0 rows (no violations)
- **FAIL**: Views return ≥1 rows (violations detected)

## Assumptions

- Tables: BOM_Events, BOM, Production_Events, Component_Consumption, Inventory
- BOM structure: Parent_Item, Component_Item, Qty_Per
- Events: ITEMNMBR, Event_Sequence, Event_Date, Event_Type, Qty_Change

## Maintenance

Update views if BOM schema changes. Re-run tests after modifications.