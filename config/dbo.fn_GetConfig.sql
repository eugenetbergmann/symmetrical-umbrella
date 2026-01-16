/*
================================================================================
Function: dbo.fn_GetConfig
Description: Hierarchical configuration lookup with Item → Client → ABC → Global fallback
Version: 2.0.0
Last Modified: 2026-01-16

Configuration Hierarchy (highest to lowest priority):
  1. Item-specific (Rolyat_Config_Items)
  2. Client-specific (Rolyat_Config_Clients)
  3. ABC Class defaults (Rolyat_Config_ABC_Defaults via Rolyat_Config_OrderSizing)
  4. Global defaults (Rolyat_Config_Global)
================================================================================
*/

IF OBJECT_ID('dbo.fn_GetConfig', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetConfig;
GO

CREATE FUNCTION dbo.fn_GetConfig (
    @ITEMNMBR NVARCHAR(50),
    @Client_ID NVARCHAR(50),
    @Config_Key NVARCHAR(100),
    @As_Of_Date DATE
)
RETURNS NVARCHAR(500)
AS
BEGIN
    DECLARE @Config_Value NVARCHAR(500);
    DECLARE @ABC_Class CHAR(1);
    
    SET @As_Of_Date = COALESCE(@As_Of_Date, CAST(GETDATE() AS DATE));
    
    -- Priority 1: Item-specific
    SELECT @Config_Value = Config_Value
    FROM dbo.Rolyat_Config_Items
    WHERE ITEMNMBR = @ITEMNMBR
      AND Config_Key = @Config_Key
      AND Effective_Date <= @As_Of_Date
      AND (Expiry_Date IS NULL OR Expiry_Date > @As_Of_Date);
    
    IF @Config_Value IS NOT NULL RETURN @Config_Value;
    
    -- Priority 2: Client-specific
    IF @Client_ID IS NOT NULL
    BEGIN
        SELECT @Config_Value = Config_Value
        FROM dbo.Rolyat_Config_Clients
        WHERE Client_ID = @Client_ID
          AND Config_Key = @Config_Key
          AND Effective_Date <= @As_Of_Date
          AND (Expiry_Date IS NULL OR Expiry_Date > @As_Of_Date);
        
        IF @Config_Value IS NOT NULL RETURN @Config_Value;
    END
    
    -- Priority 3: ABC Class defaults
    IF @ITEMNMBR IS NOT NULL
    BEGIN
        SELECT @ABC_Class = ABC_Class
        FROM dbo.Rolyat_Config_OrderSizing
        WHERE ITEMNMBR = @ITEMNMBR;
        
        IF @ABC_Class IS NOT NULL
        BEGIN
            SELECT @Config_Value = Config_Value
            FROM dbo.Rolyat_Config_ABC_Defaults
            WHERE ABC_Class = @ABC_Class
              AND Config_Key = @Config_Key
              AND Effective_Date <= @As_Of_Date
              AND (Expiry_Date IS NULL OR Expiry_Date > @As_Of_Date);
            
            IF @Config_Value IS NOT NULL RETURN @Config_Value;
        END
    END
    
    -- Priority 4: Global defaults
    SELECT @Config_Value = Config_Value
    FROM dbo.Rolyat_Config_Global
    WHERE Config_Key = @Config_Key
      AND Effective_Date <= @As_Of_Date
      AND (Expiry_Date IS NULL OR Expiry_Date > @As_Of_Date);
    
    RETURN @Config_Value;
END
GO

-- Helper: fn_GetConfigInt
IF OBJECT_ID('dbo.fn_GetConfigInt', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetConfigInt;
GO

CREATE FUNCTION dbo.fn_GetConfigInt (
    @ITEMNMBR NVARCHAR(50),
    @Client_ID NVARCHAR(50),
    @Config_Key NVARCHAR(100),
    @As_Of_Date DATE,
    @Default_Value INT
)
RETURNS INT
AS
BEGIN
    RETURN COALESCE(TRY_CAST(dbo.fn_GetConfig(@ITEMNMBR, @Client_ID, @Config_Key, @As_Of_Date) AS INT), @Default_Value);
END
GO

-- Helper: fn_GetConfigDecimal
IF OBJECT_ID('dbo.fn_GetConfigDecimal', 'FN') IS NOT NULL
    DROP FUNCTION dbo.fn_GetConfigDecimal;
GO

CREATE FUNCTION dbo.fn_GetConfigDecimal (
    @ITEMNMBR NVARCHAR(50),
    @Client_ID NVARCHAR(50),
    @Config_Key NVARCHAR(100),
    @As_Of_Date DATE,
    @Default_Value DECIMAL(18,5)
)
RETURNS DECIMAL(18,5)
AS
BEGIN
    RETURN COALESCE(TRY_CAST(dbo.fn_GetConfig(@ITEMNMBR, @Client_ID, @Config_Key, @As_Of_Date) AS DECIMAL(18,5)), @Default_Value);
END
GO

-- Inline TVF: fn_GetActiveWindow
IF OBJECT_ID('dbo.fn_GetActiveWindow', 'IF') IS NOT NULL
    DROP FUNCTION dbo.fn_GetActiveWindow;
GO

CREATE FUNCTION dbo.fn_GetActiveWindow (
    @ITEMNMBR NVARCHAR(50),
    @Client_ID NVARCHAR(50),
    @As_Of_Date DATE
)
RETURNS TABLE
AS
RETURN (
    SELECT
        DATEADD(DAY, 
            -COALESCE(
                (SELECT TRY_CAST(Config_Value AS INT) FROM dbo.Rolyat_Config_Items 
                 WHERE ITEMNMBR = @ITEMNMBR AND Config_Key = 'ActiveWindow_Past_Days'
                 AND Effective_Date <= @As_Of_Date AND (Expiry_Date IS NULL OR Expiry_Date > @As_Of_Date)),
                (SELECT TRY_CAST(Config_Value AS INT) FROM dbo.Rolyat_Config_Clients 
                 WHERE Client_ID = @Client_ID AND Config_Key = 'ActiveWindow_Past_Days'
                 AND Effective_Date <= @As_Of_Date AND (Expiry_Date IS NULL OR Expiry_Date > @As_Of_Date)),
                (SELECT TRY_CAST(Config_Value AS INT) FROM dbo.Rolyat_Config_Global 
                 WHERE Config_Key = 'ActiveWindow_Past_Days'
                 AND Effective_Date <= @As_Of_Date AND (Expiry_Date IS NULL OR Expiry_Date > @As_Of_Date)),
                21
            ),
            @As_Of_Date
        ) AS Window_Start,
        DATEADD(DAY, 
            COALESCE(
                (SELECT TRY_CAST(Config_Value AS INT) FROM dbo.Rolyat_Config_Items 
                 WHERE ITEMNMBR = @ITEMNMBR AND Config_Key = 'ActiveWindow_Future_Days'
                 AND Effective_Date <= @As_Of_Date AND (Expiry_Date IS NULL OR Expiry_Date > @As_Of_Date)),
                (SELECT TRY_CAST(Config_Value AS INT) FROM dbo.Rolyat_Config_Clients 
                 WHERE Client_ID = @Client_ID AND Config_Key = 'ActiveWindow_Future_Days'
                 AND Effective_Date <= @As_Of_Date AND (Expiry_Date IS NULL OR Expiry_Date > @As_Of_Date)),
                (SELECT TRY_CAST(Config_Value AS INT) FROM dbo.Rolyat_Config_Global 
                 WHERE Config_Key = 'ActiveWindow_Future_Days'
                 AND Effective_Date <= @As_Of_Date AND (Expiry_Date IS NULL OR Expiry_Date > @As_Of_Date)),
                21
            ),
            @As_Of_Date
        ) AS Window_End
);
GO

PRINT 'Rolyat Configuration Functions created successfully.';
GO
