#!/bin/bash

# SSIS Package Deployment Script
# This script automates the deployment process for the ObjectionLetterApiIntegration package

echo "=== SSIS Package Deployment Script ==="
echo "Deploying ObjectionLetterApiIntegration package..."

# Configuration variables
SQL_SERVER="${SQL_SERVER:-localhost}"
DATABASE_NAME="${DATABASE_NAME:-ObjectionLettersDB}"
SSIS_FOLDER="${SSIS_FOLDER:-ObjectionLetterProject}"
PACKAGE_NAME="${PACKAGE_NAME:-ObjectionLetterApiIntegration}"
API_ENDPOINT="${API_ENDPOINT:-https://yourserver/api/decisionReport}"
API_USERNAME="${API_USERNAME:-your_username}"
API_PASSWORD="${API_PASSWORD:-your_password}"

echo "Configuration:"
echo "  SQL Server: $SQL_SERVER"
echo "  Database: $DATABASE_NAME"
echo "  SSIS Folder: $SSIS_FOLDER"
echo "  Package: $PACKAGE_NAME"
echo "  API Endpoint: $API_ENDPOINT"
echo ""

# Function to execute SQL command
execute_sql() {
    local sql_command="$1"
    local description="$2"
    
    echo "Executing: $description"
    sqlcmd -S "$SQL_SERVER" -d "$DATABASE_NAME" -Q "$sql_command" -b
    
    if [ $? -eq 0 ]; then
        echo "✅ Success: $description"
    else
        echo "❌ Failed: $description"
        exit 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check if sqlcmd is available
    if ! command -v sqlcmd &> /dev/null; then
        echo "❌ sqlcmd is not installed or not in PATH"
        exit 1
    fi
    
    # Check SQL Server connectivity
    sqlcmd -S "$SQL_SERVER" -Q "SELECT @@VERSION" -b > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ SQL Server connection successful"
    else
        echo "❌ Cannot connect to SQL Server: $SQL_SERVER"
        exit 1
    fi
}

# Function to create database and tables
setup_database() {
    echo ""
    echo "=== Setting up database ==="
    
    # Create database if it doesn't exist
    execute_sql "
    IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = '$DATABASE_NAME')
    BEGIN
        CREATE DATABASE [$DATABASE_NAME];
        PRINT 'Database $DATABASE_NAME created successfully.';
    END
    ELSE
    BEGIN
        PRINT 'Database $DATABASE_NAME already exists.';
    END
    " "Create database $DATABASE_NAME"
    
    # Run the SampleData.sql script
    echo "Executing SampleData.sql..."
    sqlcmd -S "$SQL_SERVER" -i "SampleData.sql" -b
    
    if [ $? -eq 0 ]; then
        echo "✅ Database setup completed successfully"
    else
        echo "❌ Database setup failed"
        exit 1
    fi
}

# Function to setup SSIS catalog
setup_ssis_catalog() {
    echo ""
    echo "=== Setting up SSIS catalog ==="
    
    # Check if SSIS catalog exists
    execute_sql "
    IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'SSISDB')
    BEGIN
        PRINT 'SSIS catalog does not exist. Please create it manually using SQL Server Management Studio.';
        PRINT 'Go to Integration Services Catalogs -> Right-click -> Create Catalog';
        THROW 50000, 'SSIS catalog not found', 1;
    END
    ELSE
    BEGIN
        PRINT 'SSIS catalog exists.';
    END
    " "Check SSIS catalog"
    
    # Create SSIS folder
    execute_sql "
    USE SSISDB;
    IF NOT EXISTS (SELECT folder_id FROM [catalog].[folders] WHERE name = '$SSIS_FOLDER')
    BEGIN
        EXEC [catalog].[create_folder] @folder_name = N'$SSIS_FOLDER';
        PRINT 'SSIS folder $SSIS_FOLDER created.';
    END
    ELSE
    BEGIN
        PRINT 'SSIS folder $SSIS_FOLDER already exists.';
    END
    " "Create SSIS folder"
}

# Function to create SSIS environment
create_ssis_environment() {
    echo ""
    echo "=== Creating SSIS environment ==="
    
    execute_sql "
    USE SSISDB;
    
    -- Create environment
    IF NOT EXISTS (SELECT environment_id FROM [catalog].[environments] WHERE name = 'Production' AND folder_name = '$SSIS_FOLDER')
    BEGIN
        EXEC [catalog].[create_environment] 
            @environment_name = N'Production', 
            @folder_name = N'$SSIS_FOLDER';
        PRINT 'SSIS environment Production created.';
    END
    ELSE
    BEGIN
        PRINT 'SSIS environment Production already exists.';
    END
    
    -- Create environment variables
    IF NOT EXISTS (SELECT * FROM [catalog].[environment_variables] 
                   WHERE environment_name = 'Production' 
                   AND name = 'ApiEndpoint')
    BEGIN
        EXEC [catalog].[create_environment_variable] 
            @variable_name = N'ApiEndpoint', 
            @environment_name = N'Production',
            @folder_name = N'$SSIS_FOLDER',
            @data_type = N'String',
            @sensitive = 0,
            @value = N'$API_ENDPOINT';
    END
    
    IF NOT EXISTS (SELECT * FROM [catalog].[environment_variables] 
                   WHERE environment_name = 'Production' 
                   AND name = 'ApiUsername')
    BEGIN
        EXEC [catalog].[create_environment_variable] 
            @variable_name = N'ApiUsername', 
            @environment_name = N'Production',
            @folder_name = N'$SSIS_FOLDER',
            @data_type = N'String',
            @sensitive = 0,
            @value = N'$API_USERNAME';
    END
    
    IF NOT EXISTS (SELECT * FROM [catalog].[environment_variables] 
                   WHERE environment_name = 'Production' 
                   AND name = 'ApiPassword')
    BEGIN
        EXEC [catalog].[create_environment_variable] 
            @variable_name = N'ApiPassword', 
            @environment_name = N'Production',
            @folder_name = N'$SSIS_FOLDER',
            @data_type = N'String',
            @sensitive = 1,
            @value = N'$API_PASSWORD';
    END
    
    PRINT 'SSIS environment variables configured.';
    " "Create SSIS environment variables"
}

# Function to create SQL Server Agent job
create_agent_job() {
    echo ""
    echo "=== Creating SQL Server Agent job ==="
    
    execute_sql "
    USE msdb;
    
    -- Delete existing job if it exists
    IF EXISTS (SELECT job_id FROM dbo.sysjobs WHERE name = N'$PACKAGE_NAME')
    BEGIN
        EXEC dbo.sp_delete_job @job_name = N'$PACKAGE_NAME';
        PRINT 'Existing job deleted.';
    END
    
    -- Create new job
    EXEC dbo.sp_add_job
        @job_name = N'$PACKAGE_NAME',
        @description = N'Automated execution of ObjectionLetter API Integration package';
    
    -- Add job step
    EXEC dbo.sp_add_jobstep
        @job_name = N'$PACKAGE_NAME',
        @step_name = N'Execute SSIS Package',
        @subsystem = N'SSIS',
        @command = N'/ISSERVER \"\\\"\SSISDB\\$SSIS_FOLDER\\$PACKAGE_NAME\\$PACKAGE_NAME.dtsx\\\"\" /SERVER \"\\\"$SQL_SERVER\\\"\" /Par \"\\\"\$ServerOption::LOGGING_LEVEL(Int16)\\\"\";1 /Par \"\\\"\$ServerOption::SYNCHRONIZED(Boolean)\\\"\";True /CALLERINFO SQLAGENT /REPORTING E',
        @retry_attempts = 3,
        @retry_interval = 5;
    
    -- Add schedule (daily at 6 AM)
    EXEC dbo.sp_add_schedule
        @schedule_name = N'Daily Processing - $PACKAGE_NAME',
        @freq_type = 4,
        @freq_interval = 1,
        @active_start_time = 60000;
    
    -- Attach schedule to job
    EXEC dbo.sp_attach_schedule
        @job_name = N'$PACKAGE_NAME',
        @schedule_name = N'Daily Processing - $PACKAGE_NAME';
    
    -- Add job to server
    EXEC dbo.sp_add_jobserver
        @job_name = N'$PACKAGE_NAME';
    
    PRINT 'SQL Server Agent job created successfully.';
    " "Create SQL Server Agent job"
}

# Function to validate deployment
validate_deployment() {
    echo ""
    echo "=== Validating deployment ==="
    
    # Check database objects
    execute_sql "
    USE $DATABASE_NAME;
    
    DECLARE @ObjectCount INT;
    
    -- Check table exists
    SELECT @ObjectCount = COUNT(*) FROM sys.objects WHERE name = 'ObjectionLetters' AND type = 'U';
    IF @ObjectCount = 0 THROW 50000, 'ObjectionLetters table not found', 1;
    
    -- Check stored procedure exists
    SELECT @ObjectCount = COUNT(*) FROM sys.objects WHERE name = 'UpdateObjectionLetterStatus' AND type = 'P';
    IF @ObjectCount = 0 THROW 50000, 'UpdateObjectionLetterStatus procedure not found', 1;
    
    -- Check view exists
    SELECT @ObjectCount = COUNT(*) FROM sys.objects WHERE name = 'vw_ProcessedObjectionLetters' AND type = 'V';
    IF @ObjectCount = 0 THROW 50000, 'vw_ProcessedObjectionLetters view not found', 1;
    
    -- Check sample data
    SELECT @ObjectCount = COUNT(*) FROM [dbo].[ObjectionLetters];
    IF @ObjectCount = 0 THROW 50000, 'No sample data found in ObjectionLetters table', 1;
    
    PRINT 'Database validation passed. Objects found:';
    PRINT '  - ObjectionLetters table: 1';
    PRINT '  - UpdateObjectionLetterStatus procedure: 1';
    PRINT '  - vw_ProcessedObjectionLetters view: 1';
    PRINT '  - Sample records: ' + CAST(@ObjectCount AS VARCHAR(10));
    " "Validate database objects"
    
    echo "✅ Deployment validation completed successfully"
}

# Function to display next steps
show_next_steps() {
    echo ""
    echo "=== Deployment Complete ==="
    echo ""
    echo "📋 Next Steps:"
    echo "1. Open Visual Studio 2017 with SSDT"
    echo "2. Import the ObjectionLetterApiIntegration.dtsx package"
    echo "3. Configure the Script Component with the provided ScriptComponent.cs code"
    echo "4. Add reference to Newtonsoft.Json in the Script Component"
    echo "5. Deploy the package to the SSIS catalog folder: $SSIS_FOLDER"
    echo "6. Configure environment references for the deployed package"
    echo "7. Test the package execution"
    echo ""
    echo "📁 Files created:"
    echo "  - Database: $DATABASE_NAME"
    echo "  - SSIS Folder: SSISDB/$SSIS_FOLDER"
    echo "  - Environment: Production"
    echo "  - SQL Agent Job: $PACKAGE_NAME"
    echo ""
    echo "🔧 Configuration:"
    echo "  - API Endpoint: $API_ENDPOINT"
    echo "  - API Username: $API_USERNAME"
    echo "  - Connection String: Data Source=$SQL_SERVER;Initial Catalog=$DATABASE_NAME;Integrated Security=SSPI;"
    echo ""
    echo "📖 For detailed instructions, see DeploymentGuide.md"
}

# Main execution
main() {
    echo "Starting deployment process..."
    echo ""
    
    check_prerequisites
    setup_database
    setup_ssis_catalog
    create_ssis_environment
    create_agent_job
    validate_deployment
    show_next_steps
    
    echo ""
    echo "🎉 Deployment script completed successfully!"
}

# Execute main function
main "$@"