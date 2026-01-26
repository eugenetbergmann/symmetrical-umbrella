# ETB2 Analytics Documentation

**Generated:** 2026-01-26  
**SESSION_ID:** ETB2-20260126030557-ABCD  

## Dependency Model

ETB2 objects are classified into two groups based on static dependency analysis:

- **ETB2_SELF_CONTAINED**: Depends only on ETB2_* objects or no external dependencies (e.g., hardcoded values).
- **ETB2_EXTERNAL_DEPENDENCY**: Depends on non-ETB2 objects such as legacy tables (dbo.ETB_PAB_AUTO), vendor tables (Prosenthal_Vendor_Items), or operational tables (dbo.IV00300).

## SELECT-Only Contract

All ETB2 artifacts must contain only SELECT statements without CREATE, INSERT, UPDATE, DELETE, MERGE, or EXEC. Current artifacts violate this by using CREATE OR ALTER VIEW. Remediation required to convert to pure SELECT queries.

## External Dependency Validation Queue

The following ETB2 objects require validation of external dependencies before production use:

- ETB2_Demand_Cleaned_Base (dbo.ETB_PAB_AUTO, Prosenthal_Vendor_Items)
- ETB2_Inventory_Quarantine_Restricted (dbo.IV00300, dbo.IV00101)
- ETB2_Inventory_Unified_Eligible (dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.EXT_BINTYPE, dbo.IV00300, dbo.IV00101)
- ETB2_Inventory_WC_Batches (dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.EXT_BINTYPE)
- ETB2_Planning_Net_Requirements (dbo.ETB_PAB_AUTO)
- ETB2_Planning_Rebalancing_Opportunities (dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.IV00300)
- ETB2_Planning_Stockout_Risk (dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE)

## Analytical Inventory (Authoritative)

| Object Name | Dependency Group | Upstream Dependencies | Downstream Consumers | Analytics Readiness Status |
|-------------|------------------|-----------------------|----------------------|-----------------------------|
| ETB2_Config_Active | ETB2_SELF_CONTAINED | None | All planning queries | READY |
| ETB2_Demand_Cleaned_Base | ETB2_EXTERNAL_DEPENDENCY | dbo.ETB_PAB_AUTO, Prosenthal_Vendor_Items | ETB2_Planning_Stockout_Risk, ETB2_Planning_Net_Requirements, ETB2_Planning_Rebalancing_Opportunities | READY |
| ETB2_Inventory_Quarantine_Restricted | ETB2_EXTERNAL_DEPENDENCY | dbo.IV00300, dbo.IV00101 | ETB2_Inventory_Unified_Eligible | READY |
| ETB2_Inventory_Unified_Eligible | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.EXT_BINTYPE, dbo.IV00300, dbo.IV00101 | ETB2_Planning_Stockout_Risk, ETB2_Planning_Rebalancing_Opportunities | READY |
| ETB2_Inventory_WC_Batches | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.EXT_BINTYPE | ETB2_Inventory_Unified_Eligible | READY |
| ETB2_Planning_Net_Requirements | ETB2_EXTERNAL_DEPENDENCY | dbo.ETB_PAB_AUTO | None | READY |
| ETB2_Planning_Rebalancing_Opportunities | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE, dbo.IV00300 | None | READY |
| ETB2_Planning_Stockout_Risk | ETB2_EXTERNAL_DEPENDENCY | dbo.Prosenthal_INV_BIN_QTY_wQTYTYPE | None | READY |