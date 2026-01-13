USE [MED]
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_DiagramPaneCount' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'rolyat_WC_PAB_data_cleaned'
GO

EXEC sys.sp_dropextendedproperty @name=N'MS_DiagramPane1' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'rolyat_WC_PAB_data_cleaned'
GO

/****** Object:  View [dbo].[rolyat_WC_PAB_data_cleaned]    Script Date: 1/13/2026 9:30:13 AM ******/
DROP VIEW [dbo].[rolyat_WC_PAB_data_cleaned]
GO

/****** Object:  View [dbo].[rolyat_WC_PAB_data_cleaned]    Script Date: 1/13/2026 9:30:13 AM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE VIEW [dbo].[rolyat_WC_PAB_data_cleaned]
AS
SELECT 
    UPPER(LTRIM(RTRIM(ORDERNUMBER))) AS ORDERNUMBER,
    UPPER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(REPLACE(ORDERNUMBER, 'MO', ''))), '-', ''), ' ', ''), '/', ''), '.', ''), '#', '')) AS CleanOrder,
    LTRIM(RTRIM(ITEMNMBR)) AS ITEMNMBR,
    LTRIM(RTRIM(ITEMNMBR)) AS CleanItem,
    LTRIM(RTRIM(COALESCE(WCID_From_MO, ''))) AS WCID_From_MO,
    LTRIM(RTRIM(COALESCE(Construct, ''))) AS Construct,
    LTRIM(RTRIM(COALESCE(FG, ''))) AS FG,
    LTRIM(RTRIM(COALESCE([FG Desc], ''))) AS FG_Desc,
    LTRIM(RTRIM(COALESCE(ItemDescription, ''))) AS ItemDescription,
    LTRIM(RTRIM(COALESCE(UOMSCHDL, ''))) AS UOMSCHDL,
    LTRIM(RTRIM(COALESCE(STSDESCR, ''))) AS STSDESCR,
    LTRIM(RTRIM(COALESCE(MRPTYPE, ''))) AS MRPTYPE,
    LTRIM(RTRIM(COALESCE(VendorItem, ''))) AS VendorItem,
    LTRIM(RTRIM(COALESCE(INCLUDE_MRP, ''))) AS INCLUDE_MRP,
    LTRIM(RTRIM(COALESCE(SITE, ''))) AS SITE,
    LTRIM(RTRIM(COALESCE(PRIME_VNDR, ''))) AS PRIME_VNDR,
    TRY_CONVERT(DATE, [Date + Expiry]) AS Date_Expiry,
    TRY_CONVERT(DATE, [Expiry Dates]) AS Expiry_Dates,
    TRY_CONVERT(DATE, DUEDATE) AS DUEDATE,
    TRY_CONVERT(DATE, MRP_IssueDate) AS MRP_IssueDate,
    COALESCE(TRY_CAST(BEG_BAL AS DECIMAL(18, 5)), 0.0) AS BEG_BAL,
    COALESCE(TRY_CAST([PO's] AS DECIMAL(18, 5)), 0.0) AS POs,
    COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) AS Deductions,
    COALESCE(TRY_CAST(Deductions AS DECIMAL(18, 5)), 0.0) AS CleanDeductions,
    COALESCE(TRY_CAST(Expiry AS DECIMAL(18, 5)), 0.0) AS Expiry,
    COALESCE(TRY_CAST(Remaining AS DECIMAL(18, 5)), 0.0) AS Remaining,
    COALESCE(TRY_CAST(Running_Balance AS DECIMAL(18, 5)), 0.0) AS Running_Balance,
    COALESCE(TRY_CAST(Issued AS DECIMAL(18, 5)), 0.0) AS Issued,
    COALESCE(TRY_CAST(PURCHASING_LT AS DECIMAL(18, 5)), 0.0) AS PURCHASING_LT,
    COALESCE(TRY_CAST(PLANNING_LT AS DECIMAL(18, 5)), 0.0) AS PLANNING_LT,
    COALESCE(TRY_CAST(ORDER_POINT_QTY AS DECIMAL(18, 5)), 0.0) AS ORDER_POINT_QTY,
    COALESCE(TRY_CAST(SAFETY_STOCK AS DECIMAL(18, 5)), 0.0) AS SAFETY_STOCK,
    UPPER(LTRIM(RTRIM(COALESCE(Has_Issued, 'NO')))) AS Has_Issued,
    UPPER(LTRIM(RTRIM(COALESCE(IssueDate_Mismatch, 'NO')))) AS IssueDate_Mismatch,
    UPPER(LTRIM(RTRIM(COALESCE(Early_Issue_Flag, 'NO')))) AS Early_Issue_Flag
FROM dbo.ETB_PAB_AUTO
WHERE TRY_CONVERT(DATE, [Date + Expiry]) IS NOT NULL
  AND LTRIM(RTRIM(ITEMNMBR)) NOT LIKE '60.%'
  AND LTRIM(RTRIM(ITEMNMBR)) NOT LIKE '70.%'
  AND LTRIM(RTRIM(COALESCE(STSDESCR, ''))) <> 'Partially Received';
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
      Begin ColumnWidths = 36
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
' , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'rolyat_WC_PAB_data_cleaned'
GO

EXEC sys.sp_addextendedproperty @name=N'MS_DiagramPaneCount', @value=1 , @level0type=N'SCHEMA',@level0name=N'dbo', @level1type=N'VIEW',@level1name=N'rolyat_WC_PAB_data_cleaned'
GO

