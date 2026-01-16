/*
===============================================================================
Data Quality Checks: Rolyat Stock-Out Intelligence Pipeline v2.0
Description: Comprehensive data quality validation for pipeline integrity
Version: 2.0.0
Last Modified: 2026-01-16

Purpose:
  - Validate data integrity across all pipeline views
  - Check for null values in critical fields
  - Verify data type consistency and ranges
  - Ensure referential integrity where applicable

Execution:
  - Run after smoke test passes
  - Review results for data quality issues
===============================================================================
*/

-- Check 1: Null values in ITEMNMBR across all views
PRINT 'Checking for NULL ITEMNMBR values...';

SELECT 'Rolyat_Cleaned_Base_Demand_1' AS View_Name, COUNT(*) AS Null_Count
FROM dbo.Rolyat_Cleaned_Base_Demand_1
WHERE ITEMNMBR IS NULL
UNION ALL
SELECT 'Rolyat_WC_Inventory', COUNT(*)
FROM dbo.Rolyat_WC_Inventory
WHERE ITEMNMBR IS NULL
UNION ALL
SELECT 'Rolyat_WFQ_5', COUNT(*)
FROM dbo.Rolyat_WFQ_5
WHERE ITEMNMBR IS NULL
UNION ALL
SELECT 'Rolyat_WC_Allocation_Effective_2', COUNT(*)
FROM dbo.Rolyat_WC_Allocation_Effective_2
WHERE ITEMNMBR IS NULL
UNION ALL
SELECT 'Rolyat_Unit_Price_4', COUNT(*)
FROM dbo.Rolyat_Unit_Price_4
WHERE ITEMNMBR IS NULL
UNION ALL
SELECT 'Rolyat_Final_Ledger_3', COUNT(*)
FROM dbo.Rolyat_Final_Ledger_3
WHERE ITEMNMBR IS NULL
UNION ALL
SELECT 'Rolyat_StockOut_Analysis_v2', COUNT(*)
FROM dbo.Rolyat_StockOut_Analysis_v2
WHERE ITEMNMBR IS NULL
UNION ALL
SELECT 'Rolyat_Rebalancing_Layer', COUNT(*)
FROM dbo.Rolyat_Rebalancing_Layer
WHERE ITEMNMBR IS NULL;

-- Check 2: Invalid dates (future dates in past fields, etc.)
PRINT 'Checking for invalid date ranges...';

SELECT 'Rolyat_Cleaned_Base_Demand_1 - DUEDATE in future' AS Check_Name, COUNT(*) AS Issue_Count
FROM dbo.Rolyat_Cleaned_Base_Demand_1
WHERE DUEDATE > GETDATE()
UNION ALL
SELECT 'Rolyat_WC_Inventory - EXPIREDATE before today', COUNT(*)
FROM dbo.Rolyat_WC_Inventory
WHERE EXPIREDATE < GETDATE()
UNION ALL
SELECT 'Rolyat_Final_Ledger_3 - Negative ATP_Balance', COUNT(*)
FROM dbo.Rolyat_Final_Ledger_3
WHERE ATP_Balance < 0;

-- Check 3: Data type consistency (quantities should be positive)
PRINT 'Checking for invalid quantity values...';

SELECT 'Rolyat_WC_Inventory - Negative QTYONHND', COUNT(*)
FROM dbo.Rolyat_WC_Inventory
WHERE QTYONHND < 0
UNION ALL
SELECT 'Rolyat_Cleaned_Base_Demand_1 - Negative Base_Demand', COUNT(*)
FROM dbo.Rolyat_Cleaned_Base_Demand_1
WHERE Base_Demand < 0;

-- Check 4: SortPriority values (should be 1-4)
PRINT 'Checking SortPriority values...';

SELECT DISTINCT SortPriority, COUNT(*) AS Count
FROM dbo.Rolyat_Final_Ledger_3
WHERE SortPriority NOT IN (1, 2, 3, 4)
GROUP BY SortPriority;

PRINT 'Data quality checks completed. Review results above for issues.';