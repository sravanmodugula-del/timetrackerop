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
        [employee_id] NVARCHAR(255) NOT NULL UNIQUE,
        [first_name] NVARCHAR(255) NOT NULL,
        [last_name] NVARCHAR(255) NOT NULL,
        [department] NVARCHAR(255) NOT NULL,
        [user_id] NVARCHAR(255) NOT NULL,
        [created_at] DATETIME2 DEFAULT GETUTCDATE(),
        [updated_at] DATETIME2 DEFAULT GETUTCDATE(),
        FOREIGN KEY ([user_id]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE
    );
END
GO

-- Project employees table
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[project_employees] (
        [id] NVARCHAR(255) NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [project_id] NVARCHAR(255) NOT NULL,
        [employee_id] NVARCHAR(255) NOT NULL,
        [user_id] NVARCHAR(255) NOT NULL,
        [created_at] DATETIME2 DEFAULT GETUTCDATE(),
        [updated_at] DATETIME2 DEFAULT GETUTCDATE()
    );
END
GO

-- Add foreign key constraints for project_employees after all tables are created
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_project_id')
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'project_id')
BEGIN
    ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_project_id 
    FOREIGN KEY ([project_id]) REFERENCES [dbo].[projects]([id]) ON DELETE CASCADE;
    PRINT 'Added FK_project_employees_project_id constraint';
END
ELSE
BEGIN
    PRINT 'FK_project_employees_project_id constraint already exists or prerequisites not met';
END
GO

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_employee_id')
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'employee_id')
BEGIN
    ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_employee_id 
    FOREIGN KEY ([employee_id]) REFERENCES [dbo].[employees]([id]) ON DELETE CASCADE;
    PRINT 'Added FK_project_employees_employee_id constraint';
END
ELSE
BEGIN
    PRINT 'FK_project_employees_employee_id constraint already exists or prerequisites not met';
END
GO

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_user_id')
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'user_id')
BEGIN
    ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_user_id 
    FOREIGN KEY ([user_id]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE;
    PRINT 'Added FK_project_employees_user_id constraint';
END
ELSE
BEGIN
    PRINT 'FK_project_employees_user_id constraint already exists or prerequisites not met';
END
GO

-- Add foreign key for departments managerId now that employees table exists
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_departments_managerId')
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'managerId')
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'id')
BEGIN
    ALTER TABLE [dbo].[departments] ADD CONSTRAINT FK_departments_managerId 
    FOREIGN KEY ([managerId]) REFERENCES [dbo].[employees]([id]);
    PRINT 'Added FK_departments_managerId constraint';
END
ELSE
BEGIN
    PRINT 'FK_departments_managerId constraint already exists or prerequisites not met';
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

-- Final validation of all columns before completing
PRINT 'Validating database schema...';

-- Check for any missing critical columns
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'id')
    PRINT 'WARNING: users.id column missing';

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'id')
    PRINT 'WARNING: employees.id column missing';

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'id')
    PRINT 'WARNING: projects.id column missing';

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'project_id')
    PRINT 'WARNING: project_employees.project_id column missing';

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'employee_id')
    PRINT 'WARNING: project_employees.employee_id column missing';

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'user_id')
    PRINT 'WARNING: project_employees.user_id column missing';

PRINT 'FMB TimeTracker database schema created successfully';
