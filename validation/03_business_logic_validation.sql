/*
===============================================================================
Business Logic Validation: Rolyat Stock-Out Intelligence Pipeline v2.0
Description: Validation of core business rules and ATP/Forecast logic
Version: 2.0.0
Last Modified: 2026-01-16

Purpose:
  - Verify ATP/Forecast separation logic
  - Confirm SortPriority enforcement and deterministic ordering
  - Validate stock-out prevention mechanisms
  - Check active window filtering

Execution:
  - Run after data quality checks pass
  - Critical for ensuring pipeline correctness
===============================================================================
*/

-- Check 1: ATP vs Forecast separation
PRINT 'Validating ATP/Forecast logic separation...';

-- ATP should exclude WFQ/RMQTY, Forecast should include
SELECT 'ATP Balance Check' AS Test_Name,
       SUM(CASE WHEN ATP_Balance < 0 THEN 1 ELSE 0 END) AS Negative_ATP_Count,
       COUNT(*) AS Total_Records
FROM dbo.Rolyat_Final_Ledger_3;

-- Check WFQ/RMQTY exclusion in ATP calculation
SELECT 'WFQ/RMQTY in ATP' AS Test_Name, COUNT(*) AS Records_With_WFQ_RMQTY_In_ATP
FROM dbo.Rolyat_Final_Ledger_3 fl
JOIN dbo.Rolyat_WFQ_5 wfq ON fl.ITEMNMBR = wfq.ITEMNMBR
WHERE fl.ATP_Balance > 0;  -- Should be minimal or zero

-- Check 2: SortPriority enforcement (deterministic ordering)
PRINT 'Validating SortPriority ordering...';

SELECT ITEMNMBR, MIN(SortPriority) AS Min_Sort, MAX(SortPriority) AS Max_Sort, COUNT(*) AS Record_Count
FROM dbo.Rolyat_Final_Ledger_3
GROUP BY ITEMNMBR
HAVING MIN(SortPriority) <> 1 OR MAX(SortPriority) > 4
ORDER BY ITEMNMBR;

-- Check 3: Active window filtering (ATP excludes old demand)
PRINT 'Validating active window filtering...';

DECLARE @ActiveWindowDays INT = (SELECT CAST(Config_Value AS INT) FROM dbo.Rolyat_Config_Global WHERE Config_Key = 'ActiveWindow_Past_Days');
SELECT 'Demand outside active window' AS Test_Name, COUNT(*) AS Outdated_Demand_Count
FROM dbo.Rolyat_Cleaned_Base_Demand_1
WHERE DATEDIFF(DAY, DUEDATE, GETDATE()) > @ActiveWindowDays;

-- Check 4: Stock-out analysis logic
PRINT 'Validating stock-out prevention logic...';

SELECT 'Stock-out candidates' AS Test_Name, COUNT(*) AS StockOut_Count
FROM dbo.Rolyat_StockOut_Analysis_v2
WHERE ATP_Balance <= 0 AND Forecast_Balance > 0;  -- Should trigger rebalancing

-- Check 5: Degradation factors application
PRINT 'Validating degradation logic...';

SELECT ITEMNMBR, SUM(Degraded_Qty) AS Total_Degraded, SUM(Usable_Qty) AS Total_Usable
FROM dbo.Rolyat_WC_Inventory
GROUP BY ITEMNMBR
HAVING SUM(Degraded_Qty) > SUM(Usable_Qty);  -- Warning if degraded > usable

PRINT 'Business logic validation completed. Review results for logic violations.';