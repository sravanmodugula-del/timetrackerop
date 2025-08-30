

-- FMB TimeTracker Database Setup for MS SQL Server
-- Run this script on HUB-SQL1TST-LIS

USE [timetracker];
GO

-- Enable snapshot isolation for better concurrency
ALTER DATABASE [timetracker] SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE [timetracker] SET READ_COMMITTED_SNAPSHOT ON;
GO

-- Sessions table (required for session management - keep NVARCHAR for compatibility)
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

-- Add missing columns if they don't exist (for existing installations)
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'profileImageUrl')
BEGIN
    ALTER TABLE [dbo].[users] ADD [profileImageUrl] NVARCHAR(255);
    PRINT '✅ Added profileImageUrl column to users table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'firstName')
BEGIN
    ALTER TABLE [dbo].[users] ADD [firstName] NVARCHAR(255);
    PRINT '✅ Added firstName column to users table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'lastName')
BEGIN
    ALTER TABLE [dbo].[users] ADD [lastName] NVARCHAR(255);
    PRINT '✅ Added lastName column to users table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'employeeId')
BEGIN
    ALTER TABLE [dbo].[users] ADD [employeeId] NVARCHAR(255);
    PRINT '✅ Added employeeId column to users table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'isActive')
BEGIN
    ALTER TABLE [dbo].[users] ADD [isActive] BIT NOT NULL DEFAULT 1;
    PRINT '✅ Added isActive column to users table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'lastLoginAt')
BEGIN
    ALTER TABLE [dbo].[users] ADD [lastLoginAt] DATETIME2;
    PRINT '✅ Added lastLoginAt column to users table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'createdAt')
BEGIN
    ALTER TABLE [dbo].[users] ADD [createdAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added createdAt column to users table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[users] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT '✅ Added updatedAt column to users table';
END
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

-- Project employees table (simplified)
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[project_employees] (
        [id] UNIQUEIDENTIFIER NOT NULL PRIMARY KEY DEFAULT NEWID(),
        [projectId] UNIQUEIDENTIFIER NOT NULL,
        [userId] UNIQUEIDENTIFIER NOT NULL,
        [createdAt] DATETIME2 DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 DEFAULT GETUTCDATE()
    );
    PRINT '✅ Created project_employees table';
END
ELSE
    PRINT '✅ Project employees table already exists';
GO

-- Add foreign key constraints (with error handling)
BEGIN TRY
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_organizations_userId')
        ALTER TABLE [dbo].[organizations] ADD CONSTRAINT FK_organizations_userId FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_departments_organizationId')
        ALTER TABLE [dbo].[departments] ADD CONSTRAINT FK_departments_organizationId FOREIGN KEY ([organizationId]) REFERENCES [dbo].[organizations]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_departments_userId')
        ALTER TABLE [dbo].[departments] ADD CONSTRAINT FK_departments_userId FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE;
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_departments_managerId')
        ALTER TABLE [dbo].[departments] ADD CONSTRAINT FK_departments_managerId FOREIGN KEY ([managerId]) REFERENCES [dbo].[users]([id]) ON DELETE SET NULL;
    
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
    
    IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_userId')
        ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_userId FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE;
    
    PRINT '✅ Foreign key constraints added successfully';
END TRY
BEGIN CATCH
    PRINT '⚠️ Some foreign keys may already exist or failed to create: ' + ERROR_MESSAGE();
END CATCH
GO

-- Create performance indexes
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

-- Create update triggers for updatedAt columns
IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_users_updatedAt')
BEGIN
    EXEC('
    CREATE TRIGGER [dbo].[trg_users_updatedAt]
    ON [dbo].[users]
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        UPDATE [dbo].[users]
        SET [updatedAt] = GETUTCDATE()
        FROM [dbo].[users] u
        INNER JOIN inserted i ON u.id = i.id;
    END
    ');
    PRINT '✅ Created users update trigger';
END
GO

IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_organizations_updatedAt')
BEGIN
    EXEC('
    CREATE TRIGGER [dbo].[trg_organizations_updatedAt]
    ON [dbo].[organizations]
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        UPDATE [dbo].[organizations]
        SET [updatedAt] = GETUTCDATE()
        FROM [dbo].[organizations] o
        INNER JOIN inserted i ON o.id = i.id;
    END
    ');
    PRINT '✅ Created organizations update trigger';
END
GO

IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_departments_updatedAt')
BEGIN
    EXEC('
    CREATE TRIGGER [dbo].[trg_departments_updatedAt]
    ON [dbo].[departments]
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        UPDATE [dbo].[departments]
        SET [updatedAt] = GETUTCDATE()
        FROM [dbo].[departments] d
        INNER JOIN inserted i ON d.id = i.id;
    END
    ');
    PRINT '✅ Created departments update trigger';
END
GO

IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_projects_updatedAt')
BEGIN
    EXEC('
    CREATE TRIGGER [dbo].[trg_projects_updatedAt]
    ON [dbo].[projects]
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        UPDATE [dbo].[projects]
        SET [updatedAt] = GETUTCDATE()
        FROM [dbo].[projects] p
        INNER JOIN inserted i ON p.id = i.id;
    END
    ');
    PRINT '✅ Created projects update trigger';
END
GO

IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_tasks_updatedAt')
BEGIN
    EXEC('
    CREATE TRIGGER [dbo].[trg_tasks_updatedAt]
    ON [dbo].[tasks]
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        UPDATE [dbo].[tasks]
        SET [updatedAt] = GETUTCDATE()
        FROM [dbo].[tasks] t
        INNER JOIN inserted i ON t.id = i.id;
    END
    ');
    PRINT '✅ Created tasks update trigger';
END
GO

IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_time_entries_updatedAt')
BEGIN
    EXEC('
    CREATE TRIGGER [dbo].[trg_time_entries_updatedAt]
    ON [dbo].[time_entries]
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        UPDATE [dbo].[time_entries]
        SET [updatedAt] = GETUTCDATE()
        FROM [dbo].[time_entries] te
        INNER JOIN inserted i ON te.id = i.id;
    END
    ');
    PRINT '✅ Created time_entries update trigger';
END
GO

IF NOT EXISTS (SELECT * FROM sys.triggers WHERE name = 'trg_project_employees_updatedAt')
BEGIN
    EXEC('
    CREATE TRIGGER [dbo].[trg_project_employees_updatedAt]
    ON [dbo].[project_employees]
    AFTER UPDATE
    AS
    BEGIN
        SET NOCOUNT ON;
        UPDATE [dbo].[project_employees]
        SET [updatedAt] = GETUTCDATE()
        FROM [dbo].[project_employees] pe
        INNER JOIN inserted i ON pe.id = i.id;
    END
    ');
    PRINT '✅ Created project_employees update trigger';
END
GO

-- Final validation
PRINT '';
PRINT '🔍 Validating database schema...';

DECLARE @tableCount INT = 0;
SELECT @tableCount = COUNT(*) FROM sys.tables WHERE name IN ('sessions', 'users', 'organizations', 'departments', 'projects', 'tasks', 'time_entries', 'project_employees');

IF @tableCount = 8
    PRINT '✅ All 8 required tables created successfully';
ELSE
    PRINT '⚠️ Expected 8 tables, found ' + CAST(@tableCount AS VARCHAR);

PRINT '';
PRINT '🎉 FMB TimeTracker database schema created successfully!';
PRINT 'Database: ' + DB_NAME();
PRINT 'Server: ' + @@SERVERNAME;
PRINT 'Completion time: ' + CONVERT(VARCHAR, GETDATE(), 120);

