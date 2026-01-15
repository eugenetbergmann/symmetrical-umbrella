-- Synthetic Data Generation for Rolyat Pipeline Testing
-- Creates staging schema and tables, populates with parameterized synthetic data

USE [MED];
GO

-- Create staging schema if not exists
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'stg')
BEGIN
    EXEC('CREATE SCHEMA stg');
END
GO

-- Drop existing staging tables if they exist
IF OBJECT_ID('stg.Synthetic_Demand', 'U') IS NOT NULL DROP TABLE stg.Synthetic_Demand;
IF OBJECT_ID('stg.Synthetic_PO', 'U') IS NOT NULL DROP TABLE stg.Synthetic_PO;
IF OBJECT_ID('stg.Synthetic_WFQ', 'U') IS NOT NULL DROP TABLE stg.Synthetic_WFQ;
IF OBJECT_ID('stg.Synthetic_RMQTY', 'U') IS NOT NULL DROP TABLE stg.Synthetic_RMQTY;
IF OBJECT_ID('stg.Synthetic_BeginningBalance', 'U') IS NOT NULL DROP TABLE stg.Synthetic_BeginningBalance;
GO

-- Create staging tables
CREATE TABLE stg.Synthetic_Demand (
    ItemNMBR NVARCHAR(50),
    EventType NVARCHAR(50), -- 'DEMAND', 'EXPIRY'
    DUEDATE DATE,
    Quantity DECIMAL(18,5),
    PO_ID NVARCHAR(50) NULL,
    ExpiryDate DATE NULL,
    OtherMetadata NVARCHAR(MAX) NULL
);

CREATE TABLE stg.Synthetic_PO (
    PO_ID NVARCHAR(50),
    ItemNMBR NVARCHAR(50),
    PO_DUEDATE DATE,
    PO_QTY DECIMAL(18,5),
    PURCHASING_LT INT DEFAULT 7,
    PLANNING_LT INT DEFAULT 7
);

CREATE TABLE stg.Synthetic_WFQ (
    ItemNMBR NVARCHAR(50),
    WFQ_QTY DECIMAL(18,5)
);

CREATE TABLE stg.Synthetic_RMQTY (
    ItemNMBR NVARCHAR(50),
    RMQTY_QTY DECIMAL(18,5)
);

CREATE TABLE stg.Synthetic_BeginningBalance (
    ItemNMBR NVARCHAR(50),
    DUEDATE DATE,
    Quantity DECIMAL(18,5)
);
GO

-- Create the synthetic data generation procedure
CREATE OR ALTER PROCEDURE stg.sp_generate_synthetic
    @seed INT,
    @scenario NVARCHAR(50),
    @scale_factor INT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- Truncate existing data
    TRUNCATE TABLE stg.Synthetic_Demand;
    TRUNCATE TABLE stg.Synthetic_PO;
    TRUNCATE TABLE stg.Synthetic_WFQ;
    TRUNCATE TABLE stg.Synthetic_RMQTY;
    TRUNCATE TABLE stg.Synthetic_BeginningBalance;

    -- Set seed for reproducibility
    DECLARE @rand_seed BIGINT = @seed;

    -- Define canonical items (include 10.020B as example)
    DECLARE @items TABLE (ItemNMBR NVARCHAR(50), RowNum INT IDENTITY(1,1));
    INSERT INTO @items (ItemNMBR)
    VALUES ('10.020B'), ('20.001A'), ('30.005C'), ('40.010D'), ('50.015E');

    -- Generate data based on scenario
    DECLARE @item_cursor CURSOR FOR SELECT ItemNMBR FROM @items;
    DECLARE @current_item NVARCHAR(50);
    DECLARE @i INT = 1;

    OPEN @item_cursor;
    FETCH NEXT FROM @item_cursor INTO @current_item;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Generate beginning balance
        INSERT INTO stg.Synthetic_BeginningBalance (ItemNMBR, DUEDATE, Quantity)
        VALUES (
            @current_item,
            DATEADD(DAY, -ABS(CHECKSUM(@rand_seed + @i)) % 30, GETDATE()),
            ABS(CHECKSUM(@rand_seed + @i + 100)) % 100 + 10
        );

        -- Generate POs
        DECLARE @po_count INT = ABS(CHECKSUM(@rand_seed + @i + 200)) % 5 + 1;
        DECLARE @po_idx INT = 1;

        WHILE @po_idx <= @po_count
        BEGIN
            DECLARE @po_id NVARCHAR(50) = 'PO_' + @current_item + '_' + CAST(@po_idx AS NVARCHAR(10));
            DECLARE @po_duedate DATE = DATEADD(DAY, -ABS(CHECKSUM(@rand_seed + @i + @po_idx + 300)) % 60, GETDATE());
            DECLARE @po_qty DECIMAL(18,5) = ABS(CHECKSUM(@rand_seed + @i + @po_idx + 400)) % 200 + 50;

            INSERT INTO stg.Synthetic_PO (PO_ID, ItemNMBR, PO_DUEDATE, PO_QTY, PURCHASING_LT, PLANNING_LT)
            VALUES (@po_id, @current_item, @po_duedate, @po_qty, 7, 7);

            -- Generate corresponding demand event (sometimes same-day)
            IF ABS(CHECKSUM(@rand_seed + @i + @po_idx + 500)) % 2 = 0
            BEGIN
                INSERT INTO stg.Synthetic_Demand (ItemNMBR, EventType, DUEDATE, Quantity, PO_ID, ExpiryDate)
                VALUES (@current_item, 'DEMAND', @po_duedate, @po_qty * 0.8, @po_id, NULL);
            END
            ELSE
            BEGIN
                INSERT INTO stg.Synthetic_Demand (ItemNMBR, EventType, DUEDATE, Quantity, PO_ID, ExpiryDate)
                VALUES (@current_item, 'DEMAND', DATEADD(DAY, ABS(CHECKSUM(@rand_seed + @i + @po_idx + 600)) % 30, @po_duedate), @po_qty * 0.8, @po_id, NULL);
            END

            SET @po_idx = @po_idx + 1;
        END

        -- Generate additional demands across ±60 day window
        DECLARE @demand_count INT = ABS(CHECKSUM(@rand_seed + @i + 700)) % 10 + 5;
        DECLARE @demand_idx INT = 1;

        WHILE @demand_idx <= @demand_count
        BEGIN
            INSERT INTO stg.Synthetic_Demand (ItemNMBR, EventType, DUEDATE, Quantity, PO_ID, ExpiryDate)
            VALUES (
                @current_item,
                'DEMAND',
                DATEADD(DAY, (CHECKSUM(@rand_seed + @i + @demand_idx + 800) % 120) - 60, GETDATE()),
                ABS(CHECKSUM(@rand_seed + @i + @demand_idx + 900)) % 50 + 5,
                NULL,
                NULL
            );

            SET @demand_idx = @demand_idx + 1;
        END

        -- Generate expiry events
        IF ABS(CHECKSUM(@rand_seed + @i + 1000)) % 3 = 0
        BEGIN
            INSERT INTO stg.Synthetic_Demand (ItemNMBR, EventType, DUEDATE, Quantity, PO_ID, ExpiryDate)
            VALUES (
                @current_item,
                'EXPIRY',
                DATEADD(DAY, ABS(CHECKSUM(@rand_seed + @i + 1100)) % 30, GETDATE()),
                ABS(CHECKSUM(@rand_seed + @i + 1200)) % 20 + 5,
                NULL,
                DATEADD(DAY, ABS(CHECKSUM(@rand_seed + @i + 1300)) % 30, GETDATE())
            );
        END

        -- Generate WFQ and RMQTY
        INSERT INTO stg.Synthetic_WFQ (ItemNMBR, WFQ_QTY)
        VALUES (@current_item, ABS(CHECKSUM(@rand_seed + @i + 1400)) % 100);

        INSERT INTO stg.Synthetic_RMQTY (ItemNMBR, RMQTY_QTY)
        VALUES (@current_item, ABS(CHECKSUM(@rand_seed + @i + 1500)) % 50);

        SET @i = @i + 1;
        FETCH NEXT FROM @item_cursor INTO @current_item;
    END

    CLOSE @item_cursor;
    DEALLOCATE @item_cursor;

    -- Special case for 10.020B: ensure same-day PO offsets negative drift
    -- (This is hardcoded to match the example scenario)
    DELETE FROM stg.Synthetic_Demand WHERE ItemNMBR = '10.020B';
    DELETE FROM stg.Synthetic_PO WHERE ItemNMBR = '10.020B';
    DELETE FROM stg.Synthetic_BeginningBalance WHERE ItemNMBR = '10.020B';

    -- Beginning balance
    INSERT INTO stg.Synthetic_BeginningBalance (ItemNMBR, DUEDATE, Quantity)
    VALUES ('10.020B', DATEADD(DAY, -10, GETDATE()), 50);

    -- Demand that creates negative balance
    INSERT INTO stg.Synthetic_Demand (ItemNMBR, EventType, DUEDATE, Quantity)
    VALUES ('10.020B', 'DEMAND', GETDATE(), 60);

    -- Same-day PO that offsets
    INSERT INTO stg.Synthetic_PO (PO_ID, ItemNMBR, PO_DUEDATE, PO_QTY)
    VALUES ('PO_10.020B_1', '10.020B', GETDATE(), 20);

    -- WFQ and RMQTY zero for this test
    UPDATE stg.Synthetic_WFQ SET WFQ_QTY = 0 WHERE ItemNMBR = '10.020B';
    UPDATE stg.Synthetic_RMQTY SET RMQTY_QTY = 0 WHERE ItemNMBR = '10.020B';

    PRINT 'Synthetic data generated for scenario: ' + @scenario + ', seed: ' + CAST(@seed AS NVARCHAR(10));
END
GO