USE [MED]
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_DiagramPaneCount' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_with_prioritized_inventory'
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_DiagramPane2' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_with_prioritized_inventory'
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_DiagramPane1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_with_prioritized_inventory'
GO

/****** Object:  View [dbo].[Rolyat_WC_PAB_with_prioritized_inventory]    Script Date: 1/13/2026 9:34:31 AM ******/
DROP VIEW [dbo].[Rolyat_WC_PAB_with_prioritized_inventory]
GO

/****** Object:  View [dbo].[Rolyat_WC_PAB_with_prioritized_inventory]    Script Date: 1/13/2026 9:34:31 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

/* View purpose: Join and prioritize WC inventory for demand allocation
 Matches eligible ETB_WC_INV batches to cleaned demand rows
 Applies time-based degradation (0-30d=100%, 31-60d=75%, 61-90d=50%, expired=0)
 Calculates diagnostics (age, expiry mismatch) and FEFO priority scores
 Limits to active near-term demand (±21 days) and reasonable inventory age
 Active near-term demand only
 View purpose: Join and prioritize WC inventory for demand allocation
 Matches eligible ETB_WC_INV batches to cleaned demand rows
 Applies time-based degradation (0-30d=100%, 31-60d=75%, 61-90d=50%, expired=0)
 Calculates diagnostics (age, expiry mismatch) and FEFO priority scores
 Limits to active near-term demand (±21 days) and reasonable inventory age
 CORRECTED: Changed from >= 90 to <= 90*/
CREATE VIEW [dbo].[Rolyat_WC_PAB_with_prioritized_inventory]
AS
SELECT        bd.ORDERNUMBER, bd.CleanOrder, bd.ITEMNMBR, bd.CleanItem, bd.WCID_From_MO, bd.Construct, bd.FG, bd.FG_Desc, bd.ItemDescription, bd.UOMSCHDL, bd.STSDESCR, bd.MRPTYPE, bd.VendorItem, bd.INCLUDE_MRP, 
                         bd.SITE, bd.PRIME_VNDR, bd.Date_Expiry, bd.Expiry_Dates, bd.DUEDATE, bd.MRP_IssueDate, bd.BEG_BAL, bd.POs, bd.Deductions, bd.CleanDeductions, bd.Expiry, bd.Remaining, bd.Running_Balance, bd.Issued, 
                         bd.PURCHASING_LT, bd.PLANNING_LT, bd.ORDER_POINT_QTY, bd.SAFETY_STOCK, bd.Has_Issued, bd.IssueDate_Mismatch, bd.Early_Issue_Flag, bd.Base_Demand, w.Item_Number AS WC_Item, w.SITE AS WC_Site, 
                         w.QTY_Available AS Available_Qty, w.DATERECD AS WC_DateReceived, DATEDIFF(DAY, w.DATERECD, GETDATE()) AS WC_Age_Days, CASE WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) 
                         <= 30 THEN 1.00 WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 60 THEN 0.75 WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 90 THEN 0.50 ELSE 0.00 END AS WC_Degradation_Factor, 
                         w.QTY_Available * CASE WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 30 THEN 1.00 WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) <= 60 THEN 0.75 WHEN DATEDIFF(DAY, w.DATERECD, GETDATE()) 
                         <= 90 THEN 0.50 ELSE 0.00 END AS WC_Effective_Qty, ISNULL(w.Item_Number, '') + '|' + ISNULL(w.SITE, '') + '|' + ISNULL(w.LOT_Number, '') + '|' + ISNULL(FORMAT(w.DATERECD, 'yyyy-MM-dd'), '') AS WC_Batch_ID, 
                         CASE WHEN w.SITE = bd.SITE THEN 1 ELSE 999 END AS pri_wcid_match, ABS(DATEDIFF(DAY, COALESCE (w.EXPNDATE, '9999-12-31'), COALESCE (bd.Expiry_Dates, '9999-12-31'))) AS pri_expiry_proximity, ABS(DATEDIFF(DAY, 
                         w.DATERECD, bd.Date_Expiry)) AS pri_temporal_proximity
FROM            dbo.Rolyat_Base_Demand AS bd LEFT OUTER JOIN
                         dbo.ETB_WC_INV AS w ON LTRIM(RTRIM(w.Item_Number)) = bd.CleanItem AND w.SITE LIKE 'WC-W%' AND w.QTY_Available > 0 AND ABS(DATEDIFF(DAY, w.DATERECD, bd.Date_Expiry)) <= 21 AND DATEDIFF(DAY, 
                         w.DATERECD, GETDATE()) <= 90
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[30] 4[3] 2[22] 3) )"
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
         Begin Table = "bd"
            Begin Extent = 
               Top = 9
               Left = 57
               Bottom = 206
               Right = 322
            End
            DisplayFlags = 280
            TopColumn = 0
         End
         Begin Table = "w"
            Begin Extent = 
               Top = 9
               Left = 379
               Bottom = 206
               Right = 601
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
      Begin ColumnWidths = 51
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
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         Width = 1500
         ' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_with_prioritized_inventory'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane2', @value=N'Width = 1500
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
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_with_prioritized_inventory'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=2 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_with_prioritized_inventory'
GO

