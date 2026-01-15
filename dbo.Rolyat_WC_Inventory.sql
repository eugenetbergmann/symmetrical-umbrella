CREATE VIEW dbo.Rolyat_WC_Inventory
AS
SELECT
    ITEMNMBR,
    Construct AS Client_ID,
    SITE AS Site_ID,
    WCID_From_MO AS WC_Batch_ID,
    MRP_Remaining_Qty AS Available_Qty,
    MRP_IssueDate AS Batch_Receipt_Date,

    -- Calculate expiry based on issue date + configurable shelf life
    DATEADD(day,
        CAST(dbo.fn_GetConfig(ITEMNMBR, Construct, 'WC_Batch_Shelf_Life_Days', GETDATE()) AS int),
        MRP_IssueDate
    ) AS Batch_Expiry_Date,

    -- Calculate age for degradation
    DATEDIFF(day, MRP_IssueDate, GETDATE()) AS Batch_Age_Days,

    -- Row type
    'WC_BATCH' AS Row_Type

FROM dbo.Rolyat_Cleaned_Base_Demand_1
WHERE
    WCID_From_MO IS NOT NULL
    AND WCID_From_MO <> ''
    AND MRP_Remaining_Qty > 0
    AND Has_Issued = 'YES'  -- Partial issuance indicates WC batch in progress

GO

EXEC sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'WC batch inventory. Option A sources from ETB_PAB_AUTO WCID_From_MO/Remaining. Option B sources from IV00300 with WC site filter. Choose implementation based on your WC tracking method.',
    @level0type = N'SCHEMA', @level0name = 'dbo',
    @level1type = N'VIEW', @level1name = 'Rolyat_WC_Inventory'
GO
