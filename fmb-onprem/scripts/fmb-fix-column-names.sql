
-- FMB TimeTracker Column Name Fix
-- Run this script if you're getting "invalid column name" errors
-- This fixes the mismatch between snake_case and camelCase column names

USE [timetracker];
GO

PRINT '🔧 FMB TimeTracker Column Name Migration';
PRINT '==========================================';

-- Check if we need to rename columns from snake_case to camelCase
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'profile_image_url')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'profileImageUrl')
BEGIN
    EXEC sp_rename 'users.profile_image_url', 'profileImageUrl', 'COLUMN';
    PRINT '✅ Renamed profile_image_url to profileImageUrl';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'first_name')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'firstName')
BEGIN
    EXEC sp_rename 'users.first_name', 'firstName', 'COLUMN';
    PRINT '✅ Renamed first_name to firstName';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'last_name')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'lastName')
BEGIN
    EXEC sp_rename 'users.last_name', 'lastName', 'COLUMN';
    PRINT '✅ Renamed last_name to lastName';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'is_active')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'isActive')
BEGIN
    EXEC sp_rename 'users.is_active', 'isActive', 'COLUMN';
    PRINT '✅ Renamed is_active to isActive';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'last_login_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'lastLoginAt')
BEGIN
    EXEC sp_rename 'users.last_login_at', 'lastLoginAt', 'COLUMN';
    PRINT '✅ Renamed last_login_at to lastLoginAt';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'users.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'users.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt';
END
GO

-- Fix other tables if needed
-- Projects table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'project_number')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'projectNumber')
BEGIN
    EXEC sp_rename 'projects.project_number', 'projectNumber', 'COLUMN';
    PRINT '✅ Renamed project_number to projectNumber';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'start_date')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'startDate')
BEGIN
    EXEC sp_rename 'projects.start_date', 'startDate', 'COLUMN';
    PRINT '✅ Renamed start_date to startDate';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'end_date')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'endDate')
BEGIN
    EXEC sp_rename 'projects.end_date', 'endDate', 'COLUMN';
    PRINT '✅ Renamed end_date to endDate';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'is_enterprise_wide')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'isEnterpriseWide')
BEGIN
    EXEC sp_rename 'projects.is_enterprise_wide', 'isEnterpriseWide', 'COLUMN';
    PRINT '✅ Renamed is_enterprise_wide to isEnterpriseWide';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'user_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'userId')
BEGIN
    EXEC sp_rename 'projects.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in projects table';
END
GO

-- Fix project_employees table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'project_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'projectId')
BEGIN
    EXEC sp_rename 'project_employees.project_id', 'projectId', 'COLUMN';
    PRINT '✅ Renamed project_id to projectId in project_employees table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'user_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'userId')
BEGIN
    EXEC sp_rename 'project_employees.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in project_employees table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'project_employees.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in project_employees table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[project_employees]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'project_employees.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in project_employees table';
END
GO

-- Fix users table employeeId
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'employee_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND name = 'employeeId')
BEGIN
    EXEC sp_rename 'users.employee_id', 'employeeId', 'COLUMN';
    PRINT '✅ Renamed employee_id to employeeId in users table';
END
GO

-- Fix all remaining tables with systematic approach
-- Tasks table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'project_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'projectId')
BEGIN
    EXEC sp_rename 'tasks.project_id', 'projectId', 'COLUMN';
    PRINT '✅ Renamed project_id to projectId in tasks table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'tasks.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in tasks table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'tasks.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in tasks table';
END
GO

-- Time entries table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'user_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'userId')
BEGIN
    EXEC sp_rename 'time_entries.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in time_entries table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'project_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'projectId')
BEGIN
    EXEC sp_rename 'time_entries.project_id', 'projectId', 'COLUMN';
    PRINT '✅ Renamed project_id to projectId in time_entries table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'task_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'taskId')
BEGIN
    EXEC sp_rename 'time_entries.task_id', 'taskId', 'COLUMN';
    PRINT '✅ Renamed task_id to taskId in time_entries table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'start_time')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'startTime')
BEGIN
    EXEC sp_rename 'time_entries.start_time', 'startTime', 'COLUMN';
    PRINT '✅ Renamed start_time to startTime in time_entries table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'end_time')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'endTime')
BEGIN
    EXEC sp_rename 'time_entries.end_time', 'endTime', 'COLUMN';
    PRINT '✅ Renamed end_time to endTime in time_entries table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'time_entries.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in time_entries table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'time_entries.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in time_entries table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_template')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isTemplate')
BEGIN
    EXEC sp_rename 'time_entries.is_template', 'isTemplate', 'COLUMN';
    PRINT '✅ Renamed is_template to isTemplate in time_entries table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_billable')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isBillable')
BEGIN
    EXEC sp_rename 'time_entries.is_billable', 'isBillable', 'COLUMN';
    PRINT '✅ Renamed is_billable to isBillable in time_entries table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_approved')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isApproved')
BEGIN
    EXEC sp_rename 'time_entries.is_approved', 'isApproved', 'COLUMN';
    PRINT '✅ Renamed is_approved to isApproved in time_entries table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_manual_entry')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isManualEntry')
BEGIN
    EXEC sp_rename 'time_entries.is_manual_entry', 'isManualEntry', 'COLUMN';
    PRINT '✅ Renamed is_manual_entry to isManualEntry in time_entries table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'is_timer_entry')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND name = 'isTimerEntry')
BEGIN
    EXEC sp_rename 'time_entries.is_timer_entry', 'isTimerEntry', 'COLUMN';
    PRINT '✅ Renamed is_timer_entry to isTimerEntry in time_entries table';
END
GO

-- Organizations table  
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'user_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'userId')
BEGIN
    EXEC sp_rename 'organizations.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in organizations table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'organizations.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in organizations table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'organizations.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in organizations table';
END
GO

-- Departments table
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'organization_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'organizationId')
BEGIN
    EXEC sp_rename 'departments.organization_id', 'organizationId', 'COLUMN';
    PRINT '✅ Renamed organization_id to organizationId in departments table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'manager_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'managerId')
BEGIN
    EXEC sp_rename 'departments.manager_id', 'managerId', 'COLUMN';
    PRINT '✅ Renamed manager_id to managerId in departments table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'user_id')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'userId')
BEGIN
    EXEC sp_rename 'departments.user_id', 'userId', 'COLUMN';
    PRINT '✅ Renamed user_id to userId in departments table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'departments.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in departments table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'departments.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in departments table';
END
GO

-- Fix remaining project columns
IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'created_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'createdAt')
BEGIN
    EXEC sp_rename 'projects.created_at', 'createdAt', 'COLUMN';
    PRINT '✅ Renamed created_at to createdAt in projects table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'updated_at')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'updatedAt')
BEGIN
    EXEC sp_rename 'projects.updated_at', 'updatedAt', 'COLUMN';
    PRINT '✅ Renamed updated_at to updatedAt in projects table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'is_template')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'isTemplate')
BEGIN
    EXEC sp_rename 'projects.is_template', 'isTemplate', 'COLUMN';
    PRINT '✅ Renamed is_template to isTemplate in projects table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'allow_time_tracking')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'allowTimeTracking')
BEGIN
    EXEC sp_rename 'projects.allow_time_tracking', 'allowTimeTracking', 'COLUMN';
    PRINT '✅ Renamed allow_time_tracking to allowTimeTracking in projects table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'require_task_selection')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'requireTaskSelection')
BEGIN
    EXEC sp_rename 'projects.require_task_selection', 'requireTaskSelection', 'COLUMN';
    PRINT '✅ Renamed require_task_selection to requireTaskSelection in projects table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enable_budget_tracking')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enableBudgetTracking')
BEGIN
    EXEC sp_rename 'projects.enable_budget_tracking', 'enableBudgetTracking', 'COLUMN';
    PRINT '✅ Renamed enable_budget_tracking to enableBudgetTracking in projects table';
END
GO

IF EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enable_billing')
AND NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND name = 'enableBilling')
BEGIN
    EXEC sp_rename 'projects.enable_billing', 'enableBilling', 'COLUMN';
    PRINT '✅ Renamed enable_billing to enableBilling in projects table';
END
GO

PRINT '';
PRINT '🎉 Column name migration completed!';
PRINT 'All snake_case columns have been renamed to camelCase.';
PRINT 'You can now restart your application.';
