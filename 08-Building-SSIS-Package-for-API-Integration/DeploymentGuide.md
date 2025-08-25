# SSIS Package Deployment Guide

## Objective
This guide provides step-by-step instructions for deploying and configuring the ObjectionLetterApiIntegration SSIS package for SQL Server 2012 and Visual Studio 2017 environments.

## Prerequisites

### Software Requirements
- **SQL Server 2012** or later (SQL Server Database Engine)
- **Visual Studio 2017** with SQL Server Data Tools (SSDT)
- **SQL Server Integration Services 2012** or later
- **.NET Framework 4.7.2** or later
- **Newtonsoft.Json** NuGet package for SSIS Script Components

### Permissions Required
- SQL Server database access with `db_datareader`, `db_datawriter`, and `db_ddladmin` permissions
- SSIS catalog deployment permissions (`ssis_admin` role)
- Access to the target REST API endpoint

## Step 1: Database Setup

### 1.1 Create Sample Database
Execute the provided SQL script to create the sample database and table structure:

```sql
-- Run SampleData.sql script
sqlcmd -S your_server -d master -i SampleData.sql
```

### 1.2 Verify Database Setup
Ensure the following objects are created:
- Database: `ObjectionLettersDB`
- Table: `[dbo].[ObjectionLetters]`
- Stored Procedure: `[dbo].[UpdateObjectionLetterStatus]`
- View: `[dbo].[vw_ProcessedObjectionLetters]`

## Step 2: Visual Studio 2017 SSDT Setup

### 2.1 Install Required Components
1. **SQL Server Data Tools (SSDT)** for Visual Studio 2017
2. **SQL Server Integration Services Projects** extension

### 2.2 Add NuGet Package References
For the Script Component to work with JSON serialization:

1. In Visual Studio, create a new Integration Services project
2. Add reference to `Newtonsoft.Json` version 12.0.3 (compatible with .NET 4.7.2)
3. Ensure the package is available in the Global Assembly Cache (GAC)

```bash
# Install Newtonsoft.Json to GAC (run as administrator)
gacutil /i "path\to\Newtonsoft.Json.dll"
```

## Step 3: SSIS Package Configuration

### 3.1 Import Package
1. Open Visual Studio 2017
2. Create new **Integration Services Project**
3. Import the `ObjectionLetterApiIntegration.dtsx` file
4. Or create new package and copy components from provided package

### 3.2 Configure Connection Manager
Update the OLE DB Connection Manager:
```
Server: your_sql_server_instance
Database: ObjectionLettersDB
Authentication: Windows Authentication (or SQL Server Authentication)
```

### 3.3 Configure Package Variables
Set the following package variables according to your environment:

| Variable Name | Data Type | Default Value | Description |
|---------------|-----------|---------------|-------------|
| `ApiEndpoint` | String | `https://yourserver/api/decisionReport` | REST API endpoint URL |
| `ApiUsername` | String | `your_username` | Basic Auth username |
| `ApiPassword` | String | `your_password` | Basic Auth password |
| `ConnectionString` | String | `Data Source=your_server;Initial Catalog=ObjectionLettersDB;Integrated Security=SSPI;` | Database connection string |

### 3.4 Script Component Configuration

#### Add Required References
In the Script Component, add these references:
- `System.Net.Http`
- `Newtonsoft.Json` (version 12.0.3)
- `System.Threading.Tasks`

#### Input Columns
Configure input columns to match SQL Server table:
- UB_ID (DT_I4)
- IH_CRIBNR (DT_STR, 50)
- Datum (DT_DBTIMESTAMP)
- Betreffende (DT_STR, 255)
- Aanslagnummer (DT_STR, 50)
- BM_OMSCHRIJVING (DT_STR, 500)
- Periode (DT_STR, 50)
- OpenstandBedrag (DT_NUMERIC, 18, 2)
- BestredenBedrag (DT_NUMERIC, 18, 2)
- NietBestredenBedrag (DT_NUMERIC, 18, 2)
- Kosten (DT_NUMERIC, 18, 2)
- TotaalOpenstand (DT_NUMERIC, 18, 2)
- UB_BIJZONDERHEDEN (DT_STR, 1000)
- RU_BIJZONDER (DT_STR, 1000)
- UB_DATUM (DT_DBTIMESTAMP)

#### Output Columns
**Success Output:**
- UB_ID (DT_I4)
- ProcessedDateTime (DT_DBTIMESTAMP)
- ApiResponse (DT_STR, 255)

**Error Output:**
- UB_ID (DT_I4)
- ErrorDescription (DT_STR, 1000)

## Step 4: Package Deployment

### 4.1 Deploy to SSIS Catalog

1. **Build the Project** in Visual Studio 2017
2. **Deploy to SSIS Catalog**:
   ```
   Right-click project → Deploy
   Server: your_sql_server_instance
   Path: /SSISDB/YourFolder/ObjectionLetterProject
   ```

### 4.2 Configure Environment Variables

Create SSIS environment for different deployment stages:

```sql
-- Create SSIS environment
USE SSISDB;
GO

-- Create folder
EXEC [catalog].[create_folder] @folder_name = N'ObjectionLetterProject';

-- Create environment
EXEC [catalog].[create_environment] 
    @environment_name = N'Production', 
    @folder_name = N'ObjectionLetterProject';

-- Add environment variables
EXEC [catalog].[create_environment_variable] 
    @variable_name = N'ApiEndpoint', 
    @environment_name = N'Production',
    @folder_name = N'ObjectionLetterProject',
    @data_type = N'String',
    @sensitive = 0,
    @value = N'https://production-api.yourserver.com/api/decisionReport';

EXEC [catalog].[create_environment_variable] 
    @variable_name = N'ApiUsername', 
    @environment_name = N'Production',
    @folder_name = N'ObjectionLetterProject',
    @data_type = N'String',
    @sensitive = 0,
    @value = N'production_username';

EXEC [catalog].[create_environment_variable] 
    @variable_name = N'ApiPassword', 
    @environment_name = N'Production',
    @folder_name = N'ObjectionLetterProject',
    @data_type = N'String',
    @sensitive = 1,
    @value = N'production_password';
```

## Step 5: Testing and Validation

### 5.1 Unit Testing
1. **Test with Sample Data**: Ensure sample records exist in `ObjectionLetters` table
2. **Validate API Endpoint**: Test API accessibility and authentication
3. **Execute Package**: Run package in SQL Server Management Studio

### 5.2 Integration Testing
```sql
-- Check processing results
SELECT 
    COUNT(*) as TotalRecords,
    SUM(CASE WHEN IsProcessed = 1 THEN 1 ELSE 0 END) as ProcessedRecords,
    SUM(CASE WHEN IsProcessed = 0 THEN 1 ELSE 0 END) as PendingRecords
FROM [dbo].[ObjectionLetters];

-- View processed records
SELECT * FROM [dbo].[vw_ProcessedObjectionLetters];
```

### 5.3 Error Handling Validation
1. Test with invalid API credentials
2. Test with network connectivity issues
3. Verify error logging and package failure handling

## Step 6: Production Scheduling

### 6.1 SQL Server Agent Job
Create SQL Server Agent job for automated execution:

```sql
-- Create SQL Server Agent Job
USE msdb;
GO

EXEC dbo.sp_add_job
    @job_name = N'ObjectionLetter API Integration';

EXEC dbo.sp_add_jobstep
    @job_name = N'ObjectionLetter API Integration',
    @step_name = N'Execute SSIS Package',
    @subsystem = N'SSIS',
    @command = N'/ISSERVER "\"\SSISDB\ObjectionLetterProject\ObjectionLetterApiIntegration\ObjectionLetterApiIntegration.dtsx\"" /SERVER "\"your_server\"" /Par "\"$ServerOption::LOGGING_LEVEL(Int16)\"";1 /Par "\"$ServerOption::SYNCHRONIZED(Boolean)\"";True /CALLERINFO SQLAGENT /REPORTING E',
    @retry_attempts = 3,
    @retry_interval = 5;

EXEC dbo.sp_add_schedule
    @schedule_name = N'Daily Processing',
    @freq_type = 4,
    @freq_interval = 1,
    @active_start_time = 60000; -- 06:00:00

EXEC dbo.sp_attach_schedule
    @job_name = N'ObjectionLetter API Integration',
    @schedule_name = N'Daily Processing';

EXEC dbo.sp_add_jobserver
    @job_name = N'ObjectionLetter API Integration';
```

### 6.2 Monitoring and Alerting
1. Set up SQL Server Agent job notifications
2. Configure SSIS catalog logging
3. Implement custom error handling and notifications

## Step 7: Maintenance and Troubleshooting

### 7.1 Common Issues

**Issue: Newtonsoft.Json not found**
- Solution: Install Newtonsoft.Json in GAC and ensure proper version compatibility

**Issue: API Authentication failures**
- Solution: Verify credentials and test API endpoint independently

**Issue: Connection timeout**
- Solution: Adjust HTTP client timeout settings in script component

### 7.2 Performance Optimization
1. **Batch Processing**: Consider processing records in batches for large datasets
2. **Parallel Processing**: Configure SSIS for parallel execution
3. **Indexing**: Ensure proper indexing on `IsProcessed` and `Datum` columns

### 7.3 Logging and Auditing
Monitor execution through:
- SSIS catalog execution reports
- SQL Server Agent job history
- Custom logging table for API responses

## Security Considerations

1. **Credentials Management**: Use SSIS environments for sensitive information
2. **Connection Security**: Use encrypted connections where possible
3. **API Security**: Implement proper API key management and rotation
4. **Database Security**: Follow principle of least privilege for SSIS service accounts

## Compatibility Notes

- **SQL Server 2012**: Fully compatible with SSIS 2012 features
- **Visual Studio 2017**: Requires SSDT for Visual Studio 2017
- **.NET Framework**: Targets .NET Framework 4.7.2 for compatibility
- **Newtonsoft.Json**: Version 12.0.3 recommended for stability

## Support and Documentation

For additional support:
1. Review SSIS catalog execution logs
2. Check SQL Server error logs
3. Validate API endpoint documentation
4. Test connection strings and credentials

This deployment guide ensures successful implementation of the SSIS package for API integration while maintaining compatibility with SQL Server 2012 and Visual Studio 2017 environments.