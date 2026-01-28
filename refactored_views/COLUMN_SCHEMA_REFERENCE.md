# ETB2 Pipeline - Unified Column Schema Reference

This document defines the standardized column names and aliases used across all 17 views.

---

## Core Standard Column Names

### Item Identifier (Standardized)
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `ITEMNMBR` | `Item_Number` | Primary item identifier (from GP tables) |
| `ITEMDESC` | `Item_Description` | Item description from IV00101 |
| `UOMSCHDL` | `Unit_Of_Measure` | Unit of measure |

### Order Identifier (Standardized)
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `ORDERNUMBER` | `Order_Number` | PAB order number |
| `Clean_Order_Number` | `Order_Number` | Cleaned order number |
| `PONUMBER` | `Order_Number` | PO order number |
| `Order_Number` | `Campaign_ID` | Campaign/Planning order (view 11) |

### Date Fields (Standardized)
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `DUEDATE` | `Due_Date` | Original due date |
| `Due_Date_Clean` | `Due_Date` | Cleaned due date |
| `DOCDATE` | `Order_Date` | PO document date |
| `REQDATE` | `Required_Date` | Required delivery date |
| `RECEIPTDATE` | `Receipt_Date` | Inventory receipt date |
| `EXPNDATE` | `Expiry_Date` | Expiration date |

### Location/Site Fields (Standardized)
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `LOCNID` | `Site` | Work center/location |
| `LOCNID` | `From_Work_Center` | Source WC (view 10) |
| `LOCNID` | `To_Work_Center` | Target WC (view 10) |
| `Hold_Type` | `Site_Type` | Quarantine hold type |

### Quantity Fields (Standardized)
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `REMAINING` | `Remaining_Qty` | Remaining quantity |
| `DEDUCTIONS` | `Deductions_Qty` | Deductions quantity |
| `EXPIRY` | `Expiry_Qty` | Expiry quantity |
| `Base_Demand_Qty` | `Base_Demand_Qty` | Calculated demand |
| `QTY` | `Quantity` | Raw quantity |
| `QTY` | `Usable_Qty` | Available quantity |
| `QTYORDER` | `Ordered_Qty` | PO ordered quantity |
| `QTYRECEIVED` | `Received_Qty` | PO received quantity |
| `QTYREMGTD` | `Remaining_Qty` | PO remaining quantity |
| `Net_Requirement_Qty` | `Net_Requirement` | Net requirement |
| `Total_Available` | `Total_Available` | Available inventory |
| `ATP_Balance` | `ATP_Balance` | Available to promise |
| `Surplus_Qty` | `Surplus_Qty` | Surplus quantity |
| `Deficit_Qty` | `Deficit_Qty` | Deficit quantity |

### Status Fields (Standardized)
| Internal Name | Output Alias | Usage |
|---------------|--------------|-------|
| `STSDESCR` | `Status_Description` | PAB status |
| `Demand_Priority_Type` | `Demand_Priority_Type` | Priority type |
| `Requirement_Priority` | `Requirement_Priority` | Planning priority |
| `Requirement_Status` | `Requirement_Status` | Planning status |
| `Risk_Level` | `Risk_Level` | Stockout risk |
| `Collision_Risk_Level` | `Collision_Risk_Level` | Campaign collision risk |
| `Campaign_Health` | `Campaign_Health` | Campaign health status |

---

## View-by-View Column Output

### View 01: ETB2_Config_Lead_Times
- `ITEMNMBR` (Item_Number)
- `Lead_Time_Days`
- `Config_Source`

### View 02: ETB2_Config_Part_Pooling
- `ITEMNMBR` (Item_Number)
- `Pooling_Classification`
- `Config_Source`

### View 03: ETB2_Config_Active
- `ITEMNMBR` (Item_Number)
- `Lead_Time_Days`
- `Pooling_Classification`
- `Config_Source`

### View 04: ETB2_Demand_Cleaned_Base
- `ORDERNUMBER` → `Order_Number`
- `ITEMNMBR` (Item_Number)
- `Item_Description`
- `SITE` (Site)
- `Due_Date` (DUEDATE)
- `Base_Demand_Qty`
- `Expiry_Qty`
- `Expiry_Date` (Expiry_Dates)
- `Unit_Of_Measure` (UOMSCHDL)
- `Remaining_Qty`
- `Deductions_Qty`
- `Demand_Priority_Type`
- `Is_Within_Active_Planning_Window`
- `Event_Sort_Priority`

### View 05: ETB2_Inventory_WC_Batches
- `Item_Number` (ITEMNMBR)
- `Item_Description`
- `Unit_Of_Measure`
- `Site` (LOCNID)
- `Quantity`
- `Usable_Qty`
- `Receipt_Date`
- `Expiry_Date`
- `Days_To_Expiry`
- `Use_Sequence`

### View 06: ETB2_Inventory_Quarantine_Restricted
- `Item_Number` (ITEMNMBR)
- `Item_Description`
- `Unit_Of_Measure`
- `Site` (LOCNID)
- `Hold_Type`
- `Quantity_Received` (QTYRECVD)
- `Quantity_Sold` (QTYSOLD)
- `Quantity_Allocated` (ATYALLOC)
- `Can_Allocate`
- `Receipt_Date`

### View 07: ETB2_Inventory_Unified (NEW)
- `Item_Number` (ITEMNMBR)
- `Item_Description`
- `Unit_Of_Measure`
- `Site`
- `Site_Type`
- `Quantity`
- `Usable_Qty`
- `Receipt_Date`
- `Expiry_Date`
- `Days_To_Expiry`
- `Use_Sequence`
- `Inventory_Type`
- `Allocation_Priority`

### View 08: ETB2_Planning_Net_Requirements
- `ITEMNMBR` (Item_Number)
- `Net_Requirement_Qty` → `Net_Requirement`
- `Safety_Stock_Level`
- `Days_Of_Supply`
- `Order_Count`
- `Requirement_Priority`
- `Requirement_Status`
- `Earliest_Demand_Date`
- `Latest_Demand_Date`

### View 09: ETB2_Planning_Stockout (NEW)
- `Item_Number` (ITEMNMBR)
- `Item_Description`
- `Unit_Of_Measure`
- `Net_Requirement`
- `Total_Available`
- `ATP_Balance`
- `Shortage_Quantity`
- `Risk_Level`
- `Coverage_Ratio`
- `Priority`
- `Recommendation`

### View 10: ETB2_Planning_Rebalancing_Opportunities
- `ITEMNMBR` (Item_Number)
- `From_Work_Center`
- `Surplus_Qty`
- `To_Work_Center`
- `Deficit_Qty`
- `Recommended_Transfer`
- `Net_Position`
- `Rebalancing_Type`
- `Identified_Date`

### View 11: ETB2_Campaign_Normalized_Demand
- `Order_Number` → `Campaign_ID`
- `ITEMNMBR` (Item_Number)
- `Total_Campaign_Quantity`
- `CCU`
- `CCU_Unit`
- `Peak_Period_Start`
- `Peak_Period_End`
- `Campaign_Duration_Days`
- `Active_Days_Count`

### View 12: ETB2_Campaign_Concurrency_Window
- `Campaign_A`
- `Campaign_B`
- `Concurrency_Start`
- `Concurrency_End`
- `Concurrency_Days`
- `Combined_CCU`
- `Concurrency_Intensity`

### View 13: ETB2_Campaign_Collision_Buffer
- `Campaign_ID`
- `Item_Number` (ITEMNMBR)
- `Total_Campaign_Quantity`
- `CCU`
- `collision_buffer_qty`
- `Peak_Period_Start`
- `Peak_Period_End`
- `Collision_Risk_Level`
- `Overlapping_Campaigns`

### View 14: ETB2_Campaign_Risk_Adequacy
- `Item_Number` (ITEMNMBR)
- `Campaign_ID`
- `Available_Inventory`
- `Required_Buffer`
- `Adequacy_Score`
- `campaign_collision_risk`
- `Days_Buffer_Coverage`
- `Recommendation`

### View 15: ETB2_Campaign_Absorption_Capacity
- `Campaign_ID`
- `Total_Inventory`
- `Total_Buffer_Required`
- `Absorption_Ratio`
- `Campaign_Health`
- `Items_In_Campaign`
- `Avg_Adequacy`
- `Calculated_Date`

### View 16: ETB2_Campaign_Model_Data_Gaps
- `ITEMNMBR` (Item_Number)
- `Missing_Lead_Time_Config`
- `Missing_Pooling_Config`
- `Missing_Inventory_Data`
- `Missing_Demand_Data`
- `Missing_Campaign_Data`
- `Total_Gap_Count`
- `data_confidence`
- `Gap_Description`
- `Remediation_Priority`

### View 17: ETB2_PAB_EventLedger_v1
- `Order_Number`
- `Vendor_ID`
- `Item_Number` (ITEMNMBR)
- `UOM` (UOFM)
- `Ordered_Qty`
- `Received_Qty`
- `Remaining_Qty`
- `Event_Type`
- `Order_Date`
- `Required_Date`
- `ETB2_Load_Date`
- `Item_Description`

---

## Join Key References

### Cross-View Joins
| From View | To View | Join Columns |
|-----------|---------|--------------|
| View 04 (Demand) | View 08 (Planning) | `ITEMNMBR` |
| View 04 (Demand) | View 11 (Campaign) | `Order_Number`, `ITEMNMBR` |
| View 07 (Inventory) | View 09 (Stockout) | `Item_Number` |
| View 08 (Requirements) | View 09 (Stockout) | `Item_Number` |
| View 11 (Campaign) | View 12 (Concurrency) | `ITEMNMBR`, `Campaign_ID` |
| View 12 (Concurrency) | View 13 (Collision) | `Campaign_ID`, `ITEMNMBR` |
| View 13 (Collision) | View 14 (Risk) | `Campaign_ID`, `ITEMNMBR` |

### External Table References
| External Table | Internal Column | Output Alias |
|----------------|-----------------|--------------|
| `ETB_PAB_AUTO` | `ORDERNUMBER` | `Order_Number` |
| `ETB_PAB_AUTO` | `ITEMNMBR` | `Item_Number` |
| `ETB_PAB_AUTO` | `DUEDATE` | `Due_Date` |
| `IV00101` | `ITEMNMBR` | `Item_Number` |
| `IV00101` | `ITEMDESC` | `Item_Description` |
| `IV00101` | `UOMSCHDL` | `Unit_Of_Measure` |
| `POP10100` | `PONUMBER` | `Order_Number` |
| `POP10100` | `VENDORID` | `Vendor_ID` |
| `POP10110` | `ITEMNMBR` | `Item_Number` |
| `POP10110` | `UOFM` | `UOM` |
| `Prosenthal_Vendor_Items` | `[Item Number]` | `Item_Number` |
| `Prosenthal_Vendor_Items` | `ITEMDESC` | `Item_Description` |

---

## Last Updated
2026-01-28
