# Rolyat Configuration Guide

## Overview

The Rolyat Stock-Out Intelligence Pipeline uses a hierarchical configuration system that allows fine-tuned control over inventory intelligence parameters. Configuration is managed through the `dbo.fn_GetConfig` scalar function, which implements a three-tier lookup hierarchy:

1. **Item-specific overrides** (highest priority)
2. **Client-specific overrides** (medium priority)
3. **Global defaults** (lowest priority/fallback)

## Configuration Tables

### Rolyat_Config_Global
Contains system-wide default parameters. All pipeline parameters have defaults here.

### Rolyat_Config_Clients
Client-specific overrides. Useful for different business units or regions.

### Rolyat_Config_Items
Item-specific overrides. Critical for items requiring special handling (e.g., high-value biologics, controlled substances).

## Key Parameters

### Active Window Settings
- `ActiveWindow_Past_Days`: Days in past to include for demand suppression (default: 21)
- `ActiveWindow_Future_Days`: Days in future for planning horizon (default: 21)

### Quarantine Settings
- `WFQ_Hold_Days`: Quarantine period for incoming inventory (default: 14)
- `RMQTY_Hold_Days`: Hold period for restricted material (default: 7)
- `WFQ_Expiry_Filter_Days`: Days before expiry to exclude WFQ batches (default: 30)
- `RMQTY_Expiry_Filter_Days`: Days before expiry to exclude RMQTY batches (default: 30)

### Degradation Settings
- `Degradation_Tier1_Days`: Age threshold for 100% usable (default: 30)
- `Degradation_Tier1_Factor`: Usability factor for Tier 1 (default: 1.00)
- `Degradation_Tier2_Days`: Age threshold for 75% usable (default: 60)
- `Degradation_Tier2_Factor`: Usability factor for Tier 2 (default: 0.75)
- `Degradation_Tier3_Days`: Age threshold for 50% usable (default: 90)
- `Degradation_Tier3_Factor`: Usability factor for Tier 3 (default: 0.50)

### Safety Stock
- `Safety_Stock_Days`: Default days of supply (default: 7)
- `Safety_Stock_Method`: Calculation method (default: DAYS_OF_SUPPLY)

## Using fn_GetConfig

### Function Signature
```sql
dbo.fn_GetConfig(
    @Config_Key NVARCHAR(100),
    @ITEMNMBR NVARCHAR(50) = NULL,
    @Client_ID NVARCHAR(50) = NULL,
    @AsOfDate DATE = NULL
)
```

### Examples

#### Get global default
```sql
SELECT dbo.fn_GetConfig('ActiveWindow_Past_Days', NULL, NULL, GETDATE());
-- Returns: 21
```

#### Get item-specific override (if exists)
```sql
SELECT dbo.fn_GetConfig('Safety_Stock_Days', 'BIO-001', NULL, GETDATE());
-- Returns item override or global default
```

#### Get client-specific override
```sql
SELECT dbo.fn_GetConfig('WFQ_Hold_Days', NULL, 'CLIENT_A', GETDATE());
-- Returns client override or global default
```

## Tuning Guidelines

### For High-Value Items
- Increase `Safety_Stock_Days` to 10-14
- Set shorter `ActiveWindow_Future_Days` for tighter control
- Consider item-specific degradation factors

### For Long Lead-Time Items
- Extend `BackwardSuppression_Extended_Lookback_Days`
- Increase `Safety_Stock_Days` proportionally to lead time

### For GMP/PPQ Processes
- Use extended lookback periods for demand reconciliation
- Adjust `BackwardSuppression_Match_Tolerance_Days` for process variability

### Performance Considerations
- Minimize item-specific overrides (use ABC classes where possible)
- Regularly review and clean up expired configurations
- Monitor query performance with large config tables

## Maintenance

### Adding New Parameters
1. Add default to `Rolyat_Config_Global`
2. Update `fn_GetConfig` if needed
3. Document in this guide
4. Update validation scripts

### Updating Parameters
- Use effective dates for time-sensitive changes
- Test impacts on ATP/Forecast calculations
- Update downstream systems if needed

### Monitoring
- Run config coverage tests regularly
- Audit parameter usage in views
- Validate hierarchical lookup behavior