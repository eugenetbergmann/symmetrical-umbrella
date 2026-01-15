CREATE VIEW dbo.Rolyat_WC_Allocation_Effective_2
AS
WITH WC_With_Degradation AS (
    -- Apply age-based degradation factors to WC batches
    SELECT
        wc.*,
        -- Calculate degradation factor based on configurable age tiers
        CASE
            WHEN wc.Batch_Age_Days <= CAST(dbo.fn_GetConfig(wc.ITEMNMBR, wc.Client_ID, 'Degradation_Tier1_Days', GETDATE()) AS int)
                THEN CAST(dbo.fn_GetConfig(wc.ITEMNMBR, wc.Client_ID, 'Degradation_Tier1_Factor', GETDATE()) AS decimal(5,2))
            WHEN wc.Batch_Age_Days <= CAST(dbo.fn_GetConfig(wc.ITEMNMBR, wc.Client_ID, 'Degradation_Tier2_Days', GETDATE()) AS int)
                THEN CAST(dbo.fn_GetConfig(wc.ITEMNMBR, wc.Client_ID, 'Degradation_Tier2_Factor', GETDATE()) AS decimal(5,2))
            WHEN wc.Batch_Age_Days <= CAST(dbo.fn_GetConfig(wc.ITEMNMBR, wc.Client_ID, 'Degradation_Tier3_Days', GETDATE()) AS int)
                THEN CAST(dbo.fn_GetConfig(wc.ITEMNMBR, wc.Client_ID, 'Degradation_Tier3_Factor', GETDATE()) AS decimal(5,2))
            ELSE CAST(dbo.fn_GetConfig(wc.ITEMNMBR, wc.Client_ID, 'Degradation_Tier4_Factor', GETDATE()) AS decimal(5,2))
        END AS Degradation_Factor
    FROM dbo.Rolyat_WC_Inventory wc
),

WC_Effective_Qty AS (
    -- Calculate effective quantity after degradation
    SELECT
        *,
        Available_Qty * Degradation_Factor AS Effective_Batch_Qty
    FROM WC_With_Degradation
),

Demand_WC_Eligible AS (
    -- Match demand to eligible WC batches (client/site match, within active window)
    SELECT
        demand.*,
        wc.WC_Batch_ID,
        wc.Available_Qty AS WC_Available_Qty,
        wc.Batch_Expiry_Date,
        wc.Batch_Receipt_Date,
        wc.Batch_Age_Days,
        wc.Degradation_Factor,
        wc.Effective_Batch_Qty,

        -- FEFO ordering: earliest expiry, then closest temporal proximity
        ROW_NUMBER() OVER (
            PARTITION BY demand.ITEMNMBR, demand.ORDERNUMBER
            ORDER BY
                wc.Batch_Expiry_Date ASC,
                ABS(DATEDIFF(day, wc.Batch_Receipt_Date, demand.DUEDATE)) ASC
        ) AS FEFO_Priority

    FROM dbo.Rolyat_Cleaned_Base_Demand_1 demand
    LEFT JOIN WC_Effective_Qty wc
        ON wc.ITEMNMBR = demand.ITEMNMBR
        AND wc.Client_ID = demand.Client_ID  -- Client match
        AND wc.Site_ID = demand.Site_ID      -- Site match
        AND wc.Effective_Batch_Qty > 0
        AND demand.IsActiveWindow = 1        -- Only allocate within active window
),

Cumulative_WC_Allocation AS (
    -- Calculate cumulative WC availability per demand using window function
    SELECT
        *,
        SUM(Effective_Batch_Qty) OVER (
            PARTITION BY ITEMNMBR, ORDERNUMBER
            ORDER BY FEFO_Priority
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Cumulative_WC_Available
    FROM Demand_WC_Eligible
),

Final_Allocation AS (
    -- Pick single row per demand with total cumulative WC available
    SELECT
        ORDERNUMBER,
        ITEMNMBR,
        Client_ID,
        Site_ID,
        DUEDATE,
        Date_Expiry,
        Base_Demand,
        IsActiveWindow,
        SortPriority,
        Row_Type,

        -- WC allocation details (from first/best FEFO batch)
        WC_Batch_ID,
        Degradation_Factor,

        -- Total WC available after cumulative FEFO allocation
        MAX(Cumulative_WC_Available) AS Total_WC_Available,

        -- Calculate effective demand after WC suppression
        CASE
            WHEN IsActiveWindow = 1
            THEN GREATEST(0, Base_Demand - MAX(Cumulative_WC_Available))
            ELSE Base_Demand  -- No suppression outside active window
        END AS effective_demand,

        -- Allocation status flags
        CASE
            WHEN IsActiveWindow = 1 AND MAX(Cumulative_WC_Available) > 0
            THEN 'WC_ALLOCATED'
            WHEN IsActiveWindow = 1 AND MAX(Cumulative_WC_Available) = 0
            THEN 'NO_WC_AVAILABLE'
            ELSE 'OUTSIDE_WINDOW'
        END AS Allocation_Status,

        CASE
            WHEN IsActiveWindow = 1
             AND Base_Demand > 0
             AND MAX(Cumulative_WC_Available) >= Base_Demand
            THEN 'FULLY_COVERED'
            WHEN IsActiveWindow = 1
             AND Base_Demand > 0
             AND MAX(Cumulative_WC_Available) > 0
             AND MAX(Cumulative_WC_Available) < Base_Demand
            THEN 'PARTIALLY_COVERED'
            ELSE 'NOT_COVERED'
        END AS WC_Coverage_Status,

        -- Pass through all other demand columns
        ItemDescription,
        UOMSCHDL,
        Status_Description,
        MRPTYPE,
        VendorItem,
        INCLUDE_MRP,
        BEG_BAL,
        Item_Lead_Time_Days,
        Item_Safety_Stock,
        ORDER_POINT_QTY,
        PLANNING_LT,
        PRIME_VNDR,
        Original_Deductions,
        Original_Expiry,
        Original_POs,
        Original_Running_Balance,
        MRP_IssueDate,
        WCID_From_MO,
        MRP_Issued_Qty,
        MRP_Remaining_Qty,
        Has_Issued,
        IssueDate_Mismatch,
        Early_Issue_Flag

    FROM Cumulative_WC_Allocation
    GROUP BY
        ORDERNUMBER, ITEMNMBR, Client_ID, Site_ID, DUEDATE, Date_Expiry,
        Base_Demand, IsActiveWindow, SortPriority, Row_Type,
        WC_Batch_ID, Degradation_Factor,
        ItemDescription, UOMSCHDL, Status_Description, MRPTYPE, VendorItem,
        INCLUDE_MRP, BEG_BAL, Item_Lead_Time_Days, Item_Safety_Stock,
        ORDER_POINT_QTY, PLANNING_LT, PRIME_VNDR,
        Original_Deductions, Original_Expiry, Original_POs, Original_Running_Balance,
        MRP_IssueDate, WCID_From_MO, MRP_Issued_Qty, MRP_Remaining_Qty,
        Has_Issued, IssueDate_Mismatch, Early_Issue_Flag
)

SELECT * FROM Final_Allocation

GO
