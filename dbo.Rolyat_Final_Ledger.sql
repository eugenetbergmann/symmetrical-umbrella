USE [MED]
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_DiagramPaneCount' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_Final_Ledger'
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_DiagramPane1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_Final_Ledger'
GO

/****** Object:  View [dbo].[Rolyat_Final_Ledger]    Script Date: 1/13/2026 9:31:36 AM ******/
DROP VIEW [dbo].[Rolyat_Final_Ledger]
GO

/****** Object:  View [dbo].[Rolyat_Final_Ledger]    Script Date: 1/13/2026 9:31:36 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_Final_Ledger]
AS
SELECT
    ORDERNUMBER,
    ITEMNMBR,
    CleanItem,
    WCID_From_MO,
    Construct,
    FG,
    FG_Desc,
    ItemDescription,
    UOMSCHDL,
    STSDESCR,
    MRPTYPE,
    VendorItem,
    INCLUDE_MRP,
    SITE,
    PRIME_VNDR,
    Date_Expiry,
    Expiry_Dates,
    DUEDATE,
    MRP_IssueDate,
    BEG_BAL,
    POs,
    Deductions,
    CleanDeductions,
    Expiry,
    Remaining,
    Running_Balance AS Original_Running_Balance,
    Issued,
    PURCHASING_LT,
    PLANNING_LT,
    ORDER_POINT_QTY,
    SAFETY_STOCK,
    Has_Issued,
    IssueDate_Mismatch,
    Early_Issue_Flag,

    Base_Demand,
    allocated AS WC_Inventory_Applied,
    effective_demand AS Effective_Demand,
    wc_allocation_status,

    -- Per-item running balance (fixed global total issue)
    SUM(COALESCE(BEG_BAL, 0.0) + COALESCE(POs, 0.0) - effective_demand) 
        OVER (
            PARTITION BY ITEMNMBR
            ORDER BY Date_Expiry, ORDERNUMBER
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS Adjusted_Running_Balance,

    CASE
        WHEN BEG_BAL > 0 THEN 'BEGINNING_BALANCE'
        WHEN POs > 0 THEN 'PURCHASE_ORDER'
        WHEN Base_Demand > 0 THEN 'DEMAND_EVENT'
        ELSE 'OTHER'
    END AS Row_Type,

    CASE
        WHEN allocated >= Base_Demand AND Base_Demand > 0 THEN 'FULLY_SUPPLIED'
        WHEN allocated > 0 THEN 'PARTIALLY_SUPPLIED'
        ELSE 'NO_WC_ALLOCATED'
    END AS Demand_Validation_Status,

    CASE
        WHEN allocated = 0 AND Base_Demand > 0 THEN 'NO_ALLOCATION'
        WHEN allocated < Base_Demand THEN 'PARTIAL_ALLOCATION'
        ELSE 'FULL_ALLOCATION'
    END AS Allocation_Efficiency_Flag,

    CASE
        WHEN effective_demand > 0 AND Date_Expiry BETWEEN GETDATE() AND DATEADD(DAY, 3, GETDATE())
            THEN 'URGENT_UNMET_DEMAND'
        WHEN wc_allocation_status = 'No_WC_Allocation' AND Base_Demand > 0
            THEN 'REVIEW_NO_WC_AVAILABLE'
        ELSE 'NORMAL'
    END AS QC_Flag

FROM dbo.Rolyat_WC_PAB_effective_demand;
-- ORDER BY removed — add it when querying the view instead
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[40] 4[20] 2[20] 3) )"
      End
      Begin PaneConfiguration = 1
         NumPanes = 3
         Configuration = "(H (1 [50] 4 [25] 3))"
      End
      Begin PaneConfiguration = 2
         NumPanes = 3
         Configuration = "(H (1 [50] 2 [25] 3))"
      End
      Begin PaneConfiguration = 3
         NumPanes = 3
         Configuration = "(H (4 [30] 2 [40] 3))"
      End
      Begin PaneConfiguration = 4
         NumPanes = 2
         Configuration = "(H (1 [56] 3))"
      End
      Begin PaneConfiguration = 5
         NumPanes = 2
         Configuration = "(H (2 [66] 3))"
      End
      Begin PaneConfiguration = 6
         NumPanes = 2
         Configuration = "(H (4 [50] 3))"
      End
      Begin PaneConfiguration = 7
         NumPanes = 1
         Configuration = "(V (3))"
      End
      Begin PaneConfiguration = 8
         NumPanes = 3
         Configuration = "(H (1[56] 4[18] 2) )"
      End
      Begin PaneConfiguration = 9
         NumPanes = 2
         Configuration = "(H (1 [75] 4))"
      End
      Begin PaneConfiguration = 10
         NumPanes = 2
         Configuration = "(H (1[66] 2) )"
      End
      Begin PaneConfiguration = 11
         NumPanes = 2
         Configuration = "(H (4 [60] 2))"
      End
      Begin PaneConfiguration = 12
         NumPanes = 1
         Configuration = "(H (1) )"
      End
      Begin PaneConfiguration = 13
         NumPanes = 1
         Configuration = "(V (4))"
      End
      Begin PaneConfiguration = 14
         NumPanes = 1
         Configuration = "(V (2))"
      End
      ActivePaneConfig = 0
   End
   Begin DiagramPane = 
      Begin Origin = 
         Top = 0
         Left = 0
      End
      Begin Tables = 
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 44
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
      End
   End
   Begin CriteriaPane = 
      Begin ColumnWidths = 11
         Column = 1440
         Alias = 900
         Table = 1170
         Output = 720
         Append = 1400
         NewValue = 1170
         SortType = 1350
         SortOrder = 1410
         GroupBy = 1350
         Filter = 1350
         Or = 1350
         Or = 1350
         Or = 1350
      End
   End
End
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_Final_Ledger'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_Final_Ledger'
GO

