# ETB2 Refactored Views

**Author:** Eugene Bergmann  
**Last Updated:** 2026-01-30

---

## About

This repository contains 17 SQL Server views for the ETB2 (Enterprise Tactical Business 2) analytics system. These views provide a unified supply chain planning and analytics framework with full FG (Finished Goods) Item Number and Construct visibility.

## Views

| # | View | Purpose |
|---|------|---------|
| 01 | ETB2_Config_Lead_Times | Lead time configuration |
| 02 | ETB2_Config_Part_Pooling | Part pooling classification |
| 02B | ETB2_Config_Items | Item configuration |
| 03 | ETB2_Config_Active | Active configuration hierarchy |
| 04 | ETB2_Demand_Cleaned_Base | Cleaned demand with FG/Construct |
| 05 | ETB2_Inventory_WC_Batches | WC batch inventory with FG/Construct |
| 06 | ETB2_Inventory_Quarantine_Restricted | WFQ/RMQTY inventory with FG/Construct |
| 07 | ETB2_Inventory_Unified | Unified eligible inventory |
| 08 | ETB2_Planning_Net_Requirements | Net requirements with FG/Construct |
| 09 | ETB2_Planning_Stockout | ATP and stockout risk |
| 10 | ETB2_Planning_Rebalancing_Opportunities | Transfer recommendations |
| 11 | ETB2_Campaign_Normalized_Demand | Campaign consumption units (CCU) |
| 12 | ETB2_Campaign_Concurrency_Window | Campaign concurrency (CCW) |
| 13 | ETB2_Campaign_Collision_Buffer | Collision buffer requirements |
| 14 | ETB2_Campaign_Risk_Adequacy | Risk adequacy assessment |
| 15 | ETB2_Campaign_Absorption_Capacity | Executive KPIs |
| 16 | ETB2_Campaign_Model_Data_Gaps | Data quality flags |
| 17 | ETB2_PAB_EventLedger_v1 | Event ledger with FG/Construct |

## Key Features

- **FG + Construct Visibility:** All views carry FG Item Number, FG Description, and Construct (Customer) from ETB_PAB_MO
- **CleanOrder Normalization:** Orders normalized by stripping MO, hyphens, spaces, punctuation
- **Context Columns:** client, contract, run preserved throughout
- **Is_Suppressed Flag:** Data quality filtering

## Location

All views are in `etb2-refactored-views/views/`
