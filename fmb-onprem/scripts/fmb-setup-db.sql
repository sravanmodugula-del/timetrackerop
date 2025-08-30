-- FMB TimeTracker Database Setup for MS SQL Server
-- Run this script on HUB-SQL1TST-LIS

USE [timetracker];
GO

-- Enable snapshot isolation for better concurrency
ALTER DATABASE [timetracker] SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE [timetracker] SET READ_COMMITTED_SNAPSHOT ON;
GO

-- Sessions table (required for session management)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sessions]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[sessions] (
        [sid] NVARCHAR(255) NOT NULL PRIMARY KEY,
        [sess] NVARCHAR(MAX) NOT NULL,
        [expire] DATETIME2 NOT NULL
    );
    CREATE INDEX IDX_session_expire ON [dbo].[sessions] ([expire]);
END
GO

-- Users table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[users] (
        [id] NVARCHAR(255) NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [email] NVARCHAR(255) UNIQUE,
        [firstName] NVARCHAR(255),
        [lastName] NVARCHAR(255),
        [profileImageUrl] NVARCHAR(255),
        [role] NVARCHAR(50) DEFAULT 'employee',
        [isActive] BIT NOT NULL DEFAULT 1,
        [lastLoginAt] DATETIME2,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
END
GO

-- Add updatedAt column if it doesn't exist
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[users] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
END
GO

-- Organizations table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[organizations] (
        [id] NVARCHAR(255) NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [name] NVARCHAR(255) NOT NULL,
        [description] NTEXT,
        [userId] NVARCHAR(255) NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE(),
        FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE
    );
END
GO

-- Departments table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[departments] (
        [id] NVARCHAR(255) NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [name] NVARCHAR(255) NOT NULL,
        [organizationId] NVARCHAR(255) NOT NULL,
        [managerId] NVARCHAR(255),
        [description] NVARCHAR(255),
        [userId] NVARCHAR(255) NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE(),
        FOREIGN KEY ([organizationId]) REFERENCES [dbo].[organizations]([id]) ON DELETE CASCADE,
        FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE
    );
END
GO

-- Projects table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[projects] (
        [id] NVARCHAR(255) NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [name] NVARCHAR(255) NOT NULL,
        [projectNumber] NVARCHAR(50),
        [description] NTEXT,
        [color] NVARCHAR(7) DEFAULT '#1976D2',
        [startDate] DATETIME2,
        [endDate] DATETIME2,
        [isEnterpriseWide] BIT NOT NULL DEFAULT 1,
        [userId] NVARCHAR(255) NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE(),
        [isTemplate] BIT NOT NULL DEFAULT 0,
        [allowTimeTracking] BIT NOT NULL DEFAULT 1,
        [requireTaskSelection] BIT NOT NULL DEFAULT 0,
        [enableBudgetTracking] BIT NOT NULL DEFAULT 0,
        [enableBilling] BIT NOT NULL DEFAULT 0,
        FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE
    );
END
GO

-- Tasks table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[tasks] (
        [id] NVARCHAR(255) NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [projectId] NVARCHAR(255) NOT NULL,
        [name] NVARCHAR(255) NOT NULL,
        [description] NTEXT,
        [status] NVARCHAR(50) NOT NULL DEFAULT 'active',
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE(),
        FOREIGN KEY ([projectId]) REFERENCES [dbo].[projects]([id]) ON DELETE CASCADE
    );
END
GO

-- Time entries table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[time_entries] (
        [id] NVARCHAR(255) NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [userId] NVARCHAR(255) NOT NULL,
        [projectId] NVARCHAR(255) NOT NULL,
        [taskId] NVARCHAR(255),
        [description] NTEXT,
        [date] DATE NOT NULL,
        [startTime] NVARCHAR(5) NOT NULL,
        [endTime] NVARCHAR(5) NOT NULL,
        [duration] DECIMAL(5,2) NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE(),
        [isTemplate] BIT NOT NULL DEFAULT 0,
        [isBillable] BIT NOT NULL DEFAULT 0,
        [isApproved] BIT NOT NULL DEFAULT 0,
        [isManualEntry] BIT NOT NULL DEFAULT 1,
        [isTimerEntry] BIT NOT NULL DEFAULT 0,
        FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE,
        FOREIGN KEY ([projectId]) REFERENCES [dbo].[projects]([id]) ON DELETE CASCADE,
        FOREIGN KEY ([taskId]) REFERENCES [dbo].[tasks]([id]) ON DELETE SET NULL
    );
END
GO

-- Employees table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[employees] (
        [id] NVARCHAR(255) NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [employeeId] NVARCHAR(255) NOT NULL UNIQUE,
        [firstName] NVARCHAR(255) NOT NULL,
        [lastName] NVARCHAR(255) NOT NULL,
        [department] NVARCHAR(255) NOT NULL,
        [userId] NVARCHAR(255) NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE(),
        FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE
    );
END
GO

-- Project employees table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[project_employees] (
        [id] NVARCHAR(255) NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [projectId] NVARCHAR(255) NOT NULL,
        [employeeId] NVARCHAR(255) NOT NULL,
        [userId] NVARCHAR(255) NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
END
GO

-- Add foreign key constraints for project_employees after table creation
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_projectId')
BEGIN
    ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_projectId 
    FOREIGN KEY ([projectId]) REFERENCES [dbo].[projects]([id]) ON DELETE CASCADE;
END
GO

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_employeeId')
BEGIN
    ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_employeeId 
    FOREIGN KEY ([employeeId]) REFERENCES [dbo].[employees]([id]) ON DELETE CASCADE;
END
GO

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_userId')
BEGIN
    ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_userId 
    FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE;
END
GO

-- Add foreign key for departments managerId now that employees table exists
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_departments_managerId')
BEGIN
    IF EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
    BEGIN
        -- Only add the constraint if managerId column exists and is not null
        IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'managerId')
        BEGIN
            ALTER TABLE [dbo].[departments] ADD CONSTRAINT FK_departments_managerId 
            FOREIGN KEY ([managerId]) REFERENCES [dbo].[employees]([id]);
        END
    END
END
GO

-- Create indexes for performance
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_time_entries_user_date')
    CREATE INDEX IDX_time_entries_user_date ON [dbo].[time_entries] ([userId], [date]);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_time_entries_project_date')
    CREATE INDEX IDX_time_entries_project_date ON [dbo].[time_entries] ([projectId], [date]);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_projects_enterprise')
    CREATE INDEX IDX_projects_enterprise ON [dbo].[projects] ([isEnterpriseWide]);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_users_email')
    CREATE INDEX IDX_users_email ON [dbo].[users] ([email]);
GO

PRINT 'FMB TimeTracker database schema created successfully';
