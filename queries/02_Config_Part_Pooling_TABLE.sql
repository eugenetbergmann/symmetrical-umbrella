/*******************************************************************************
* Table: ETB2_Config_Part_Pooling
* Order: 02 of 17 ⚠️ DEPLOY SECOND
* 
* Dependencies (MUST exist first):
*   (none - but file 01 should be deployed first)
*
* External Tables Required:
*   (none)
*
* DEPLOYMENT METHOD:
* 1. In SSMS: Click New Query
* 2. Copy ENTIRE script below
* 3. Paste into query window
* 4. Click Execute (!) to create table and insert default data
* 5. Verify table created: SELECT * FROM dbo.ETB2_Config_Part_Pooling
*
* Expected Result: Table created with 3 rows (Dedicated, Pooled, Mixed samples)
*******************************************************************************/

-- Create Table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'dbo.ETB2_Config_Part_Pooling') AND type in (N'U'))
BEGIN
    CREATE TABLE dbo.ETB2_Config_Part_Pooling (
        ITEMNMBR VARCHAR(50) NOT NULL,
        Pooling_Classification VARCHAR(20) NOT NULL DEFAULT 'Dedicated',
        Client VARCHAR(50) NULL,
        Created_Date DATETIME NOT NULL DEFAULT GETDATE(),
        CONSTRAINT PK_ETB2_Config_Part_Pooling PRIMARY KEY (ITEMNMBR, Client)
    );
END;
GO

-- Insert Default Data
IF NOT EXISTS (SELECT * FROM dbo.ETB2_Config_Part_Pooling WHERE ITEMNMBR = 'GLOBAL_DEFAULT')
BEGIN
    INSERT INTO dbo.ETB2_Config_Part_Pooling (ITEMNMBR, Pooling_Classification, Client)
    VALUES 
        ('GLOBAL_DEFAULT', 'Dedicated', NULL),
        ('SAMPLE_ITEM_01', 'Pooled', NULL),
        ('SAMPLE_ITEM_02', 'Mixed', NULL);
END;
GO
