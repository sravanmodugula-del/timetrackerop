
-- FMB TimeTracker Database Migration Script
-- Adds any missing constraints and indexes

USE [timetracker];
GO

-- Add missing foreign key constraints if they don't exist

-- Foreign key for departments managerId (only if both tables exist and have the right columns)
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_departments_managerId')
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'managerId')
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

-- Add any missing indexes
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IDX_departments_manager')
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND type in (N'U'))
BEGIN
    CREATE INDEX IDX_departments_manager ON [dbo].[departments] ([managerId]);
    PRINT 'Added IDX_departments_manager index';
END
GO

-- Add any missing columns if they don't exist
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[users] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT 'Added updatedAt column to users table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[organizations] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT 'Added updatedAt column to organizations table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[departments] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT 'Added updatedAt column to departments table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[projects] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT 'Added updatedAt column to projects table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[tasks] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT 'Added updatedAt column to tasks table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[time_entries] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT 'Added updatedAt column to time_entries table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[employees] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT 'Added updatedAt column to employees table';
END
GO

IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'updatedAt')
BEGIN
    ALTER TABLE [dbo].[project_employees] ADD [updatedAt] DATETIME2 DEFAULT GETUTCDATE();
    PRINT 'Added updatedAt column to project_employees table';
END
GO

-- Add missing foreign key constraints for project_employees
IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_projectId')
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND type in (N'U'))
BEGIN
    ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_projectId 
    FOREIGN KEY ([projectId]) REFERENCES [dbo].[projects]([id]) ON DELETE CASCADE;
    PRINT 'Added FK_project_employees_projectId constraint';
END
GO

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_employeeId')
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
BEGIN
    ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_employeeId 
    FOREIGN KEY ([employeeId]) REFERENCES [dbo].[employees]([id]) ON DELETE CASCADE;
    PRINT 'Added FK_project_employees_employeeId constraint';
END
GO

IF NOT EXISTS (SELECT * FROM sys.foreign_keys WHERE name = 'FK_project_employees_userId')
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND type in (N'U'))
AND EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND type in (N'U'))
BEGIN
    ALTER TABLE [dbo].[project_employees] ADD CONSTRAINT FK_project_employees_userId 
    FOREIGN KEY ([userId]) REFERENCES [dbo].[users]([id]) ON DELETE CASCADE;
    PRINT 'Added FK_project_employees_userId constraint';
END
GO

PRINT 'FMB TimeTracker database migration completed successfully';
