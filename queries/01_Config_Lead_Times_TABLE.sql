/*******************************************************************************
* Table: ETB2_Config_Lead_Times
* Order: 01 of 17 ⚠️ DEPLOY FIRST
* 
* Dependencies (MUST exist first):
*   (none - this is the first object)
*
* External Tables Required:
*   (none)
*
* DEPLOYMENT METHOD:
* 1. In SSMS: Click New Query
* 2. Copy ENTIRE script below
* 3. Paste into query window
* 4. Click Execute (!) to create table and insert default data
* 5. Verify table created: SELECT * FROM dbo.ETB2_Config_Lead_Times
*
* Expected Result: Table created with 2-3 rows (global default + samples)
*******************************************************************************/

-- Create Table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.ETB2_Config_Lead_Times') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.ETB2_Config_Lead_Times (
        ITEMNMBR VARCHAR(50) NOT NULL,
        Lead_Time_Days INT NOT NULL DEFAULT 30,
        Client VARCHAR(50) NULL,
        Created_Date DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT PK_ETB2_Config_Lead_Times PRIMARY KEY (ITEMNMBR, Client)
    );
END;
GO

-- Insert Default Data
IF NOT EXISTS (SELECT * FROM dbo.ETB2_Config_Lead_Times WHERE ITEMNMBR = 'GLOBAL_DEFAULT')
BEGIN
    INSERT INTO dbo.ETB2_Config_Lead_Times (ITEMNMBR, Lead_Time_Days, Client)
    VALUES 
        ('GLOBAL_DEFAULT', 30, NULL),
        ('SAMPLE_ITEM_01', 14, NULL),
        ('SAMPLE_ITEM_02', 21, NULL);
END;
GO
