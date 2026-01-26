# ETB2 Dependency Audit

**Generated:** 2026-01-26  
**SESSION_ID:** ETB2-20260126030557-ABCD  

## Dependency Classification

| ETB2 Object | Dependency Group | External Dependencies | Validation Required |
|-------------|------------------|----------------------|---------------------|
| ETB2_Config_Active | ETB2_SELF_CONTAINED | None | NO |
| ETB2_Demand_Cleaned_Base | ETB2_EXTERNAL_DEPENDENCY | dbo.ETB_PAB_AUTO, Prosenthal_Vendor_Items | YES |
| ETB2_Inventory_Quarantine_Restricted | ETB2_EXTERNAL_DEPENDENCY | dbo.IV00300, dbo.IV00101 | YES |
| ETB2_Inventory_Unified_Eligible | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.EXT_BINTYPE, dbo.IV00300, dbo.IV00101 | YES |
| ETB2_Inventory_WC_Batches | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.EXT_BINTYPE | YES |
| ETB2_Planning_Net_Requirements | ETB2_EXTERNAL_DEPENDENCY | dbo.ETB_PAB_AUTO | YES |
| ETB2_Planning_Rebalancing_Opportunities | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.IV00300 | YES |
| ETB2_Planning_Stockout_Risk | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE | YES |

## SELECT-Only Validation

All ETB2 SQL artifacts contain CREATE OR ALTER VIEW statements, violating the SELECT-only contract. Recommended remediation: Convert to standalone SELECT queries.