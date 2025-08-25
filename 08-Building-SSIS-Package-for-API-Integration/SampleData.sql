-- =============================================
-- Sample SQL Table Structure for ObjectionLetters
-- Compatible with SQL Server 2012 and later
-- =============================================

-- Create the database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'ObjectionLettersDB')
BEGIN
    CREATE DATABASE ObjectionLettersDB;
END
GO

USE ObjectionLettersDB;
GO

-- Create the ObjectionLetters table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[ObjectionLetters]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[ObjectionLetters] (
        [UB_ID] [int] IDENTITY(1,1) NOT NULL,
        [IH_CRIBNR] [varchar](50) NOT NULL,
        [Datum] [datetime] NOT NULL,
        [Betreffende] [varchar](255) NULL,
        [Aanslagnummer] [varchar](50) NOT NULL,
        [BM_OMSCHRIJVING] [varchar](500) NULL,
        [Periode] [varchar](50) NULL,
        [OpenstandBedrag] [decimal](18, 2) NULL DEFAULT (0),
        [BestredenBedrag] [decimal](18, 2) NULL DEFAULT (0),
        [NietBestredenBedrag] [decimal](18, 2) NULL DEFAULT (0),
        [Kosten] [decimal](18, 2) NULL DEFAULT (0),
        [TotaalOpenstand] [decimal](18, 2) NULL DEFAULT (0),
        [UB_BIJZONDERHEDEN] [varchar](1000) NULL,
        [RU_BIJZONDER] [varchar](1000) NULL,
        [UB_DATUM] [datetime] NOT NULL DEFAULT (GETDATE()),
        [IsProcessed] [bit] NOT NULL DEFAULT (0),
        [ProcessedDate] [datetime] NULL,
        [ApiResponseStatus] [varchar](10) NULL,
        [ErrorMessage] [varchar](1000) NULL,
        CONSTRAINT [PK_ObjectionLetters] PRIMARY KEY CLUSTERED ([UB_ID] ASC)
    );
END
GO

-- Create index for performance on frequently queried columns
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[ObjectionLetters]') AND name = N'IX_ObjectionLetters_IsProcessed')
BEGIN
    CREATE NONCLUSTERED INDEX [IX_ObjectionLetters_IsProcessed] ON [dbo].[ObjectionLetters] ([IsProcessed]) INCLUDE ([UB_ID], [IH_CRIBNR], [Datum]);
END
GO

-- Insert sample data for testing
MERGE [dbo].[ObjectionLetters] AS target
USING (
    VALUES 
        ('IH001', '2024-01-15 10:30:00', 'Tax Assessment Objection', 'AN2024001', 'Income Tax Assessment Dispute', '2023', 5000.00, 3000.00, 2000.00, 150.00, 5150.00, 'Disputed calculation method', 'Requires legal review', '2024-01-15 14:20:00'),
        ('IH002', '2024-01-16 09:15:00', 'Property Tax Objection', 'AN2024002', 'Property Valuation Dispute', '2023', 8000.00, 8000.00, 0.00, 200.00, 8200.00, 'Property value incorrect', 'New appraisal needed', '2024-01-16 11:45:00'),
        ('IH003', '2024-01-17 14:00:00', 'VAT Assessment Objection', 'AN2024003', 'VAT Calculation Error', 'Q4 2023', 2500.00, 1500.00, 1000.00, 75.00, 2575.00, 'VAT rate applied incorrectly', 'Supporting documentation provided', '2024-01-17 16:30:00'),
        ('IH004', '2024-01-18 11:20:00', 'Corporate Tax Objection', 'AN2024004', 'Deduction Disallowance', '2023', 12000.00, 10000.00, 2000.00, 300.00, 12300.00, 'Business expense wrongly disallowed', 'Appeal in progress', '2024-01-18 13:15:00'),
        ('IH005', '2024-01-19 08:45:00', 'Personal Income Tax', 'AN2024005', 'Withholding Tax Error', '2023', 1800.00, 1800.00, 0.00, 50.00, 1850.00, 'Incorrect withholding calculation', 'Employer error confirmed', '2024-01-19 10:20:00')
) AS source (IH_CRIBNR, Datum, Betreffende, Aanslagnummer, BM_OMSCHRIJVING, Periode, OpenstandBedrag, BestredenBedrag, NietBestredenBedrag, Kosten, TotaalOpenstand, UB_BIJZONDERHEDEN, RU_BIJZONDER, UB_DATUM)
ON target.IH_CRIBNR = source.IH_CRIBNR
WHEN NOT MATCHED THEN
    INSERT (IH_CRIBNR, Datum, Betreffende, Aanslagnummer, BM_OMSCHRIJVING, Periode, OpenstandBedrag, BestredenBedrag, NietBestredenBedrag, Kosten, TotaalOpenstand, UB_BIJZONDERHEDEN, RU_BIJZONDER, UB_DATUM)
    VALUES (source.IH_CRIBNR, source.Datum, source.Betreffende, source.Aanslagnummer, source.BM_OMSCHRIJVING, source.Periode, source.OpenstandBedrag, source.BestredenBedrag, source.NietBestredenBedrag, source.Kosten, source.TotaalOpenstand, source.UB_BIJZONDERHEDEN, source.RU_BIJZONDER, source.UB_DATUM);

-- Query to select records that need to be processed by SSIS
-- This query should be used in the OLE DB Source component
SELECT 
    UB_ID,
    IH_CRIBNR,
    Datum,
    Betreffende,
    Aanslagnummer,
    BM_OMSCHRIJVING,
    Periode,
    OpenstandBedrag,
    BestredenBedrag,
    NietBestredenBedrag,
    Kosten,
    TotaalOpenstand,
    UB_BIJZONDERHEDEN,
    RU_BIJZONDER,
    UB_DATUM
FROM [dbo].[ObjectionLetters]
WHERE IsProcessed = 0
    AND Datum >= DATEADD(day, -30, GETDATE()) -- Only process records from last 30 days
ORDER BY UB_ID;

-- Stored procedure to update processing status
CREATE OR ALTER PROCEDURE [dbo].[UpdateObjectionLetterStatus]
    @UB_ID INT,
    @ApiResponseStatus VARCHAR(10),
    @ErrorMessage VARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    UPDATE [dbo].[ObjectionLetters]
    SET 
        IsProcessed = CASE WHEN @ApiResponseStatus = 'Success' THEN 1 ELSE 0 END,
        ProcessedDate = CASE WHEN @ApiResponseStatus = 'Success' THEN GETDATE() ELSE NULL END,
        ApiResponseStatus = @ApiResponseStatus,
        ErrorMessage = @ErrorMessage
    WHERE UB_ID = @UB_ID;
END
GO

-- View for reporting processed records
CREATE OR ALTER VIEW [dbo].[vw_ProcessedObjectionLetters]
AS
SELECT 
    UB_ID,
    IH_CRIBNR,
    Datum,
    Betreffende,
    Aanslagnummer,
    ProcessedDate,
    ApiResponseStatus,
    ErrorMessage,
    TotaalOpenstand
FROM [dbo].[ObjectionLetters]
WHERE IsProcessed = 1;
GO

-- Grant permissions (adjust as needed for your environment)
-- GRANT SELECT, UPDATE ON [dbo].[ObjectionLetters] TO [SSIS_ServiceAccount];
-- GRANT EXECUTE ON [dbo].[UpdateObjectionLetterStatus] TO [SSIS_ServiceAccount];

PRINT 'Sample database and table structure created successfully.';
PRINT 'Records available for processing: ' + CAST((SELECT COUNT(*) FROM [dbo].[ObjectionLetters] WHERE IsProcessed = 0) AS VARCHAR(10));