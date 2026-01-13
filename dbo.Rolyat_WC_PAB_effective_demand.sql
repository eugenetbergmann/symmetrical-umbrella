USE [MED]
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_DiagramPaneCount' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_effective_demand'
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_DiagramPane1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_effective_demand'
GO

/****** Object:  View [dbo].[Rolyat_WC_PAB_effective_demand]    Script Date: 1/13/2026 10:20:24 AM ******/
DROP VIEW [dbo].[Rolyat_WC_PAB_effective_demand]
GO

/****** Object:  View [dbo].[Rolyat_WC_PAB_effective_demand]    Script Date: 1/13/2026 10:20:24 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/* Single comprehensive test for allocation logic
 View purpose: Calculate effective (net) demand after WC allocation
 Suppresses allocated WC quantity only for near-term demands (±21 days)
 Leaves far-future demand untouched for conservative planning
 Bakery metaphor: Adjusted whiteboard – erase covered orders only for this week*/
CREATE VIEW [dbo].[Rolyat_WC_PAB_effective_demand]
AS
SELECT ORDERNUMBER, CleanOrder, ITEMNMBR, CleanItem, WCID_From_MO, Construct, FG, FG_Desc, ItemDescription, UOMSCHDL, STSDESCR, MRPTYPE, VendorItem, INCLUDE_MRP, SITE, PRIME_VNDR, Date_Expiry, Expiry_Dates, DUEDATE, MRP_IssueDate, BEG_BAL, POs, 
             Deductions, CleanDeductions, Expiry, Remaining, Running_Balance, Issued, PURCHASING_LT, PLANNING_LT, ORDER_POINT_QTY, SAFETY_STOCK, Has_Issued, IssueDate_Mismatch, Early_Issue_Flag, Base_Demand, WC_Item, WC_Site, Available_Qty, WC_DateReceived, 
             WC_Age_Days, WC_Degradation_Factor, WC_Effective_Qty, WC_Batch_ID, pri_wcid_match, pri_expiry_proximity, pri_temporal_proximity, batch_prior_claimed_demand, allocated, CASE WHEN Date_Expiry BETWEEN DATEADD(DAY, - 21, GETDATE()) AND DATEADD(DAY, 21, 
             GETDATE()) THEN CASE WHEN Base_Demand - allocated > 0 THEN Base_Demand - allocated ELSE 0.0 END ELSE Base_Demand END AS effective_demand, CASE WHEN Date_Expiry BETWEEN DATEADD(DAY, - 21, GETDATE()) AND DATEADD(DAY, 21, GETDATE()) 
             THEN CASE WHEN allocated > 0 THEN 'WC_Suppressed' ELSE 'No_WC_Allocation' END ELSE 'Outside_Active_Window' END AS wc_allocation_status
FROM   dbo.Rolyat_WC_PAB_with_allocation AS a
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[8] 4[36] 2[34] 3) )"
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
         Begin Table = "a"
            Begin Extent = 
               Top = 9
               Left = 57
               Bottom = 206
               Right = 373
            End
            DisplayFlags = 280
            TopColumn = 0
         End
      End
   End
   Begin SQLPane = 
   End
   Begin DataPane = 
      Begin ParameterDefaults = ""
      End
      Begin ColumnWidths = 11
         Width = 284
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 2410
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
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_effective_demand'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_effective_demand'
GO

