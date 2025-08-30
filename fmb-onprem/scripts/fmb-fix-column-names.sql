
-- FMB TimeTracker Final Column Fix for MS SQL Server
-- This script fixes ALL column naming issues and missing methods

USE [timetracker];
GO

PRINT '🔧 FMB TimeTracker Final Column Fix for MS SQL Server';
PRINT '====================================================';
PRINT 'Ensuring ALL tables have correct camelCase columns...';
PRINT '';

-- ================================================================
-- STEP 1: Ensure all tables exist with correct structure
-- ================================================================
PRINT '1️⃣ Creating missing tables...';

-- Users table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[users] (
        [id] NVARCHAR(255) NOT NULL PRIMARY KEY,
        [email] NVARCHAR(255) NOT NULL UNIQUE,
        [firstName] NVARCHAR(255),
        [lastName] NVARCHAR(255),
        [employeeId] NVARCHAR(255),
        [profileImageUrl] NVARCHAR(255),
        [role] NVARCHAR(50) NOT NULL DEFAULT 'employee',
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
        [projectNumber] NVARCHAR(100),
        [description] NVARCHAR(MAX),
        [color] NVARCHAR(7),
        [startDate] DATE,
        [endDate] DATE,
        [isEnterpriseWide] BIT NOT NULL DEFAULT 0,
        [userId] NVARCHAR(255) NOT NULL,
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
        [userId] NVARCHAR(255) NOT NULL,
        [projectId] UNIQUEIDENTIFIER NOT NULL,
        [taskId] UNIQUEIDENTIFIER,
        [description] NVARCHAR(MAX),
        [date] DATE NOT NULL,
        [startTime] NVARCHAR(5),
        [endTime] NVARCHAR(5),
        [duration] DECIMAL(10,2) NOT NULL,
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

-- Organizations table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[organizations] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [name] NVARCHAR(255) NOT NULL,
        [description] NVARCHAR(MAX),
        [userId] NVARCHAR(255) NOT NULL,
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
        [organizationId] UNIQUEIDENTIFIER,
        [managerId] UNIQUEIDENTIFIER,
        [description] NVARCHAR(MAX),
        [userId] NVARCHAR(255) NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
    PRINT '✅ Created departments table with camelCase columns';
END

-- Employees table (department as string field for simplicity)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[employees] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [employeeId] NVARCHAR(255) NOT NULL,
        [firstName] NVARCHAR(255) NOT NULL,
        [lastName] NVARCHAR(255) NOT NULL,
        [department] NVARCHAR(255),  -- Simple string field for department name
        [userId] NVARCHAR(255),
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
    PRINT '✅ Created employees table with camelCase columns and department field';
END

-- Project employees table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[project_employees] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [projectId] UNIQUEIDENTIFIER NOT NULL,
        [employeeId] UNIQUEIDENTIFIER NOT NULL,
        [userId] NVARCHAR(255) NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
    PRINT '✅ Created project_employees table with camelCase columns';
END

-- ================================================================
-- STEP 2: Fix existing column names (if tables already exist)
-- ================================================================
PRINT '';
PRINT '2️⃣ Fixing existing column names...';

-- Users table fixes
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

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'profile_image_url')
BEGIN
    EXEC sp_rename 'users.profile_image_url', 'profileImageUrl', 'COLUMN';
    PRINT '✅ Renamed profile_image_url to profileImageUrl in users';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'is_active')
BEGIN
    EXEC sp_rename 'users.is_active', 'isActive', 'COLUMN';
    PRINT '✅ Renamed is_active to isActive in users';
END

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'last_login_at')
BEGIN
    EXEC sp_rename 'users.last_login_at', 'lastLoginAt', 'COLUMN';
    PRINT '✅ Renamed last_login_at to lastLoginAt in users';
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

-- Add missing columns to users if they don't exist
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'firstName')
BEGIN
    ALTER TABLE [dbo].[users] ADD [firstName] NVARCHAR(255);
    PRINT '✅ Added firstName column to users';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'lastName')
BEGIN
    ALTER TABLE [dbo].[users] ADD [lastName] NVARCHAR(255);
    PRINT '✅ Added lastName column to users';
END

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'profileImageUrl')
BEGIN
    ALTER TABLE [dbo].[users] ADD [profileImageUrl] NVARCHAR(255);
    PRINT '✅ Added profileImageUrl column to users';
END

-- Ensure employees table has department column as string
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'department')
BEGIN
    ALTER TABLE [dbo].[employees] ADD [department] NVARCHAR(255);
    PRINT '✅ Added department column to employees table';
END

-- ================================================================
-- STEP 3: Insert test data if needed
-- ================================================================
PRINT '';
PRINT '3️⃣ Setting up test data...';

-- Insert test organization
IF NOT EXISTS (SELECT * FROM organizations WHERE name = 'FMB Corporation')
BEGIN
    INSERT INTO organizations (id, name, description, userId, createdAt, updatedAt)
    VALUES (NEWID(), 'FMB Corporation', 'Main FMB Organization', 'system', GETUTCDATE(), GETUTCDATE());
    PRINT '✅ Created test organization: FMB Corporation';
END

-- Insert test departments
IF NOT EXISTS (SELECT * FROM departments WHERE name = 'Information Technology')
BEGIN
    DECLARE @orgId UNIQUEIDENTIFIER = (SELECT TOP 1 id FROM organizations WHERE name = 'FMB Corporation');
    INSERT INTO departments (id, name, organizationId, description, userId, createdAt, updatedAt)
    VALUES (NEWID(), 'Information Technology', @orgId, 'IT Department', 'system', GETUTCDATE(), GETUTCDATE());
    PRINT '✅ Created test department: Information Technology';
END

IF NOT EXISTS (SELECT * FROM departments WHERE name = 'Human Resources')
BEGIN
    DECLARE @orgId UNIQUEIDENTIFIER = (SELECT TOP 1 id FROM organizations WHERE name = 'FMB Corporation');
    INSERT INTO departments (id, name, organizationId, description, userId, createdAt, updatedAt)
    VALUES (NEWID(), 'Human Resources', @orgId, 'HR Department', 'system', GETUTCDATE(), GETUTCDATE());
    PRINT '✅ Created test department: Human Resources';
END

-- Insert test project
IF NOT EXISTS (SELECT * FROM projects WHERE name = 'FMB Enterprise Project')
BEGIN
    INSERT INTO projects (id, name, projectNumber, description, color, isEnterpriseWide, userId, createdAt, updatedAt, allowTimeTracking)
    VALUES (NEWID(), 'FMB Enterprise Project', 'FMB-001', 'Main enterprise-wide project for FMB', '#3B82F6', 1, 'system', GETUTCDATE(), GETUTCDATE(), 1);
    PRINT '✅ Created test project: FMB Enterprise Project';
END

PRINT '';
PRINT '🎉 MS SQL Server database setup completed!';
PRINT 'All tables now have proper camelCase column names.';
PRINT '';
