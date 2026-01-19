# Rolyat Stock-Out Intelligence Pipeline

[![SQL Server](https://img.shields.io/badge/SQL%20Server-2016+-blue.svg)](https://www.microsoft.com/sql-server)
[![Tests](https://img.shields.io/badge/Tests-25%20Passing-green.svg)](tests/)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

A deterministic, noise-reduced, WF-Q/RMQTY-aware stock-out intelligence pipeline for inventory planning and management.

## Overview

The Rolyat Pipeline provides comprehensive stock-out analysis and inventory intelligence through a series of SQL Server views. It delivers:

- **Deterministic Event Ordering**: Consistent processing of supply/demand events
- **Active Window Enforcement**: ±21 day planning window for WC allocation
- **WF-Q + RMQTY Integration**: Alternate stock awareness for intelligent action tags
- **Planner-Ready Views**: One-shot queries for immediate actionable insights

## Quick Start

```sql
-- Get urgent stock-out items
SELECT TOP 100 *
FROM dbo.Rolyat_StockOut_Analysis_v2
WHERE Action_Tag LIKE 'URGENT_%'
ORDER BY Deficit_ATP DESC, DUEDATE ASC;

-- Run validation tests
EXEC tests.sp_run_unit_tests;
```

## Architecture

```
ETB_PAB_AUTO ──► Rolyat_Cleaned_Base_Demand_1 ──► Rolyat_WC_Allocation_Effective_2
                         │                                    │
                         ▼                                    ▼
                 Rolyat_WC_Inventory              Rolyat_Final_Ledger_3
                                                              │
                                                              ▼
                                              Rolyat_StockOut_Analysis_v2
                                                              │
                                                              ▼
                                              Rolyat_Rebalancing_Layer
```

## Views

| View | Description |
|------|-------------|
| `Rolyat_Site_Config` | Site configuration (WFQ/RMQTY locations) - stub view |
| `Rolyat_PO_Detail` | Purchase order details - stub view |
| `Rolyat_Config_Global` | System-wide default parameters |
| `Rolyat_Config_Clients` | Client-specific overrides |
| `Rolyat_Config_Items` | Item-specific overrides |
| `Rolyat_Cleaned_Base_Demand_1` | Data cleansing, Base_Demand calculation, SortPriority |
| `Rolyat_WC_Inventory` | WC batch inventory tracking |
| `Rolyat_WFQ_5` | WFQ/RMQTY inventory with release eligibility |
| `Rolyat_Unit_Price_4` | Blended average cost calculation |
| `Rolyat_WC_Allocation_Effective_2` | FEFO allocation, degradation factors, effective demand |
| `Rolyat_Final_Ledger_3` | Forecast/ATP running balances, stock-out flags |
| `Rolyat_StockOut_Analysis_v2` | Action tags, deficit calculations, QC flags |
| `Rolyat_Rebalancing_Layer` | Timed hope sources, net replenishment needs |
| `Rolyat_Consumption_Detail_v1` | Detailed consumption for analysis |
| `Rolyat_Consumption_SSRS_v1` | SSRS-optimized reporting view |
| `Rolyat_Net_Requirements_v1` | Net requirements calculation |

## Key Features

### Deterministic Event Ordering

Events are processed in a consistent order using `SortPriority`:

| Priority | Event Type |
|----------|------------|
| 1 | Beginning Balance |
| 2 | Purchase Orders |
| 3 | Demand Events |
| 4 | Expiry Events |
| 5 | Other |

### Active Window Enforcement

WC allocation only occurs within the ±21 day active planning window:

```sql
-- IsActiveWindow = 1 when DUEDATE is within ±21 days of today
CASE
    WHEN DUEDATE BETWEEN DATEADD(DAY, -21, GETDATE()) 
         AND DATEADD(DAY, 21, GETDATE()) THEN 1
    ELSE 0
END AS IsActiveWindow
```

### Action Tags

Planner-ready action tags based on urgency:

| Tag | Condition |
|-----|-----------|
| `URGENT_PURCHASE` | ATP deficit ≥ 100 within active window |
| `URGENT_TRANSFER` | ATP deficit ≥ 50 within active window |
| `URGENT_EXPEDITE` | ATP deficit < 50 within active window |
| `REVIEW_ALTERNATE_STOCK` | ATP deficit with alternate stock available |
| `ATP_CONSTRAINED` | ATP deficit but Forecast OK |
| `STOCK_OUT` | ATP deficit, no alternate stock |
| `NORMAL` | No deficit |

## Installation

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for detailed deployment instructions.

### Quick Deploy

```bash
# Deploy views in order
sqlcmd -S <server> -d MED -i dbo.Rolyat_Site_Config.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_PO_Detail.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Config_Global.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Config_Clients.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Config_Items.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Cleaned_Base_Demand_1.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_WC_Inventory.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_WFQ_5.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Unit_Price_4.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_WC_Allocation_Effective_2.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Final_Ledger_3.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_StockOut_Analysis_v2.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Rebalancing_Layer.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Consumption_Detail_v1.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Consumption_SSRS_v1.sql
sqlcmd -S <server> -d MED -i dbo.Rolyat_Net_Requirements_v1.sql
```

## Testing

The pipeline includes a comprehensive test suite with 25+ unit tests covering:

- Running balance identity
- Event ordering
- Active window flagging
- WC allocation logic
- Supply event composition
- Stock-out intelligence
- Data integrity
- Edge cases

### Run Tests

```sql
-- Run all unit tests
EXEC tests.sp_run_unit_tests;

-- Run iterative test harness with synthetic data
EXEC tests.sp_run_test_iterations @max_iterations = 25, @seed_start = 1000;

-- Quick single test
EXEC tests.sp_quick_test @seed = 1000;
```

### Test Files

| File | Description |
|------|-------------|
| `tests/unit_tests.sql` | Comprehensive unit test suite |
| `tests/assertions.sql` | Standalone assertion queries |
| `tests/test_harness.sql` | Iterative test harness |
| `tests/synthetic_data_generation.sql` | Test data generation |

## Configuration

### Degradation Tiers

| Age (Days) | Factor |
|------------|--------|
| 0-30 | 1.00 |
| 31-60 | 0.75 |
| 61-90 | 0.50 |
| >90 | 0.00 |

### Configuration Function

The pipeline uses `dbo.fn_GetConfig` for item/client-specific parameters. See deployment guide for implementation.

## Directory Structure

```
├── dbo.Rolyat_*.sql          # Main view definitions
├── docs/
│   ├── DEPLOYMENT.md         # Deployment guide
│   └── readout_state.md      # Pipeline state documentation
├── tests/
│   ├── unit_tests.sql        # Unit test suite
│   ├── assertions.sql        # Assertion queries
│   ├── test_harness.sql      # Test harness
│   ├── synthetic_data_generation.sql
│   └── README.md             # Test documentation
├── plans/
│   └── testing_plan.md       # Testing strategy
├── reports/
│   └── test_report.md        # Test results
└── .github/                  # CI/CD workflows
```

## Requirements

- SQL Server 2016 or later
- `CREATE VIEW` permission
- `SELECT` permission on source tables
- `EXECUTE` permission for stored procedures

## Contributing

1. Create a feature branch
2. Make changes
3. Run tests: `EXEC tests.sp_run_unit_tests;`
4. Ensure 100% test pass rate
5. Submit pull request

## License

Proprietary - All rights reserved.

## Support

For issues or questions:
1. Run diagnostics: `EXEC tests.sp_generate_diagnostics;`
2. Review test results: `EXEC tests.sp_run_unit_tests;`
3. Check iteration log: `SELECT * FROM tests.TestIterationLog ORDER BY iteration_id DESC;`

---

*Version 2.0.0 | Last Updated: 2026-01-19*
