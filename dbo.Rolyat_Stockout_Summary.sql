SELECT
    ITEMNMBR,
    SITE,
    FG,
    FG_Desc,
    ItemDescription,
    SAFETY_STOCK,
    WF_Q,
    COUNT(*) AS Total_Rows,
    COUNT(CASE WHEN Adjusted_Running_Balance + WF_Q < 0 THEN 1 END) AS Stockout_Count,
    COUNT(CASE WHEN Adjusted_Running_Balance + WF_Q < SAFETY_STOCK AND Adjusted_Running_Balance + WF_Q >= 0 THEN 1 END) AS Deficit_Count,
    COUNT(CASE WHEN Adjusted_Running_Balance + WF_Q >= SAFETY_STOCK THEN 1 END) AS Healthy_Count,
    MIN(Adjusted_Running_Balance) AS Min_Adjusted_Balance,
    MAX(Adjusted_Running_Balance) AS Max_Adjusted_Balance,
    AVG(Adjusted_Running_Balance) AS Avg_Adjusted_Balance,
    MIN(Adjusted_Running_Balance + WF_Q) AS Min_Adjusted_Balance_With_WFQ,
    MAX(Adjusted_Running_Balance + WF_Q) AS Max_Adjusted_Balance_With_WFQ,
    AVG(Adjusted_Running_Balance + WF_Q) AS Avg_Adjusted_Balance_With_WFQ,
    SUM(CASE WHEN Adjusted_Running_Balance + WF_Q < 0 THEN ABS(Adjusted_Running_Balance + WF_Q) ELSE 0 END) AS Total_Stockout_Quantity,
    SUM(CASE WHEN Adjusted_Running_Balance + WF_Q < SAFETY_STOCK AND Adjusted_Running_Balance + WF_Q >= 0 THEN SAFETY_STOCK - (Adjusted_Running_Balance + WF_Q) ELSE 0 END) AS Total_Deficit_Quantity,
    MAX(CASE WHEN QC_Flag = 'REVIEW_NO_WC_AVAILABLE' THEN 1 ELSE 0 END) AS Has_WC_Bottleneck,
    MAX(CASE WHEN IssueDate_Mismatch = 'YES' OR Early_Issue_Flag = 'YES' THEN 1 ELSE 0 END) AS Has_Timing_Issue
FROM dbo.Rolyat_Final_Ledger_3
GROUP BY
    ITEMNMBR,
    SITE,
    FG,
    FG_Desc,
    ItemDescription,
    SAFETY_STOCK,
    WF_Q
ORDER BY
    Stockout_Count DESC,
    Deficit_Count DESC,
    ITEMNMBR