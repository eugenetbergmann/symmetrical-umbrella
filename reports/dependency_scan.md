# Rolyat Pipeline Dependency Scan

**Scan Date:** 2026-01-16  
**Pipeline Version:** 2.0.0  

## View Dependencies

### dbo.Rolyat_Cleaned_Base_Demand_1
- **Source Tables:**
  - dbo.ETB_PAB_AUTO
- **Config Dependencies:**
  - dbo.fn_GetConfig('ActiveWindow_Past_Days')
  - dbo.fn_GetConfig('ActiveWindow_Future_Days')

### dbo.Rolyat_WC_Inventory
- **Source Views:**
  - dbo.Rolyat_Cleaned_Base_Demand_1
- **Config Dependencies:**
  - dbo.fn_GetConfig('WC_Batch_Shelf_Life_Days')

### dbo.Rolyat_WFQ_5
- **Source Tables:**
  - dbo.IV00300 (Inventory Lot Master)
  - dbo.IV00101 (Item Master)
  - dbo.Rolyat_Site_Config
- **Config Dependencies:**
  - dbo.fn_GetConfig('WFQ_Hold_Days')
  - dbo.fn_GetConfig('WFQ_Expiry_Filter_Days')
  - dbo.fn_GetConfig('RMQTY_Hold_Days')
  - dbo.fn_GetConfig('RMQTY_Expiry_Filter_Days')

### dbo.Rolyat_WC_Allocation_Effective_2
- **Source Views:**
  - dbo.Rolyat_Cleaned_Base_Demand_1

### dbo.Rolyat_Unit_Price_4
- **Source Views:**
  - dbo.Rolyat_WC_Allocation_Effective_2

### dbo.Rolyat_Final_Ledger_3
- **Source Views:**
  - dbo.Rolyat_WC_Allocation_Effective_2
  - dbo.Rolyat_WFQ_5
- **Source Tables:**
  - dbo.Rolyat_PO_Detail

### dbo.Rolyat_StockOut_Analysis_v2
- **Source Views:**
  - dbo.Rolyat_Final_Ledger_3

### dbo.Rolyat_Rebalancing_Layer
- **Source Views:**
  - dbo.Rolyat_StockOut_Analysis_v2

### dbo.Rolyat_Net_Requirements_v1
- **Source Views:**
  - dbo.Rolyat_Rebalancing_Layer
  - dbo.Rolyat_StockOut_Analysis_v2
- **Config Dependencies:**
  - dbo.fn_GetConfig('Safety_Stock_Days')

## Configuration Dependencies

### dbo.fn_GetConfig
- **Config Tables:**
  - dbo.Rolyat_Config_Global
  - dbo.Rolyat_Config_Clients
  - dbo.Rolyat_Config_Items

## Deployment Order

1. dbo.Rolyat_Config_Global.sql
2. dbo.Rolyat_Config_Clients.sql
3. dbo.Rolyat_Config_Items.sql
4. dbo.fn_GetConfig.sql
5. dbo.Rolyat_Cleaned_Base_Demand_1.sql
6. dbo.Rolyat_WC_Inventory.sql
7. dbo.Rolyat_WFQ_5.sql
8. dbo.Rolyat_WC_Allocation_Effective_2.sql
9. dbo.Rolyat_Unit_Price_4.sql
10. dbo.Rolyat_Final_Ledger_3.sql
11. dbo.Rolyat_StockOut_Analysis_v2.sql
12. dbo.Rolyat_Rebalancing_Layer.sql
13. dbo.Rolyat_Net_Requirements_v1.sql (optional)

## Notes

- All views are read-only (no intermediate tables)
- Configuration is hierarchical: Item > Client > Global
- Pipeline supports deterministic ordering via SortPriority
- ATP/Forecast logic properly separated