
-- FMB TimeTracker On-Premises Database Setup Script for MS SQL Server
-- Run this script to create the necessary database schema

USE [timetracker];
GO

-- Enable snapshot isolation for better concurrency
ALTER DATABASE [timetracker] SET ALLOW_SNAPSHOT_ISOLATION ON;
ALTER DATABASE [timetracker] SET READ_COMMITTED_SNAPSHOT ON;
GO

-- Create schema for application tables
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = 'timetracker')
BEGIN
    EXEC('CREATE SCHEMA timetracker');
END
GO

-- Drop existing tables if they exist (in dependency order)
IF EXISTS (SELECT * FROM sys.tables WHERE name = 'time_entries' AND schema_id = SCHEMA_ID('timetracker'))
    DROP TABLE timetracker.time_entries;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'user_departments' AND schema_id = SCHEMA_ID('timetracker'))
    DROP TABLE timetracker.user_departments;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'tasks' AND schema_id = SCHEMA_ID('timetracker'))
    DROP TABLE timetracker.tasks;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'projects' AND schema_id = SCHEMA_ID('timetracker'))
    DROP TABLE timetracker.projects;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'departments' AND schema_id = SCHEMA_ID('timetracker'))
    DROP TABLE timetracker.departments;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'organizations' AND schema_id = SCHEMA_ID('timetracker'))
    DROP TABLE timetracker.organizations;

IF EXISTS (SELECT * FROM sys.tables WHERE name = 'users' AND schema_id = SCHEMA_ID('timetracker'))
    DROP TABLE timetracker.users;

PRINT 'Existing tables dropped successfully.';
GO

-- Users table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'users' AND schema_id = SCHEMA_ID('timetracker'))
BEGIN
    CREATE TABLE timetracker.users (
        id NVARCHAR(50) PRIMARY KEY,
        email NVARCHAR(320) NOT NULL UNIQUE,
        firstName NVARCHAR(100) NOT NULL,
        lastName NVARCHAR(100) NOT NULL,
        profileImageUrl NVARCHAR(1000),
        role NVARCHAR(50) DEFAULT 'employee' CHECK (role IN ('admin', 'manager', 'project_manager', 'department_manager', 'employee')),
        createdAt DATETIME2 DEFAULT GETUTCDATE(),
        updatedAt DATETIME2 DEFAULT GETUTCDATE(),
        isActive BIT DEFAULT 1
    );
    
    CREATE INDEX IX_users_email ON timetracker.users(email);
    CREATE INDEX IX_users_role ON timetracker.users(role);
    CREATE INDEX IX_users_isActive ON timetracker.users(isActive);
END
GO

-- Organizations table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'organizations' AND schema_id = SCHEMA_ID('timetracker'))
BEGIN
    CREATE TABLE timetracker.organizations (
        id NVARCHAR(50) PRIMARY KEY,
        name NVARCHAR(255) NOT NULL,
        description NVARCHAR(MAX),
        createdAt DATETIME2 DEFAULT GETUTCDATE(),
        updatedAt DATETIME2 DEFAULT GETUTCDATE(),
        isActive BIT DEFAULT 1
    );
    
    CREATE INDEX IX_organizations_isActive ON timetracker.organizations(isActive);
END
GO

-- Departments table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'departments' AND schema_id = SCHEMA_ID('timetracker'))
BEGIN
    CREATE TABLE timetracker.departments (
        id NVARCHAR(50) PRIMARY KEY,
        name NVARCHAR(255) NOT NULL,
        description NVARCHAR(MAX),
        organizationId NVARCHAR(50),
        managerId NVARCHAR(50),
        createdAt DATETIME2 DEFAULT GETUTCDATE(),
        updatedAt DATETIME2 DEFAULT GETUTCDATE(),
        isActive BIT DEFAULT 1,
        
        CONSTRAINT FK_departments_organization FOREIGN KEY (organizationId) REFERENCES timetracker.organizations(id),
        CONSTRAINT FK_departments_manager FOREIGN KEY (managerId) REFERENCES timetracker.users(id)
    );
    
    CREATE INDEX IX_departments_organizationId ON timetracker.departments(organizationId);
    CREATE INDEX IX_departments_managerId ON timetracker.departments(managerId);
    CREATE INDEX IX_departments_isActive ON timetracker.departments(isActive);
END
GO

-- Projects table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'projects' AND schema_id = SCHEMA_ID('timetracker'))
BEGIN
    CREATE TABLE timetracker.projects (
        id NVARCHAR(50) PRIMARY KEY,
        name NVARCHAR(255) NOT NULL,
        description NVARCHAR(MAX),
        organizationId NVARCHAR(50),
        departmentId NVARCHAR(50),
        managerId NVARCHAR(50),
        startDate DATE,
        endDate DATE,
        isEnterpriseWide BIT DEFAULT 0,
        createdAt DATETIME2 DEFAULT GETUTCDATE(),
        updatedAt DATETIME2 DEFAULT GETUTCDATE(),
        isActive BIT DEFAULT 1,
        
        CONSTRAINT FK_projects_organization FOREIGN KEY (organizationId) REFERENCES timetracker.organizations(id),
        CONSTRAINT FK_projects_department FOREIGN KEY (departmentId) REFERENCES timetracker.departments(id),
        CONSTRAINT FK_projects_manager FOREIGN KEY (managerId) REFERENCES timetracker.users(id)
    );
    
    CREATE INDEX IX_projects_organizationId ON timetracker.projects(organizationId);
    CREATE INDEX IX_projects_departmentId ON timetracker.projects(departmentId);
    CREATE INDEX IX_projects_managerId ON timetracker.projects(managerId);
    CREATE INDEX IX_projects_isActive ON timetracker.projects(isActive);
    CREATE INDEX IX_projects_isEnterpriseWide ON timetracker.projects(isEnterpriseWide);
END
GO

-- Tasks table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'tasks' AND schema_id = SCHEMA_ID('timetracker'))
BEGIN
    CREATE TABLE timetracker.tasks (
        id NVARCHAR(50) PRIMARY KEY,
        name NVARCHAR(255) NOT NULL,
        description NVARCHAR(MAX),
        projectId NVARCHAR(50) NOT NULL,
        assignedToId NVARCHAR(50),
        status NVARCHAR(50) DEFAULT 'open' CHECK (status IN ('open', 'in_progress', 'completed', 'cancelled')),
        priority NVARCHAR(50) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'urgent')),
        estimatedHours DECIMAL(10,2),
        createdAt DATETIME2 DEFAULT GETUTCDATE(),
        updatedAt DATETIME2 DEFAULT GETUTCDATE(),
        isActive BIT DEFAULT 1,
        
        CONSTRAINT FK_tasks_project FOREIGN KEY (projectId) REFERENCES timetracker.projects(id),
        CONSTRAINT FK_tasks_assignedTo FOREIGN KEY (assignedToId) REFERENCES timetracker.users(id)
    );
    
    CREATE INDEX IX_tasks_projectId ON timetracker.tasks(projectId);
    CREATE INDEX IX_tasks_assignedToId ON timetracker.tasks(assignedToId);
    CREATE INDEX IX_tasks_status ON timetracker.tasks(status);
    CREATE INDEX IX_tasks_isActive ON timetracker.tasks(isActive);
END
GO

-- Time entries table
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'time_entries' AND schema_id = SCHEMA_ID('timetracker'))
BEGIN
    CREATE TABLE timetracker.time_entries (
        id NVARCHAR(50) PRIMARY KEY,
        userId NVARCHAR(50) NOT NULL,
        projectId NVARCHAR(50) NOT NULL,
        taskId NVARCHAR(50),
        date DATE NOT NULL,
        startTime TIME,
        endTime TIME,
        hours DECIMAL(10,2) NOT NULL,
        description NVARCHAR(MAX),
        createdAt DATETIME2 DEFAULT GETUTCDATE(),
        updatedAt DATETIME2 DEFAULT GETUTCDATE(),
        isActive BIT DEFAULT 1,
        
        CONSTRAINT FK_time_entries_user FOREIGN KEY (userId) REFERENCES timetracker.users(id),
        CONSTRAINT FK_time_entries_project FOREIGN KEY (projectId) REFERENCES timetracker.projects(id),
        CONSTRAINT FK_time_entries_task FOREIGN KEY (taskId) REFERENCES timetracker.tasks(id)
    );
    
    CREATE INDEX IX_time_entries_userId ON timetracker.time_entries(userId);
    CREATE INDEX IX_time_entries_projectId ON timetracker.time_entries(projectId);
    CREATE INDEX IX_time_entries_taskId ON timetracker.time_entries(taskId);
    CREATE INDEX IX_time_entries_date ON timetracker.time_entries(date);
    CREATE INDEX IX_time_entries_isActive ON timetracker.time_entries(isActive);
END
GO

-- User departments junction table - using surrogate key to avoid composite key length issues
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'user_departments' AND schema_id = SCHEMA_ID('timetracker'))
BEGIN
    CREATE TABLE timetracker.user_departments (
        id INT IDENTITY(1,1) PRIMARY KEY,
        userId NVARCHAR(50) NOT NULL,
        departmentId NVARCHAR(50) NOT NULL,
        createdAt DATETIME2 DEFAULT GETUTCDATE(),
        
        CONSTRAINT FK_user_departments_user FOREIGN KEY (userId) REFERENCES timetracker.users(id),
        CONSTRAINT FK_user_departments_department FOREIGN KEY (departmentId) REFERENCES timetracker.departments(id)
    );
    
    CREATE UNIQUE INDEX IX_user_departments_unique ON timetracker.user_departments(userId, departmentId);
END
GO

-- Create default admin user for initial setup
IF NOT EXISTS (SELECT * FROM timetracker.users WHERE email = 'admin@fmb.com')
BEGIN
    INSERT INTO timetracker.users (id, email, firstName, lastName, role, createdAt, updatedAt)
    VALUES ('fmb-admin-user', 'admin@fmb.com', 'FMB', 'Administrator', 'admin', GETUTCDATE(), GETUTCDATE());
    
    PRINT 'Default admin user created: admin@fmb.com';
END
GO

-- Create default organization
IF NOT EXISTS (SELECT * FROM timetracker.organizations WHERE name = 'FMB Corporation')
BEGIN
    INSERT INTO timetracker.organizations (id, name, description, createdAt, updatedAt)
    VALUES ('fmb-organization', 'FMB Corporation', 'Main FMB organization', GETUTCDATE(), GETUTCDATE());
    
    PRINT 'Default organization created: FMB Corporation';
END
GO

PRINT 'FMB TimeTracker database setup completed successfully!';
GO
