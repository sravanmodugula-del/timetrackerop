
-- FMB TimeTracker Database Validation Script
-- Run this to validate the database schema and connectivity

USE [timetracker];
GO

PRINT '=== FMB TimeTracker Database Validation ===';
PRINT '';

-- Check if all required tables exist
PRINT 'Checking required tables...';
DECLARE @missingTables INT = 0;

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[users]') AND type in (N'U'))
BEGIN
    PRINT '❌ Missing table: users';
    SET @missingTables = @missingTables + 1;
END
ELSE
    PRINT '✅ Table exists: users';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[organizations]') AND type in (N'U'))
BEGIN
    PRINT '❌ Missing table: organizations';
    SET @missingTables = @missingTables + 1;
END
ELSE
    PRINT '✅ Table exists: organizations';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[departments]') AND type in (N'U'))
BEGIN
    PRINT '❌ Missing table: departments';
    SET @missingTables = @missingTables + 1;
END
ELSE
    PRINT '✅ Table exists: departments';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[employees]') AND type in (N'U'))
BEGIN
    PRINT '❌ Missing table: employees';
    SET @missingTables = @missingTables + 1;
END
ELSE
    PRINT '✅ Table exists: employees';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[projects]') AND type in (N'U'))
BEGIN
    PRINT '❌ Missing table: projects';
    SET @missingTables = @missingTables + 1;
END
ELSE
    PRINT '✅ Table exists: projects';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[tasks]') AND type in (N'U'))
BEGIN
    PRINT '❌ Missing table: tasks';
    SET @missingTables = @missingTables + 1;
END
ELSE
    PRINT '✅ Table exists: tasks';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[time_entries]') AND type in (N'U'))
BEGIN
    PRINT '❌ Missing table: time_entries';
    SET @missingTables = @missingTables + 1;
END
ELSE
    PRINT '✅ Table exists: time_entries';

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[sessions]') AND type in (N'U'))
BEGIN
    PRINT '❌ Missing table: sessions';
    SET @missingTables = @missingTables + 1;
END
ELSE
    PRINT '✅ Table exists: sessions';

PRINT '';

-- Check foreign key constraints
PRINT 'Checking foreign key constraints...';
SELECT 
    fk.name AS constraint_name,
    tp.name AS parent_table,
    cp.name AS parent_column,
    tr.name AS referenced_table,
    cr.name AS referenced_column
FROM sys.foreign_keys fk
INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
INNER JOIN sys.tables tp ON fkc.parent_object_id = tp.object_id
INNER JOIN sys.columns cp ON fkc.parent_object_id = cp.object_id AND fkc.parent_column_id = cp.column_id
INNER JOIN sys.tables tr ON fkc.referenced_object_id = tr.object_id
INNER JOIN sys.columns cr ON fkc.referenced_object_id = cr.object_id AND fkc.referenced_column_id = cr.column_id
ORDER BY tp.name, fk.name;

PRINT '';

-- Test basic CRUD operations
PRINT 'Testing basic database operations...';

-- Test insert/select/delete on users table
BEGIN TRY
    INSERT INTO users (id, email, firstName, lastName, role) 
    VALUES ('test-validation-user', 'validation@test.com', 'Test', 'User', 'employee');
    
    IF EXISTS (SELECT 1 FROM users WHERE id = 'test-validation-user')
        PRINT '✅ Users table: INSERT/SELECT works';
    ELSE
        PRINT '❌ Users table: INSERT/SELECT failed';
    
    DELETE FROM users WHERE id = 'test-validation-user';
    PRINT '✅ Users table: DELETE works';
END TRY
BEGIN CATCH
    PRINT '❌ Users table operations failed: ' + ERROR_MESSAGE();
END CATCH

PRINT '';

-- Summary
IF @missingTables = 0
BEGIN
    PRINT '🎉 Database validation completed successfully!';
    PRINT 'The database is ready for FMB TimeTracker deployment.';
END
ELSE
BEGIN
    PRINT '⚠️ Database validation found issues:';
    PRINT CAST(@missingTables AS VARCHAR) + ' table(s) are missing.';
    PRINT 'Please run the setup script again: fmb-setup-db.sql';
END

PRINT '';
PRINT 'Database: ' + DB_NAME();
PRINT 'Server: ' + @@SERVERNAME;
PRINT 'Validation completed at: ' + CONVERT(VARCHAR, GETUTCDATE(), 120) + ' UTC';
