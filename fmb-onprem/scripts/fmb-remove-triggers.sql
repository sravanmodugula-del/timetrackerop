
-- FMB TimeTracker Remove Triggers Script
-- This removes triggers that conflict with Drizzle ORM OUTPUT clauses

USE [timetracker];
GO

PRINT 'Removing conflicting triggers...';

-- Remove all update triggers that conflict with OUTPUT clauses
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

PRINT '';
PRINT '🎉 All conflicting triggers removed successfully!';
PRINT 'The application will handle updatedAt timestamps programmatically.';
