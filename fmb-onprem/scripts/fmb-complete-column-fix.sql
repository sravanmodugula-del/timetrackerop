-- FMB TimeTracker Complete Column Name Fix
-- This script ensures ALL columns are properly named in camelCase
-- Run this on the MS SQL Server to fix column naming issues

USE [timetracker];
GO

PRINT '🔧 FMB TimeTracker Complete Column Name Migration';
PRINT '===================================================';
PRINT 'Fixing ALL snake_case columns to camelCase...';
PRINT '';

-- ================================================================
-- USERS TABLE
-- ================================================================
PRINT 'Fixing users table columns...';

-- Add missing columns first
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'firstName')
BEGIN
    ALTER TABLE [dbo].[users] ADD [firstName] NVARCHAR(255);
    PRINT '✅ Added firstName column to users table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'lastName')
BEGIN
    ALTER TABLE [dbo].[users] ADD [lastName] NVARCHAR(255);
    PRINT '✅ Added lastName column to users table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'employeeId')
BEGIN
    ALTER TABLE [dbo].[users] ADD [employeeId] NVARCHAR(255);
    PRINT '✅ Added employeeId column to users table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'profileImageUrl')
BEGIN
    ALTER TABLE [dbo].[users] ADD [profileImageUrl] NVARCHAR(255);
    PRINT '✅ Added profileImageUrl column to users table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'isActive')
BEGIN
    ALTER TABLE [dbo].[users] ADD [isActive] BIT NOT NULL DEFAULT 1;
    PRINT '✅ Added isActive column to users table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'lastLoginAt')
BEGIN
    ALTER TABLE [dbo].[users] ADD [lastLoginAt] DATETIME2;
    PRINT '✅ Added lastLoginAt column to users table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'createdAt')
BEGIN
    ALTER TABLE [dbo].[users] ADD [createdAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added createdAt column to users table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[users] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added updatedAt column to users table';
END

-- Rename existing snake_case columns in users
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'first_name')
BEGIN
    EXEC sp_rename 'users.first_name', 'firstName', 'COLUMN';
    PRINT '✅ Renamed first_name to firstName in users';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'last_name')
BEGIN
    EXEC sp_rename 'users.last_name', 'lastName', 'COLUMN';
    PRINT '✅ Renamed last_name to lastName in users';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'employee_id')
BEGIN
    EXEC sp_rename 'users.employee_id', 'employeeId', 'COLUMN';
    PRINT '✅ Renamed employee_id to employeeId';
END

-- Continue with all other users columns...
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'profile_image_url')
BEGIN
    EXEC sp_rename 'users.profile_image_url', 'profileImageUrl', 'COLUMN';
    PRINT '✅ Renamed profile_image_url to profileImageUrl';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'is_active')
BEGIN
    EXEC sp_rename 'users.is_active', 'isActive', 'COLUMN';
    PRINT '✅ Renamed is_active to isActive';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'last_login_at')
BEGIN
    EXEC sp_rename 'users.last_login_at', 'lastLoginAt', 'COLUMN';
    PRINT '✅ Renamed last_login_at to lastLoginAt';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'created_at')
BEGIN
    EXEC sp_rename 'users.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in users';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'updated_at')
BEGIN
    EXEC sp_rename 'users.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in users';
END

-- ================================================================
-- PROJECTS TABLE
-- ================================================================
PRINT 'Fixing projects table columns...';

-- Add missing columns to projects
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'projectNumber')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [projectNumber] NVARCHAR(50);
    PRINT '✅ Added projectNumber column to projects table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'startDate')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [startDate] DATETIME2;
    PRINT '✅ Added startDate column to projects table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'endDate')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [endDate] DATETIME2;
    PRINT '✅ Added endDate column to projects table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'isEnterpriseWide')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [isEnterpriseWide] BIT NOT NULL DEFAULT 1;
    PRINT '✅ Added isEnterpriseWide column to projects table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'userId')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [userId] UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID();
    PRINT '✅ Added userId column to projects table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'createdAt')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [createdAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added createdAt column to projects table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added updatedAt column to projects table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'isTemplate')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [isTemplate] BIT NOT NULL DEFAULT 0;
    PRINT '✅ Added isTemplate column to projects table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'allowTimeTracking')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [allowTimeTracking] BIT NOT NULL DEFAULT 1;
    PRINT '✅ Added allowTimeTracking column to projects table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'requireTaskSelection')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [requireTaskSelection] BIT NOT NULL DEFAULT 0;
    PRINT '✅ Added requireTaskSelection column to projects table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enableBudgetTracking')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [enableBudgetTracking] BIT NOT NULL DEFAULT 0;
    PRINT '✅ Added enableBudgetTracking column to projects table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enableBilling')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [enableBilling] BIT NOT NULL DEFAULT 0;
    PRINT '✅ Added enableBilling column to projects table';
END

-- Rename snake_case columns in projects
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'project_number')
BEGIN
    EXEC sp_rename 'projects.project_number', 'projectNumber', 'COLUMN';
    PRINT '✅ Renamed project_number to projectNumber';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'start_date')
BEGIN
    EXEC sp_rename 'projects.start_date', 'startDate', 'COLUMN';
    PRINT '✅ Renamed start_date to startDate';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'end_date')
BEGIN
    EXEC sp_rename 'projects.end_date', 'endDate', 'COLUMN';
    PRINT '✅ Renamed end_date to endDate';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'is_enterprise_wide')
BEGIN
    EXEC sp_rename 'projects.is_enterprise_wide', 'isEnterpriseWide', 'COLUMN';
    PRINT '✅ Renamed is_enterprise_wide to isEnterpriseWide';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'user_id')
BEGIN
    EXEC sp_rename 'projects.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in projects';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'created_at')
BEGIN
    EXEC sp_rename 'projects.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in projects';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'updated_at')
BEGIN
    EXEC sp_rename 'projects.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in projects';
END

-- Continue with all project boolean columns
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'is_template')
BEGIN
    EXEC sp_rename 'projects.is_template', 'isTemplate', 'COLUMN';
    PRINT '✅ Renamed is_template to isTemplate';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'allow_time_tracking')
BEGIN
    EXEC sp_rename 'projects.allow_time_tracking', 'allowTimeTracking', 'COLUMN';
    PRINT '✅ Renamed allow_time_tracking to allowTimeTracking';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'require_task_selection')
BEGIN
    EXEC sp_rename 'projects.require_task_selection', 'requireTaskSelection', 'COLUMN';
    PRINT '✅ Renamed require_task_selection to requireTaskSelection';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enable_budget_tracking')
BEGIN
    EXEC sp_rename 'projects.enable_budget_tracking', 'enableBudgetTracking', 'COLUMN';
    PRINT '✅ Renamed enable_budget_tracking to enableBudgetTracking';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enable_billing')
BEGIN
    EXEC sp_rename 'projects.enable_billing', 'enableBilling', 'COLUMN';
    PRINT '✅ Renamed enable_billing to enableBilling';
END

-- ================================================================
-- EMPLOYEES TABLE  
-- ================================================================
PRINT 'Fixing employees table columns...';

-- Add missing columns to employees
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'firstName')
BEGIN
    ALTER TABLE [dbo].[employees] ADD [firstName] NVARCHAR(255) NOT NULL;
    PRINT '✅ Added firstName column to employees table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'lastName')
BEGIN
    ALTER TABLE [dbo].[employees] ADD [lastName] NVARCHAR(255) NOT NULL;
    PRINT '✅ Added lastName column to employees table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'employeeId')
BEGIN
    ALTER TABLE [dbo].[employees] ADD [employeeId] NVARCHAR(255) NOT NULL;
    PRINT '✅ Added employeeId column to employees table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'userId')
BEGIN
    ALTER TABLE [dbo].[employees] ADD [userId] UNIQUEIDENTIFIER NOT NULL;
    PRINT '✅ Added userId column to employees table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'createdAt')
BEGIN
    ALTER TABLE [dbo].[employees] ADD [createdAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added createdAt column to employees table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[employees] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added updatedAt column to employees table';
END

-- Rename existing snake_case columns in employees
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'first_name')
BEGIN
    EXEC sp_rename 'employees.first_name', 'firstName', 'COLUMN';
    PRINT '✅ Renamed first_name to firstName in employees';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'last_name')
BEGIN
    EXEC sp_rename 'employees.last_name', 'lastName', 'COLUMN';
    PRINT '✅ Renamed last_name to lastName in employees';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'employee_id')
BEGIN
    EXEC sp_rename 'employees.employee_id', 'employeeId', 'COLUMN';
    PRINT '✅ Renamed employee_id to employeeId in employees';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'user_id')
BEGIN
    EXEC sp_rename 'employees.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in employees';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'created_at')
BEGIN
    EXEC sp_rename 'employees.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in employees';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'updated_at')
BEGIN
    EXEC sp_rename 'employees.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in employees';
END

-- ================================================================
-- TIME_ENTRIES TABLE
-- ================================================================
PRINT 'Fixing time_entries table columns...';

-- Add missing columns to time_entries
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'userId')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [userId] UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID();
    PRINT '✅ Added userId column to time_entries table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'projectId')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [projectId] UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID();
    PRINT '✅ Added projectId column to time_entries table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'taskId')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [taskId] UNIQUEIDENTIFIER;
    PRINT '✅ Added taskId column to time_entries table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'startTime')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [startTime] NVARCHAR(5);
    PRINT '✅ Added startTime column to time_entries table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'endTime')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [endTime] NVARCHAR(5);
    PRINT '✅ Added endTime column to time_entries table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'createdAt')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [createdAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added createdAt column to time_entries table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added updatedAt column to time_entries table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isTemplate')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [isTemplate] BIT NOT NULL DEFAULT 0;
    PRINT '✅ Added isTemplate column to time_entries table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isBillable')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [isBillable] BIT NOT NULL DEFAULT 0;
    PRINT '✅ Added isBillable column to time_entries table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isApproved')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [isApproved] BIT NOT NULL DEFAULT 0;
    PRINT '✅ Added isApproved column to time_entries table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isManualEntry')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [isManualEntry] BIT NOT NULL DEFAULT 1;
    PRINT '✅ Added isManualEntry column to time_entries table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isTimerEntry')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [isTimerEntry] BIT NOT NULL DEFAULT 0;
    PRINT '✅ Added isTimerEntry column to time_entries table';
END

-- Rename snake_case columns in time_entries
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'user_id')
BEGIN
    EXEC sp_rename 'time_entries.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in time_entries';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'project_id')
BEGIN
    EXEC sp_rename 'time_entries.project_id', 'projectId', 'COLUMN';
    PRINT '✅ Renamed project_id to projectId in time_entries';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'task_id')
BEGIN
    EXEC sp_rename 'time_entries.task_id', 'taskId', 'COLUMN';
    PRINT '✅ Renamed task_id to taskId in time_entries';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'start_time')
BEGIN
    EXEC sp_rename 'time_entries.start_time', 'startTime', 'COLUMN';
    PRINT '✅ Renamed start_time to startTime in time_entries';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'end_time')
BEGIN
    EXEC sp_rename 'time_entries.end_time', 'endTime', 'COLUMN';
    PRINT '✅ Renamed end_time to endTime in time_entries';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'created_at')
BEGIN
    EXEC sp_rename 'time_entries.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in time_entries';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'updated_at')
BEGIN
    EXEC sp_rename 'time_entries.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in time_entries';
END

-- ================================================================
-- TASKS TABLE
-- ================================================================
PRINT 'Fixing tasks table columns...';

-- Add missing columns to tasks
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'projectId')
BEGIN
    ALTER TABLE [dbo].[tasks] ADD [projectId] UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID();
    PRINT '✅ Added projectId column to tasks table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'createdAt')
BEGIN
    ALTER TABLE [dbo].[tasks] ADD [createdAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added createdAt column to tasks table';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[tasks] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added updatedAt column to tasks table';
END

-- Rename snake_case columns in tasks
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'project_id')
BEGIN
    EXEC sp_rename 'tasks.project_id', 'projectId', 'COLUMN';
    PRINT '✅ Renamed project_id to projectId in tasks';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'created_at')
BEGIN
    EXEC sp_rename 'tasks.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in tasks';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'updated_at')
BEGIN
    EXEC sp_rename 'tasks.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in tasks';
END

-- ================================================================
-- CREATE MISSING TABLES
-- ================================================================
PRINT 'Creating missing tables...';

-- Organizations table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[organizations] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [name] NVARCHAR(255) NOT NULL,
        [description] NVARCHAR(255),
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

-- Employees table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[employees] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [employeeId] NVARCHAR(255) NOT NULL,
        [firstName] NVARCHAR(255) NOT NULL,
        [lastName] NVARCHAR(255) NOT NULL,
        [department] NVARCHAR(255),
        [userId] UNIQUEIDENTIFIER,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
    PRINT '✅ Created employees table with camelCase columns';
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
PRINT '🎉 Database schema migration completed successfully!';
PRINT 'All tables now have proper camelCase column names.';
PRINT 'The application should now work correctly with MS SQL Server.';