USE [MED]
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_DiagramPaneCount' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_with_allocation'
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_DiagramPane1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_with_allocation'
GO

/****** Object:  View [dbo].[Rolyat_WC_PAB_with_allocation]    Script Date: 1/13/2026 9:33:53 AM ******/
DROP VIEW [dbo].[Rolyat_WC_PAB_with_allocation]
GO

/****** Object:  View [dbo].[Rolyat_WC_PAB_with_allocation]    Script Date: 1/13/2026 9:33:53 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[Rolyat_WC_PAB_with_allocation]
AS
SELECT 
    pi.*,
    CASE 
        WHEN WC_Batch_ID IS NULL THEN 0.0
        ELSE COALESCE(
            SUM(Base_Demand) OVER (
                PARTITION BY WC_Batch_ID
                ORDER BY pri_wcid_match, pri_expiry_proximity, pri_temporal_proximity, Date_Expiry, ORDERNUMBER
                ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
            ), 0.0)
    END AS batch_prior_claimed_demand,
    CASE 
        WHEN WC_Batch_ID IS NULL THEN 0.0
        WHEN Base_Demand <= (WC_Effective_Qty - 
            COALESCE(
                SUM(Base_Demand) OVER (
                    PARTITION BY WC_Batch_ID
                    ORDER BY pri_wcid_match, pri_expiry_proximity, pri_temporal_proximity, Date_Expiry, ORDERNUMBER
                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                ), 0.0))
        THEN Base_Demand
        WHEN (WC_Effective_Qty - 
            COALESCE(
                SUM(Base_Demand) OVER (
                    PARTITION BY WC_Batch_ID
                    ORDER BY pri_wcid_match, pri_expiry_proximity, pri_temporal_proximity, Date_Expiry, ORDERNUMBER
                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                ), 0.0)) > 0
        THEN (WC_Effective_Qty - 
            COALESCE(
                SUM(Base_Demand) OVER (
                    PARTITION BY WC_Batch_ID
                    ORDER BY pri_wcid_match, pri_expiry_proximity, pri_temporal_proximity, Date_Expiry, ORDERNUMBER
                    ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                ), 0.0))
        ELSE 0.0
    END AS allocated
FROM dbo.Rolyat_WC_PAB_with_prioritized_inventory AS pi;
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPane1', @value=N'[0E232FF0-B466-11cf-A24F-00AA00A3EFFF, 1.00]
Begin DesignProperties = 
   Begin PaneConfigurations = 
      Begin PaneConfiguration = 0
         NumPanes = 4
         Configuration = "(H (1[15] 4[9] 2[15] 3) )"
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
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_with_allocation'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'Rolyat_WC_PAB_with_allocation'
GO

