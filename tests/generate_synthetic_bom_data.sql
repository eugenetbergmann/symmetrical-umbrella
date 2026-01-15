-- Synthetic BOM Data Generation
-- Generates multi-level BOM hierarchies and transaction sequences, including edge cases

USE [MED];
GO

-- Create staging schema if not exists
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')
BEGIN
    EXEC('CREATE SCHEMA stg');
END
GO

-- Drop existing BOM staging tables
IF OBJECT_ID('stg.BOM_Hierarchy', 'U') IS NOT NULL DROP TABLE stg.BOM_Hierarchy;
IF OBJECT_ID('stg.BOM_Events_Test', 'U') IS NOT NULL DROP TABLE stg.BOM_Events_Test;
IF OBJECT_ID('stg.Production_Events', 'U') IS NOT NULL DROP TABLE stg.Production_Events;
IF OBJECT_ID('stg.Component_Consumption', 'U') IS NOT NULL DROP TABLE stg.Component_Consumption;
GO

-- Create staging tables
CREATE TABLE stg.BOM_Hierarchy (
    Parent_Item NVARCHAR(50),
    Component_Item NVARCHAR(50),
    Qty_Per DECIMAL(18,5),
    Level INT
);

CREATE TABLE stg.BOM_Events_Test (
    ITEMNMBR NVARCHAR(50),
    Event_Sequence INT,
    Event_Date DATE,
    Event_Type NVARCHAR(50), -- 'Production', 'Consumption', 'Activation', 'Deactivation'
    Qty_Change DECIMAL(18,5)
);

CREATE TABLE stg.Production_Events (
    ITEMNMBR NVARCHAR(50),
    Production_Date DATE,
    Qty_Produced DECIMAL(18,5)
);

CREATE TABLE stg.Component_Consumption (
    Component_Item NVARCHAR(50),
    Consumption_Date DATE,
    Qty_Consumed DECIMAL(18,5)
);
GO

-- Create the synthetic BOM data generation procedure
CREATE OR ALTER PROCEDURE stg.sp_generate_synthetic_bom
    @seed INT,
    @scenario NVARCHAR(50),
    @scale_factor INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- Truncate existing data
    TRUNCATE TABLE stg.BOM_Hierarchy;
    TRUNCATE TABLE stg.BOM_Events_Test;
    TRUNCATE TABLE stg.Production_Events;
    TRUNCATE TABLE stg.Component_Consumption;

    -- Set seed
    DECLARE @rand_seed BIGINT = @seed;

    -- Define items
    DECLARE @items TABLE (ITEMNMBR NVARCHAR(50), RowNum INT IDENTITY(1,1));
    INSERT INTO @items (ITEMNMBR)
    VALUES ('FINISHED_A'), ('FINISHED_B'), ('SUBASSY_C'), ('COMPONENT_D'), ('COMPONENT_E');

    -- Generate BOM hierarchy (multi-level)
    INSERT INTO stg.BOM_Hierarchy (Parent_Item, Component_Item, Qty_Per, Level)
    VALUES
        ('FINISHED_A', 'SUBASSY_C', 1.0, 1),
        ('FINISHED_A', 'COMPONENT_D', 2.0, 1),
        ('SUBASSY_C', 'COMPONENT_E', 3.0, 2),
        ('FINISHED_B', 'COMPONENT_D', 1.5, 1);

    -- Generate events
    DECLARE @item_cursor CURSOR FOR SELECT ITEMNMBR FROM @items;
    DECLARE @current_item NVARCHAR(50);
    DECLARE @i INT = 1;

    OPEN @item_cursor;
    FETCH NEXT FROM @item_cursor INTO @current_item;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Generate sequence of events
        DECLARE @event_count INT = ABS(CHECKSUM(@rand_seed + @i)) % 10 + 5;
        DECLARE @seq INT = 1;

        WHILE @seq <= @event_count
        BEGIN
            DECLARE @event_date DATE = DATEADD(DAY, (@seq - 5) * 7, GETDATE());
            DECLARE @event_type NVARCHAR(50) = CASE ABS(CHECKSUM(@rand_seed + @i + @seq)) % 4
                WHEN 0 THEN 'Production'
                WHEN 1 THEN 'Consumption'
                WHEN 2 THEN 'Activation'
                WHEN 3 THEN 'Deactivation'
            END;
            DECLARE @qty DECIMAL(18,5) = ABS(CHECKSUM(@rand_seed + @i + @seq + 100)) % 100 + 10;

            INSERT INTO stg.BOM_Events_Test (ITEMNMBR, Event_Sequence, Event_Date, Event_Type, Qty_Change)
            VALUES (@current_item, @seq, @event_date, @event_type, @qty);

            -- If production, add to production events
            IF @event_type = 'Production'
            BEGIN
                INSERT INTO stg.Production_Events (ITEMNMBR, Production_Date, Qty_Produced)
                VALUES (@current_item, @event_date, @qty);
            END

            SET @seq = @seq + 1;
        END

        -- Generate component consumption (with some mismatches for testing)
        IF ABS(CHECKSUM(@rand_seed + @i + 200)) % 2 = 0
        BEGIN
            INSERT INTO stg.Component_Consumption (Component_Item, Consumption_Date, Qty_Consumed)
            SELECT Component_Item, @event_date, Qty_Per * @qty * (0.9 + (ABS(CHECKSUM(@rand_seed + @i + 300)) % 20) / 100.0)
            FROM stg.BOM_Hierarchy
            WHERE Parent_Item = @current_item;
        END

        SET @i = @i + 1;
        FETCH NEXT FROM @item_cursor INTO @current_item;
    END

    CLOSE @item_cursor;
    DEALLOCATE @item_cursor;

    PRINT 'Synthetic BOM data generated for scenario: ' + @scenario + ', seed: ' + CAST(@seed AS NVARCHAR(10));
END
GO