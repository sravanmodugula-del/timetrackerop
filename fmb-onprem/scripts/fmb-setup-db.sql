
-- =============================================================================
-- FMB TimeTracker Database Setup for MS SQL Server
-- Run this script on HUB-SQL1TST-LIS
-- =============================================================================

USE timetracker;
GO

-- =============================================================================
-- Drop existing tables if they exist (for clean setup)
-- =============================================================================

IF OBJECT_ID('time_entries', 'U') IS NOT NULL DROP TABLE time_entries;
IF OBJECT_ID('tasks', 'U') IS NOT NULL DROP TABLE tasks;
IF OBJECT_ID('projects', 'U') IS NOT NULL DROP TABLE projects;
IF OBJECT_ID('departments', 'U') IS NOT NULL DROP TABLE departments;
IF OBJECT_ID('organizations', 'U') IS NOT NULL DROP TABLE organizations;
IF OBJECT_ID('users', 'U') IS NOT NULL DROP TABLE users;

-- =============================================================================
-- Create Organizations Table
-- =============================================================================

CREATE TABLE organizations (
    id NVARCHAR(255) PRIMARY KEY,
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX),
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE()
);

-- =============================================================================
-- Create Users Table
-- =============================================================================

CREATE TABLE users (
    id NVARCHAR(255) PRIMARY KEY,
    email NVARCHAR(255) UNIQUE NOT NULL,
    first_name NVARCHAR(255),
    last_name NVARCHAR(255),
    profile_image_url NVARCHAR(MAX),
    role NVARCHAR(50) DEFAULT 'employee',
    organization_id NVARCHAR(255),
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE SET NULL
);

-- =============================================================================
-- Create Departments Table
-- =============================================================================

CREATE TABLE departments (
    id NVARCHAR(255) PRIMARY KEY,
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX),
    organization_id NVARCHAR(255),
    manager_id NVARCHAR(255),
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (manager_id) REFERENCES users(id) ON DELETE SET NULL
);

-- =============================================================================
-- Create Projects Table
-- =============================================================================

CREATE TABLE projects (
    id NVARCHAR(255) PRIMARY KEY,
    name NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX),
    status NVARCHAR(50) DEFAULT 'active',
    organization_id NVARCHAR(255),
    department_id NVARCHAR(255),
    manager_id NVARCHAR(255),
    start_date DATE,
    end_date DATE,
    budget DECIMAL(10,2),
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (organization_id) REFERENCES organizations(id) ON DELETE CASCADE,
    FOREIGN KEY (department_id) REFERENCES departments(id) ON DELETE SET NULL,
    FOREIGN KEY (manager_id) REFERENCES users(id) ON DELETE SET NULL
);

-- =============================================================================
-- Create Tasks Table
-- =============================================================================

CREATE TABLE tasks (
    id NVARCHAR(255) PRIMARY KEY,
    title NVARCHAR(255) NOT NULL,
    description NVARCHAR(MAX),
    status NVARCHAR(50) DEFAULT 'pending',
    priority NVARCHAR(50) DEFAULT 'medium',
    project_id NVARCHAR(255),
    assigned_to NVARCHAR(255),
    created_by NVARCHAR(255),
    due_date DATE,
    estimated_hours DECIMAL(5,2),
    actual_hours DECIMAL(5,2) DEFAULT 0,
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE,
    FOREIGN KEY (assigned_to) REFERENCES users(id) ON DELETE SET NULL,
    FOREIGN KEY (created_by) REFERENCES users(id) ON DELETE SET NULL
);

-- =============================================================================
-- Create Time Entries Table
-- =============================================================================

CREATE TABLE time_entries (
    id NVARCHAR(255) PRIMARY KEY,
    user_id NVARCHAR(255) NOT NULL,
    project_id NVARCHAR(255),
    task_id NVARCHAR(255),
    description NVARCHAR(MAX),
    hours DECIMAL(5,2) NOT NULL,
    date DATE NOT NULL,
    billable BIT DEFAULT 0,
    status NVARCHAR(50) DEFAULT 'draft',
    created_at DATETIME2 DEFAULT GETDATE(),
    updated_at DATETIME2 DEFAULT GETDATE(),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE SET NULL,
    FOREIGN KEY (task_id) REFERENCES tasks(id) ON DELETE SET NULL
);

-- =============================================================================
-- Create Indexes for Performance
-- =============================================================================

-- Users indexes
CREATE INDEX IX_users_email ON users(email);
CREATE INDEX IX_users_organization_id ON users(organization_id);
CREATE INDEX IX_users_role ON users(role);

-- Departments indexes
CREATE INDEX IX_departments_organization_id ON departments(organization_id);
CREATE INDEX IX_departments_manager_id ON departments(manager_id);

-- Projects indexes
CREATE INDEX IX_projects_organization_id ON projects(organization_id);
CREATE INDEX IX_projects_department_id ON projects(department_id);
CREATE INDEX IX_projects_manager_id ON projects(manager_id);
CREATE INDEX IX_projects_status ON projects(status);

-- Tasks indexes
CREATE INDEX IX_tasks_project_id ON tasks(project_id);
CREATE INDEX IX_tasks_assigned_to ON tasks(assigned_to);
CREATE INDEX IX_tasks_created_by ON tasks(created_by);
CREATE INDEX IX_tasks_status ON tasks(status);
CREATE INDEX IX_tasks_due_date ON tasks(due_date);

-- Time entries indexes
CREATE INDEX IX_time_entries_user_id ON time_entries(user_id);
CREATE INDEX IX_time_entries_project_id ON time_entries(project_id);
CREATE INDEX IX_time_entries_task_id ON time_entries(task_id);
CREATE INDEX IX_time_entries_date ON time_entries(date);
CREATE INDEX IX_time_entries_billable ON time_entries(billable);
CREATE INDEX IX_time_entries_status ON time_entries(status);

-- =============================================================================
-- Create Update Triggers for updated_at columns
-- =============================================================================

-- Organizations update trigger
CREATE TRIGGER TR_organizations_updated_at
ON organizations
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE organizations 
    SET updated_at = GETDATE()
    FROM organizations o
    INNER JOIN inserted i ON o.id = i.id;
END;
GO

-- Users update trigger
CREATE TRIGGER TR_users_updated_at
ON users
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE users 
    SET updated_at = GETDATE()
    FROM users u
    INNER JOIN inserted i ON u.id = i.id;
END;
GO

-- Departments update trigger
CREATE TRIGGER TR_departments_updated_at
ON departments
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE departments 
    SET updated_at = GETDATE()
    FROM departments d
    INNER JOIN inserted i ON d.id = i.id;
END;
GO

-- Projects update trigger
CREATE TRIGGER TR_projects_updated_at
ON projects
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE projects 
    SET updated_at = GETDATE()
    FROM projects p
    INNER JOIN inserted i ON p.id = i.id;
END;
GO

-- Tasks update trigger
CREATE TRIGGER TR_tasks_updated_at
ON tasks
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE tasks 
    SET updated_at = GETDATE()
    FROM tasks t
    INNER JOIN inserted i ON t.id = i.id;
END;
GO

-- Time entries update trigger
CREATE TRIGGER TR_time_entries_updated_at
ON time_entries
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE time_entries 
    SET updated_at = GETDATE()
    FROM time_entries te
    INNER JOIN inserted i ON te.id = i.id;
END;
GO

-- =============================================================================
-- Insert Sample Data for Testing
-- =============================================================================

-- Insert default organization
INSERT INTO organizations (id, name, description) 
VALUES ('fmb-org-1', 'FMB Corporation', 'First Midwest Bank Organization');

-- Insert test admin user
INSERT INTO users (id, email, first_name, last_name, role, organization_id)
VALUES ('admin-user-1', 'admin@fmb.com', 'System', 'Administrator', 'admin', 'fmb-org-1');

-- Insert test department
INSERT INTO departments (id, name, description, organization_id, manager_id)
VALUES ('dept-it-1', 'Information Technology', 'IT Department', 'fmb-org-1', 'admin-user-1');

-- Insert test project
INSERT INTO projects (id, name, description, status, organization_id, department_id, manager_id)
VALUES ('proj-timetracker-1', 'TimeTracker Implementation', 'Implementation of FMB TimeTracker system', 'active', 'fmb-org-1', 'dept-it-1', 'admin-user-1');

-- =============================================================================
-- Validation Queries
-- =============================================================================

PRINT 'Database setup completed successfully!';
PRINT '';
PRINT 'Validation:';

SELECT 'Organizations' as TableName, COUNT(*) as RecordCount FROM organizations
UNION ALL
SELECT 'Users', COUNT(*) FROM users
UNION ALL
SELECT 'Departments', COUNT(*) FROM departments
UNION ALL
SELECT 'Projects', COUNT(*) FROM projects
UNION ALL
SELECT 'Tasks', COUNT(*) FROM tasks
UNION ALL
SELECT 'Time Entries', COUNT(*) FROM time_entries;

PRINT '';
PRINT 'Setup complete! The TimeTracker database is ready for use.';
