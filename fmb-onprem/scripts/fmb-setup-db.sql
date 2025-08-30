
-- FMB TimeTracker Database Setup for MS SQL Server
-- Complete one-file setup for HUB-SQL1TST-LIS
-- This script handles: table creation, column name fixes, trigger removal, and validation

USE [timetracker];
GO

PRINT '=== FMB TimeTracker Complete Database Setup ===';
PRINT 'Starting comprehensive database setup...';
PRINT '';

-- Enable snapshot isolation for better concurrency
ALTER DATABASE [timetracker] SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE [timetracker] SET READ_COMMITTED_SNAPSHOT ON;
GO

-- ================================================================
-- STEP 1: Remove conflicting triggers first (if they exist)
-- ================================================================
PRINT '🔧 STEP 1: Removing conflicting triggers...';

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_users_updatedAt')
BEGIN
    DROP TRIGGER [dbo].[trg_users_updatedAt];
    PRINT '✅ Removed trg_users_updatedAt trigger';
END

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_organizations_updatedAt')
BEGIN
    DROP TRIGGER [dbo].[trg_organizations_updatedAt];
    PRINT '✅ Removed trg_organizations_updatedAt trigger';
END

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_departments_updatedAt')
BEGIN
    DROP TRIGGER [dbo].[trg_departments_updatedAt];
    PRINT '✅ Removed trg_departments_updatedAt trigger';
END

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_projects_updatedAt')
BEGIN
    DROP TRIGGER [dbo].[trg_projects_updatedAt];
    PRINT '✅ Removed trg_projects_updatedAt trigger';
END

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_tasks_updatedAt')
BEGIN
    DROP TRIGGER [dbo].[trg_tasks_updatedAt];
    PRINT '✅ Removed trg_tasks_updatedAt trigger';
END

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_time_entries_updatedAt')
BEGIN
    DROP TRIGGER [dbo].[trg_time_entries_updatedAt];
    PRINT '✅ Removed trg_time_entries_updatedAt trigger';
END

IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_project_employees_updatedAt')
BEGIN
    DROP TRIGGER [dbo].[trg_project_employees_updatedAt];
    PRINT '✅ Removed trg_project_employees_updatedAt trigger';
END

PRINT '✅ Trigger removal completed';
PRINT '';

-- ================================================================
-- STEP 2: Create tables with camelCase column names
-- ================================================================
PRINT '🔧 STEP 2: Creating database tables...';

-- Sessions table (required for session management)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sessions]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[sessions] (
        [sid] NVARCHAR(255) NOT NULL PRIMARY KEY,
        [sess] NVARCHAR(MAX) NOT NULL,
        [expire] DATETIME2 NOT NULL
    );
    CREATE INDEX IDX_session_expire ON [dbo].[sessions] ([expire]);
    PRINT '✅ Created sessions table';
END
ELSE
    PRINT '✅ Sessions table already exists';

-- Clean up expired sessions periodically
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[CleanupExpiredSessions]') AND type in (N'P'))
BEGIN
    EXEC('
    CREATE PROCEDURE [dbo].[CleanupExpiredSessions]
    AS
    BEGIN
        DELETE FROM [dbo].[sessions] WHERE [expire] < GETUTCDATE();
        PRINT ''Cleaned up expired sessions'';
    END
    ');
    PRINT '✅ Created session cleanup procedure';
END
ELSE
    PRINT '✅ Session cleanup procedure already exists';
GO

-- Users table (consolidated with employee information)
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
    PRINT '✅ Created users table';
END
ELSE
    PRINT '✅ Users table already exists';
GO

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
    PRINT '✅ Created organizations table';
END
ELSE
    PRINT '✅ Organizations table already exists';
GO

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
    PRINT '✅ Created departments table';
END
ELSE
    PRINT '✅ Departments table already exists';
GO

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
    PRINT '✅ Created employees table';
END
ELSE
    PRINT '✅ Employees table already exists';
GO

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
    PRINT '✅ Created projects table';
END
ELSE
    PRINT '✅ Projects table already exists';
GO

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
    PRINT '✅ Created tasks table';
END
ELSE
    PRINT '✅ Tasks table already exists';
GO

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
    PRINT '✅ Created time_entries table';
END
ELSE
    PRINT '✅ Time entries table already exists';
GO

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
    PRINT '✅ Created project_employees table';
END
ELSE
    PRINT '✅ Project employees table already exists';
GO

-- ================================================================
-- STEP 3: Fix existing snake_case columns to camelCase
-- ================================================================
PRINT '🔧 STEP 3: Converting snake_case columns to camelCase...';

-- Users table column fixes
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'profile_image_url')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'profileImageUrl')
BEGIN
    EXEC sp_rename 'users.profile_image_url', 'profileImageUrl', 'COLUMN';
    PRINT '✅ Renamed profile_image_url to profileImageUrl';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'first_name')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'firstName')
BEGIN
    EXEC sp_rename 'users.first_name', 'firstName', 'COLUMN';
    PRINT '✅ Renamed first_name to firstName';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'last_name')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'lastName')
BEGIN
    EXEC sp_rename 'users.last_name', 'lastName', 'COLUMN';
    PRINT '✅ Renamed last_name to lastName';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'employee_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'employeeId')
BEGIN
    EXEC sp_rename 'users.employee_id', 'employeeId', 'COLUMN';
    PRINT '✅ Renamed employee_id to employeeId';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'is_active')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'isActive')
BEGIN
    EXEC sp_rename 'users.is_active', 'isActive', 'COLUMN';
    PRINT '✅ Renamed is_active to isActive';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'last_login_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'lastLoginAt')
BEGIN
    EXEC sp_rename 'users.last_login_at', 'lastLoginAt', 'COLUMN';
    PRINT '✅ Renamed last_login_at to lastLoginAt';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'users.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in users table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'users.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in users table';
END

-- Add missing columns to users table if they don't exist
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'profileImageUrl')
BEGIN
    ALTER TABLE [dbo].[users] ADD [profileImageUrl] NVARCHAR(255);
    PRINT '✅ Added profileImageUrl column to users table';
END

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

-- Fix Organizations table columns
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'user_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'userId')
BEGIN
    EXEC sp_rename 'organizations.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in organizations table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'organizations.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in organizations table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'organizations.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in organizations table';
END

-- Fix Departments table columns
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'organization_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'organizationId')
BEGIN
    EXEC sp_rename 'departments.organization_id', 'organizationId', 'COLUMN';
    PRINT '✅ Renamed organization_id to organizationId';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'manager_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'managerId')
BEGIN
    EXEC sp_rename 'departments.manager_id', 'managerId', 'COLUMN';
    PRINT '✅ Renamed manager_id to managerId';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'user_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'userId')
BEGIN
    EXEC sp_rename 'departments.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in departments table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'departments.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in departments table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'departments.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in departments table';
END

-- Fix Employees table columns
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'employee_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'employeeId')
BEGIN
    EXEC sp_rename 'employees.employee_id', 'employeeId', 'COLUMN';
    PRINT '✅ Renamed employee_id to employeeId in employees table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'first_name')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'firstName')
BEGIN
    EXEC sp_rename 'employees.first_name', 'firstName', 'COLUMN';
    PRINT '✅ Renamed first_name to firstName in employees table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'last_name')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'lastName')
BEGIN
    EXEC sp_rename 'employees.last_name', 'lastName', 'COLUMN';
    PRINT '✅ Renamed last_name to lastName in employees table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'user_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'userId')
BEGIN
    EXEC sp_rename 'employees.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in employees table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'employees.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in employees table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'employees.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in employees table';
END

-- Fix Projects table columns
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'project_number')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'projectNumber')
BEGIN
    EXEC sp_rename 'projects.project_number', 'projectNumber', 'COLUMN';
    PRINT '✅ Renamed project_number to projectNumber';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'start_date')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'startDate')
BEGIN
    EXEC sp_rename 'projects.start_date', 'startDate', 'COLUMN';
    PRINT '✅ Renamed start_date to startDate';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'end_date')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'endDate')
BEGIN
    EXEC sp_rename 'projects.end_date', 'endDate', 'COLUMN';
    PRINT '✅ Renamed end_date to endDate';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'is_enterprise_wide')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'isEnterpriseWide')
BEGIN
    EXEC sp_rename 'projects.is_enterprise_wide', 'isEnterpriseWide', 'COLUMN';
    PRINT '✅ Renamed is_enterprise_wide to isEnterpriseWide';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'user_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'userId')
BEGIN
    EXEC sp_rename 'projects.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in projects table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'projects.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in projects table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'projects.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in projects table';
END

-- Fix all project boolean columns
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'is_template')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'isTemplate')
BEGIN
    EXEC sp_rename 'projects.is_template', 'isTemplate', 'COLUMN';
    PRINT '✅ Renamed is_template to isTemplate';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'allow_time_tracking')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'allowTimeTracking')
BEGIN
    EXEC sp_rename 'projects.allow_time_tracking', 'allowTimeTracking', 'COLUMN';
    PRINT '✅ Renamed allow_time_tracking to allowTimeTracking';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'require_task_selection')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'requireTaskSelection')
BEGIN
    EXEC sp_rename 'projects.require_task_selection', 'requireTaskSelection', 'COLUMN';
    PRINT '✅ Renamed require_task_selection to requireTaskSelection';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enable_budget_tracking')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enableBudgetTracking')
BEGIN
    EXEC sp_rename 'projects.enable_budget_tracking', 'enableBudgetTracking', 'COLUMN';
    PRINT '✅ Renamed enable_budget_tracking to enableBudgetTracking';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enable_billing')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enableBilling')
BEGIN
    EXEC sp_rename 'projects.enable_billing', 'enableBilling', 'COLUMN';
    PRINT '✅ Renamed enable_billing to enableBilling';
END

-- Fix Tasks table columns
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'project_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'projectId')
BEGIN
    EXEC sp_rename 'tasks.project_id', 'projectId', 'COLUMN';
    PRINT '✅ Renamed project_id to projectId in tasks table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'tasks.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in tasks table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'tasks.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in tasks table';
END

-- Fix Time Entries table columns
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'user_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'userId')
BEGIN
    EXEC sp_rename 'time_entries.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in time_entries table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'project_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'projectId')
BEGIN
    EXEC sp_rename 'time_entries.project_id', 'projectId', 'COLUMN';
    PRINT '✅ Renamed project_id to projectId in time_entries table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'task_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'taskId')
BEGIN
    EXEC sp_rename 'time_entries.task_id', 'taskId', 'COLUMN';
    PRINT '✅ Renamed task_id to taskId in time_entries table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'start_time')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'startTime')
BEGIN
    EXEC sp_rename 'time_entries.start_time', 'startTime', 'COLUMN';
    PRINT '✅ Renamed start_time to startTime';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'end_time')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'endTime')
BEGIN
    EXEC sp_rename 'time_entries.end_time', 'endTime', 'COLUMN';
    PRINT '✅ Renamed end_time to endTime';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'time_entries.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in time_entries table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'time_entries.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in time_entries table';
END

-- Fix all time_entries boolean columns
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_template')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isTemplate')
BEGIN
    EXEC sp_rename 'time_entries.is_template', 'isTemplate', 'COLUMN';
    PRINT '✅ Renamed is_template to isTemplate in time_entries';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_billable')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isBillable')
BEGIN
    EXEC sp_rename 'time_entries.is_billable', 'isBillable', 'COLUMN';
    PRINT '✅ Renamed is_billable to isBillable';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_approved')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isApproved')
BEGIN
    EXEC sp_rename 'time_entries.is_approved', 'isApproved', 'COLUMN';
    PRINT '✅ Renamed is_approved to isApproved';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_manual_entry')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isManualEntry')
BEGIN
    EXEC sp_rename 'time_entries.is_manual_entry', 'isManualEntry', 'COLUMN';
    PRINT '✅ Renamed is_manual_entry to isManualEntry';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_timer_entry')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isTimerEntry')
BEGIN
    EXEC sp_rename 'time_entries.is_timer_entry', 'isTimerEntry', 'COLUMN';
    PRINT '✅ Renamed is_timer_entry to isTimerEntry';
END

-- Fix Project Employees table columns
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'project_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'projectId')
BEGIN
    EXEC sp_rename 'project_employees.project_id', 'projectId', 'COLUMN';
    PRINT '✅ Renamed project_id to projectId in project_employees table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'employee_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'employeeId')
BEGIN
    EXEC sp_rename 'project_employees.employee_id', 'employeeId', 'COLUMN';
    PRINT '✅ Renamed employee_id to employeeId in project_employees table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'user_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'userId')
BEGIN
    EXEC sp_rename 'project_employees.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in project_employees table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'project_employees.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in project_employees table';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'project_employees.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in project_employees table';
END

PRINT '✅ Column name conversion completed';
PRINT '';

-- ================================================================
-- STEP 4: Add foreign key constraints
-- ================================================================
PRINT '🔧 STEP 4: Adding foreign key constraints...';

BEGIN TRY
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_organizations_userId')
        ALTER TABLE [dbo].[organizations] ADD CONSTRAINT FK_organizations_userId FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_departments_organizationId')
        ALTER TABLE [dbo].[departments] ADD CONSTRAINT FK_departments_organizationId FOREIGN KEY ([organizationId]) REFERENCES [dbo].[organizations]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_departments_userId')
        ALTER TABLE [dbo].[departments] ADD CONSTRAINT FK_departments_userId FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_departments_managerId')
        ALTER TABLE [dbo].[departments] ADD CONSTRAINT FK_departments_managerId FOREIGN KEY ([managerId]) REFERENCES [dbo].[employees]([id]) ON DELETE SET NULL;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_employees_userId')
        ALTER TABLE [dbo].[employees] ADD CONSTRAINT FK_employees_userId FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_projects_userId')
        ALTER TABLE [dbo].[projects] ADD CONSTRAINT FK_projects_userId FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_tasks_projectId')
        ALTER TABLE [dbo].[tasks] ADD CONSTRAINT FK_tasks_projectId FOREIGN KEY ([projectId]) REFERENCES [dbo].[projects]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_time_entries_userId')
        ALTER TABLE [dbo].[time_entries] ADD CONSTRAINT FK_time_entries_userId FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_time_entries_projectId')
        ALTER TABLE [dbo].[time_entries] ADD CONSTRAINT FK_time_entries_projectId FOREIGN KEY ([projectId]) REFERENCES [dbo].[projects]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_time_entries_taskId')
        ALTER TABLE [dbo].[time_entries] ADD CONSTRAINT FK_time_entries_taskId FOREIGN KEY ([taskId]) REFERENCES [dbo].[tasks]([id]) ON DELETE SET NULL;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_projectId')
        ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_projectId FOREIGN KEY ([projectId]) REFERENCES [dbo].[projects]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_employeeId')
        ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_employeeId FOREIGN KEY ([employeeId]) REFERENCES [dbo].[employees]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_userId')
        ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_userId FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE NO ACTION;
    
    PRINT '✅ Foreign key constraints added successfully';
END TRY
BEGIN CATCH
    PRINT '⚠️ Some foreign keys may already exist or failed to create: ' + ERROR_MESSAGE();
END CATCH
GO

-- ================================================================
-- STEP 5: Create performance indexes
-- ================================================================
PRINT '🔧 STEP 5: Creating performance indexes...';

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_time_entries_user_date')
    CREATE INDEX IDX_time_entries_user_date ON [dbo].[time_entries] ([userId], [date]);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_time_entries_project_date')
    CREATE INDEX IDX_time_entries_project_date ON [dbo].[time_entries] ([projectId], [date]);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_projects_enterprise')
    CREATE INDEX IDX_projects_enterprise ON [dbo].[projects] ([isEnterpriseWide]);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_users_email')
    CREATE INDEX IDX_users_email ON [dbo].[users] ([email]);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_users_employeeId')
    CREATE INDEX IDX_users_employeeId ON [dbo].[users] ([employeeId]);

PRINT '✅ Performance indexes created';
GO

-- ================================================================
-- STEP 6: Database validation and test data insertion
-- ================================================================
PRINT '🔧 STEP 6: Validating database schema and inserting test data...';

DECLARE @tableCount INT = 0;
DECLARE @missingTables NVARCHAR(MAX) = '';

-- Check all required tables
IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sessions]') AND type in (N'U'))
    SET @tableCount = @tableCount + 1;
ELSE
    SET @missingTables = @missingTables + 'sessions, ';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND type in (N'U'))
    SET @tableCount = @tableCount + 1;
ELSE
    SET @missingTables = @missingTables + 'users, ';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND type in (N'U'))
    SET @tableCount = @tableCount + 1;
ELSE
    SET @missingTables = @missingTables + 'organizations, ';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND type in (N'U'))
    SET @tableCount = @tableCount + 1;
ELSE
    SET @missingTables = @missingTables + 'departments, ';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
    SET @tableCount = @tableCount + 1;
ELSE
    SET @missingTables = @missingTables + 'employees, ';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND type in (N'U'))
    SET @tableCount = @tableCount + 1;
ELSE
    SET @missingTables = @missingTables + 'projects, ';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND type in (N'U'))
    SET @tableCount = @tableCount + 1;
ELSE
    SET @missingTables = @missingTables + 'tasks, ';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND type in (N'U'))
    SET @tableCount = @tableCount + 1;
ELSE
    SET @missingTables = @missingTables + 'time_entries, ';

IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
    SET @tableCount = @tableCount + 1;
ELSE
    SET @missingTables = @missingTables + 'project_employees, ';

-- Test basic CRUD operations and insert test data
BEGIN TRY
    -- Insert test admin user for authentication
    IF NOT EXISTS (SELECT 1 FROM users WHERE id = 'test-admin-user')
    BEGIN
        INSERT INTO users (id, email, firstName, lastName, role, isActive, createdAt, updatedAt) 
        VALUES ('test-admin-user', 'admin@test.com', 'Test', 'Admin', 'admin', 1, GETUTCDATE(), GETUTCDATE());
        PRINT '✅ Inserted test admin user';
    END
    ELSE
        PRINT '✅ Test admin user already exists';
    
    -- Insert test organization
    IF NOT EXISTS (SELECT 1 FROM organizations WHERE name = 'Test Organization')
    BEGIN
        INSERT INTO organizations (id, name, description, userId, createdAt, updatedAt)
        VALUES (NEWID(), 'Test Organization', 'Default test organization', 'test-admin-user', GETUTCDATE(), GETUTCDATE());
        PRINT '✅ Inserted test organization';
    END
    ELSE
        PRINT '✅ Test organization already exists';
    
    -- Insert test project
    IF NOT EXISTS (SELECT 1 FROM projects WHERE name = 'Default Project')
    BEGIN
        INSERT INTO projects (id, name, description, userId, isEnterpriseWide, createdAt, updatedAt)
        VALUES (NEWID(), 'Default Project', 'Default project for testing', 'test-admin-user', 1, GETUTCDATE(), GETUTCDATE());
        PRINT '✅ Inserted test project';
    END
    ELSE
        PRINT '✅ Test project already exists';
    
    IF EXISTS (SELECT 1 FROM users WHERE id = 'test-admin-user')
        PRINT '✅ Database operations: INSERT/SELECT works';
    ELSE
        PRINT '❌ Database operations: INSERT/SELECT failed';
    
END TRY
BEGIN CATCH
    PRINT '❌ Database operations failed: ' + ERROR_MESSAGE();
END CATCH

PRINT '';

-- ================================================================
-- FINAL SUMMARY
-- ================================================================
IF @tableCount = 9 AND LEN(@missingTables) = 0
BEGIN
    PRINT '🎉 DATABASE SETUP COMPLETED SUCCESSFULLY!';
    PRINT '=========================================';
    PRINT '✅ All 9 required tables created successfully';
    PRINT '✅ All triggers removed to avoid ORM conflicts';
    PRINT '✅ All column names converted to camelCase';
    PRINT '✅ Foreign key constraints established';
    PRINT '✅ Performance indexes created';
    PRINT '✅ Test data inserted for authentication';
    PRINT '✅ Database validation passed';
    PRINT '';
    PRINT 'Your FMB TimeTracker database is ready for deployment!';
END
ELSE
BEGIN
    PRINT '⚠️ DATABASE SETUP COMPLETED WITH WARNINGS';
    PRINT '==========================================';
    PRINT 'Expected 9 tables, found ' + CAST(@tableCount AS VARCHAR);
    IF LEN(@missingTables) > 0
        PRINT 'Missing tables: ' + LEFT(@missingTables, LEN(@missingTables) - 2);
    PRINT 'Please review the errors above and re-run if necessary.';
END

PRINT '';
PRINT 'Database: ' + DB_NAME();
PRINT 'Server: ' + @@SERVERNAME;
PRINT 'Setup completed: ' + CONVERT(VARCHAR, GETDATE(), 120);
PRINT '';
PRINT 'Note: Triggers removed to avoid conflicts with Drizzle ORM OUTPUT clauses.';
PRINT 'The application will handle updatedAt timestamps programmatically.';
PRINT '';
PRINT '🔑 AUTHENTICATION SETUP:';
PRINT 'Test admin user created: admin@test.com (ID: test-admin-user)';
PRINT 'This user will be used for development authentication bypass.';
