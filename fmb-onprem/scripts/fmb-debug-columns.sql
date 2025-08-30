
-- FMB TimeTracker Column Debug Script
-- Use this to see exactly what columns exist in each table

USE [timetracker];
GO

PRINT '=== Column Debug Information ===';
PRINT '';

-- List all columns in each table
PRINT 'USERS table columns:';
SELECT 
    c.name AS column_name,
    t.name AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.columns c
INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID(N'[dbo].[users]')
ORDER BY c.column_id;

PRINT '';
PRINT 'PROJECT_EMPLOYEES table columns:';
SELECT 
    c.name AS column_name,
    t.name AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.columns c
INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID(N'[dbo].[project_employees]')
ORDER BY c.column_id;

PRINT '';
PRINT 'TIME_ENTRIES table columns:';
SELECT 
    c.name AS column_name,
    t.name AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.columns c
INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID(N'[dbo].[time_entries]')
ORDER BY c.column_id;

PRINT '';
PRINT 'EMPLOYEES table columns:';
SELECT 
    c.name AS column_name,
    t.name AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.columns c
INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID(N'[dbo].[employees]')
ORDER BY c.column_id;

PRINT '';
PRINT 'PROJECTS table columns:';
SELECT 
    c.name AS column_name,
    t.name AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.columns c
INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID(N'[dbo].[projects]')
ORDER BY c.column_id;

PRINT '';
PRINT 'Debug completed.';
