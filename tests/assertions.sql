-- Violation Detection Queries for Existing Data
-- These queries should return NO ROWS if the views are correct
-- Any returned rows indicate failures

USE [MED]
GO

-- Test 1.1: Demands within window with WC inventory but not suppressed
SELECT 'FAILURE: Test 1.1 - Unsuppressed demand within window' AS Failure_Type,
       ORDERNUMBER, ITEMNMBR, Date_Expiry, Base_Demand, effective_demand, WC_Batch_ID
FROM Rolyat_WC_PAB_effective_demand
WHERE Date_Expiry BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
    AND WC_Batch_ID IS NOT NULL
    AND effective_demand = Base_Demand
    AND Base_Demand > 0

-- Test 1.2: Demands outside window incorrectly suppressed
SELECT 'FAILURE: Test 1.2 - Suppressed demand outside window' AS Failure_Type,
       ORDERNUMBER, ITEMNMBR, Date_Expiry, Base_Demand, effective_demand
FROM Rolyat_WC_PAB_effective_demand
WHERE Date_Expiry NOT BETWEEN DATEADD(DAY, -21, GETDATE()) AND DATEADD(DAY, 21, GETDATE())
    AND effective_demand < Base_Demand

-- Test 3.1: Incorrect degradation factors
SELECT 'FAILURE: Test 3.1 - Wrong degradation factor' AS Failure_Type,
       ORDERNUMBER, ITEMNMBR, WC_Age_Days, WC_Degradation_Factor
FROM Rolyat_WC_PAB_inventory_and_allocation
WHERE (WC_Age_Days <= 30 AND WC_Degradation_Factor != 1.00)
   OR (WC_Age_Days BETWEEN 31 AND 60 AND WC_Degradation_Factor != 0.75)
   OR (WC_Age_Days BETWEEN 61 AND 90 AND WC_Degradation_Factor != 0.50)
   OR (WC_Age_Days > 90 AND WC_Degradation_Factor != 0.00)

-- Test 4.1: Double allocation - allocated exceeds batch effective qty
SELECT 'FAILURE: Test 4.1 - Double allocation' AS Failure_Type,
       WC_Batch_ID, SUM(allocated) AS Total_Allocated, MAX(WC_Effective_Qty) AS Batch_Effective_Qty
FROM Rolyat_WC_PAB_inventory_and_allocation
WHERE WC_Batch_ID IS NOT NULL
GROUP BY WC_Batch_ID
HAVING SUM(allocated) > MAX(WC_Effective_Qty)

-- Test 5.1: Running balance anomalies (simplified check for sudden increases)
SELECT 'FAILURE: Test 5.1 - Balance anomaly' AS Failure_Type,
       ITEMNMBR, Date_Expiry, Adjusted_Running_Balance,
       LAG(Adjusted_Running_Balance) OVER (PARTITION BY ITEMNMBR ORDER BY Date_Expiry, ORDERNUMBER) AS Prev_Balance
FROM Rolyat_Final_Ledger
WHERE Adjusted_Running_Balance > LAG(Adjusted_Running_Balance) OVER (PARTITION BY ITEMNMBR ORDER BY Date_Expiry, ORDERNUMBER)
    AND LAG(Adjusted_Running_Balance) OVER (PARTITION BY ITEMNMBR ORDER BY Date_Expiry, ORDERNUMBER) IS NOT NULL

-- Test 6.1: Invalid stock-out signals
SELECT 'FAILURE: Test 6.1 - False negative balance' AS Failure_Type,
       Item_Number, Adjusted_Running_Balance, QTY_ON_HAND
FROM Rolyat_Intelligence
WHERE Record_Type = 'STOCK_OUT'
    AND Adjusted_Running_Balance < 0
    AND QTY_ON_HAND > 0

GO