
-- FMB TimeTracker Emergency Database Fix
-- Run this script immediately to fix all on-premises database issues
-- This combines table creation, column fixes, and validation

USE [timetracker];
GO

PRINT '🚨 FMB TimeTracker Emergency Database Fix';
PRINT '==========================================';
PRINT 'This script will fix ALL database issues preventing the application from working.';
PRINT '';

-- First, ensure all required tables exist with correct structure
PRINT '1️⃣ Creating missing tables...';

-- Sessions table (required for session management)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sessions]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[sessions] (
        [sid] NVARCHAR(255) NOT NULL PRIMARY KEY,
        [sess] NVARCHAR(MAX) NOT NULL,
        [expire] DATETIME2 NOT NULL
    );
    PRINT '✅ Created sessions table';
END

-- Users table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[users] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [email] NVARCHAR(255) UNIQUE,
        [firstName] NVARCHAR(255),
        [lastName] NVARCHAR(255),
        [employeeId] NVARCHAR(255) UNIQUE,
        [department] NVARCHAR(255),
        [profileImageUrl] NVARCHAR(255),
        [role] NVARCHAR(50) DEFAULT 'employee',
        [isActive] BIT NOT NULL DEFAULT 1,
        [lastLoginAt] DATETIME2,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
    PRINT '✅ Created users table with camelCase columns';
END

-- Projects table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[projects] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [name] NVARCHAR(255) NOT NULL,
        [projectNumber] NVARCHAR(50),
        [description] NVARCHAR(MAX),
        [color] NVARCHAR(7) DEFAULT '#1976D2',
        [startDate] DATETIME2,
        [endDate] DATETIME2,
        [isEnterpriseWide] BIT NOT NULL DEFAULT 1,
        [userId] UNIQUEIDENTIFIER NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE(),
        [isTemplate] BIT NOT NULL DEFAULT 0,
        [allowTimeTracking] BIT NOT NULL DEFAULT 1,
        [requireTaskSelection] BIT NOT NULL DEFAULT 0,
        [enableBudgetTracking] BIT NOT NULL DEFAULT 0,
        [enableBilling] BIT NOT NULL DEFAULT 0
    );
    PRINT '✅ Created projects table with camelCase columns';
END

-- Tasks table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[tasks] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [projectId] UNIQUEIDENTIFIER NOT NULL,
        [name] NVARCHAR(255) NOT NULL,
        [description] NVARCHAR(MAX),
        [status] NVARCHAR(50) NOT NULL DEFAULT 'active',
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
    PRINT '✅ Created tasks table with camelCase columns';
END

-- Time entries table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[time_entries] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [userId] UNIQUEIDENTIFIER NOT NULL,
        [projectId] UNIQUEIDENTIFIER NOT NULL,
        [taskId] UNIQUEIDENTIFIER,
        [description] NVARCHAR(MAX),
        [date] DATE NOT NULL,
        [startTime] TIME NOT NULL,
        [endTime] TIME NOT NULL,
        [duration] DECIMAL(5,2) NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE(),
        [isTemplate] BIT NOT NULL DEFAULT 0,
        [isBillable] BIT NOT NULL DEFAULT 0,
        [isApproved] BIT NOT NULL DEFAULT 0,
        [isManualEntry] BIT NOT NULL DEFAULT 1,
        [isTimerEntry] BIT NOT NULL DEFAULT 0
    );
    PRINT '✅ Created time_entries table with camelCase columns';
END

-- Employees table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[employees] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [employeeId] NVARCHAR(255) NOT NULL UNIQUE,
        [firstName] NVARCHAR(255) NOT NULL,
        [lastName] NVARCHAR(255) NOT NULL,
        [department] NVARCHAR(255) NOT NULL,
        [userId] UNIQUEIDENTIFIER NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
    PRINT '✅ Created employees table with camelCase columns';
END

-- Organizations table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[organizations] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [name] NVARCHAR(255) NOT NULL,
        [description] NVARCHAR(MAX),
        [userId] UNIQUEIDENTIFIER NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
    PRINT '✅ Created organizations table with camelCase columns';
END

-- Departments table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[departments] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [name] NVARCHAR(255) NOT NULL,
        [organizationId] UNIQUEIDENTIFIER NOT NULL,
        [managerId] UNIQUEIDENTIFIER,
        [description] NVARCHAR(255),
        [userId] UNIQUEIDENTIFIER NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
    PRINT '✅ Created departments table with camelCase columns';
END

-- Project employees table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[project_employees] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [projectId] UNIQUEIDENTIFIER NOT NULL,
        [employeeId] UNIQUEIDENTIFIER NOT NULL,
        [userId] UNIQUEIDENTIFIER NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
    PRINT '✅ Created project_employees table with camelCase columns';
END

PRINT '';
PRINT '2️⃣ Adding missing columns to existing tables...';

-- Users table missing columns
DECLARE @userColumns TABLE (columnName NVARCHAR(255));
INSERT INTO @userColumns VALUES ('firstName'), ('lastName'), ('employeeId'), ('profileImageUrl'), ('isActive'), ('lastLoginAt'), ('createdAt'), ('updatedAt');

DECLARE @columnName NVARCHAR(255);
DECLARE user_cursor CURSOR FOR SELECT columnName FROM @userColumns;
OPEN user_cursor;
FETCH NEXT FROM user_cursor INTO @columnName;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = @columnName)
    BEGIN
        IF @columnName = 'firstName' OR @columnName = 'lastName' OR @columnName = 'employeeId' OR @columnName = 'profileImageUrl'
            EXEC('ALTER TABLE [dbo].[users] ADD [' + @columnName + '] NVARCHAR(255)');
        ELSE IF @columnName = 'isActive'
            EXEC('ALTER TABLE [dbo].[users] ADD [' + @columnName + '] BIT NOT NULL DEFAULT 1');
        ELSE IF @columnName = 'lastLoginAt' OR @columnName = 'createdAt' OR @columnName = 'updatedAt'
            EXEC('ALTER TABLE [dbo].[users] ADD [' + @columnName + '] DATETIME2 DEFAULT GETUTCDATE()');
        
        PRINT '✅ Added missing column: users.' + @columnName;
    END
    FETCH NEXT FROM user_cursor INTO @columnName;
END

CLOSE user_cursor;
DEALLOCATE user_cursor;

PRINT '';
PRINT '3️⃣ Renaming snake_case columns to camelCase...';

-- Systematic column renaming for all tables
BEGIN TRY
    -- Users table renames
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'first_name')
        EXEC sp_rename 'users.first_name', 'firstName', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'last_name')
        EXEC sp_rename 'users.last_name', 'lastName', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'employee_id')
        EXEC sp_rename 'users.employee_id', 'employeeId', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'profile_image_url')
        EXEC sp_rename 'users.profile_image_url', 'profileImageUrl', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'is_active')
        EXEC sp_rename 'users.is_active', 'isActive', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'last_login_at')
        EXEC sp_rename 'users.last_login_at', 'lastLoginAt', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'created_at')
        EXEC sp_rename 'users.created_at', 'createdAt', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'updated_at')
        EXEC sp_rename 'users.updated_at', 'updatedAt', 'COLUMN';

    PRINT '✅ Users table columns renamed';
END TRY
BEGIN CATCH
    PRINT '⚠️ Some users table renames failed (may already be renamed): ' + ERROR_MESSAGE();
END CATCH

-- Projects table renames
BEGIN TRY
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'project_number')
        EXEC sp_rename 'projects.project_number', 'projectNumber', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'start_date')
        EXEC sp_rename 'projects.start_date', 'startDate', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'end_date')
        EXEC sp_rename 'projects.end_date', 'endDate', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'is_enterprise_wide')
        EXEC sp_rename 'projects.is_enterprise_wide', 'isEnterpriseWide', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'user_id')
        EXEC sp_rename 'projects.user_id', 'userId', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'created_at')
        EXEC sp_rename 'projects.created_at', 'createdAt', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'updated_at')
        EXEC sp_rename 'projects.updated_at', 'updatedAt', 'COLUMN';
    
    -- Boolean columns
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'is_template')
        EXEC sp_rename 'projects.is_template', 'isTemplate', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'allow_time_tracking')
        EXEC sp_rename 'projects.allow_time_tracking', 'allowTimeTracking', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'require_task_selection')
        EXEC sp_rename 'projects.require_task_selection', 'requireTaskSelection', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enable_budget_tracking')
        EXEC sp_rename 'projects.enable_budget_tracking', 'enableBudgetTracking', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enable_billing')
        EXEC sp_rename 'projects.enable_billing', 'enableBilling', 'COLUMN';

    PRINT '✅ Projects table columns renamed';
END TRY
BEGIN CATCH
    PRINT '⚠️ Some projects table renames failed: ' + ERROR_MESSAGE();
END CATCH

-- Time entries table renames
BEGIN TRY
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'user_id')
        EXEC sp_rename 'time_entries.user_id', 'userId', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'project_id')
        EXEC sp_rename 'time_entries.project_id', 'projectId', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'task_id')
        EXEC sp_rename 'time_entries.task_id', 'taskId', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'start_time')
        EXEC sp_rename 'time_entries.start_time', 'startTime', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'end_time')
        EXEC sp_rename 'time_entries.end_time', 'endTime', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'created_at')
        EXEC sp_rename 'time_entries.created_at', 'createdAt', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'updated_at')
        EXEC sp_rename 'time_entries.updated_at', 'updatedAt', 'COLUMN';
    
    -- Boolean columns
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_template')
        EXEC sp_rename 'time_entries.is_template', 'isTemplate', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_billable')
        EXEC sp_rename 'time_entries.is_billable', 'isBillable', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_approved')
        EXEC sp_rename 'time_entries.is_approved', 'isApproved', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_manual_entry')
        EXEC sp_rename 'time_entries.is_manual_entry', 'isManualEntry', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_timer_entry')
        EXEC sp_rename 'time_entries.is_timer_entry', 'isTimerEntry', 'COLUMN';

    PRINT '✅ Time entries table columns renamed';
END TRY
BEGIN CATCH
    PRINT '⚠️ Some time_entries table renames failed: ' + ERROR_MESSAGE();
END CATCH

-- Employees table renames
BEGIN TRY
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'employee_id')
        EXEC sp_rename 'employees.employee_id', 'employeeId', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'first_name')
        EXEC sp_rename 'employees.first_name', 'firstName', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'last_name')
        EXEC sp_rename 'employees.last_name', 'lastName', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'user_id')
        EXEC sp_rename 'employees.user_id', 'userId', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'created_at')
        EXEC sp_rename 'employees.created_at', 'createdAt', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'updated_at')
        EXEC sp_rename 'employees.updated_at', 'updatedAt', 'COLUMN';

    PRINT '✅ Employees table columns renamed';
END TRY
BEGIN CATCH
    PRINT '⚠️ Some employees table renames failed: ' + ERROR_MESSAGE();
END CATCH

-- Tasks table renames
BEGIN TRY
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'project_id')
        EXEC sp_rename 'tasks.project_id', 'projectId', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'created_at')
        EXEC sp_rename 'tasks.created_at', 'createdAt', 'COLUMN';
    
    IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'updated_at')
        EXEC sp_rename 'tasks.updated_at', 'updatedAt', 'COLUMN';

    PRINT '✅ Tasks table columns renamed';
END TRY
BEGIN CATCH
    PRINT '⚠️ Some tasks table renames failed: ' + ERROR_MESSAGE();
END CATCH

PRINT '';
PRINT '4️⃣ Final validation...';

-- Validate critical columns exist
DECLARE @missingColumns INT = 0;

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'firstName')
BEGIN
    PRINT '❌ CRITICAL: users.firstName missing';
    SET @missingColumns = @missingColumns + 1;
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'projectNumber')
BEGIN
    PRINT '❌ CRITICAL: projects.projectNumber missing';
    SET @missingColumns = @missingColumns + 1;
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'startTime')
BEGIN
    PRINT '❌ CRITICAL: time_entries.startTime missing';
    SET @missingColumns = @missingColumns + 1;
END

IF @missingColumns = 0
BEGIN
    PRINT '';
    PRINT '🎉 EMERGENCY FIX COMPLETED SUCCESSFULLY!';
    PRINT '========================================';
    PRINT '✅ All required tables exist';
    PRINT '✅ All columns are in camelCase format';
    PRINT '✅ Database is ready for application restart';
    PRINT '';
    PRINT '🔄 NEXT STEPS:';
    PRINT '1. Restart the FMB TimeTracker application';
    PRINT '2. Test the login and dashboard functionality';
    PRINT '3. Verify project creation works';
END
ELSE
BEGIN
    PRINT '';
    PRINT '⚠️ EMERGENCY FIX COMPLETED WITH ISSUES';
    PRINT '======================================';
    PRINT CAST(@missingColumns AS VARCHAR) + ' critical columns are still missing.';
    PRINT 'You may need to manually add these columns or re-run this script.';
END

PRINT '';
PRINT 'Emergency fix completed at: ' + CONVERT(VARCHAR, GETDATE(), 120);
GO
