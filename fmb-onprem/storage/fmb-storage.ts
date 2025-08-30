import sql from 'mssql';
import type {
  User, UpsertUser,
  Project, InsertProject,
  TimeEntry, InsertTimeEntry,
  Employee, InsertEmployee,
  Organization, InsertOrganization,
  Department, InsertDepartment,
  Task, InsertTask, TimeEntryWithProject
} from '../../shared/schema.js';

import { randomUUID } from 'crypto';

interface FmbDatabaseConfig {
  server: string;
  database: string;
  user: string;
  password: string;
  options: Record<string, any>;
}

export class FmbStorage {
  private pool: sql.ConnectionPool | null = null;
  private config: sql.config;

  constructor(config: FmbDatabaseConfig) {
    this.config = {
      server: config.server,
      database: config.database,
      user: config.user,
      password: config.password,
      port: 1433,
      options: {
        encrypt: true,
        trustServerCertificate: true,
        enableArithAbort: true,
        connectTimeout: 30000,
        requestTimeout: 30000,
        ...config.options
      }
    };
  }

  async connect(): Promise<void> {
    try {
      this.pool = new sql.ConnectionPool(this.config);
      await this.pool.connect();
      console.log('✅ FMB MS SQL Database connected successfully');
    } catch (error) {
      console.error('❌ Failed to connect to FMB MS SQL Database:', error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    if (this.pool) {
      await this.pool.close();
      this.pool = null;
    }
  }

  private getPool(): sql.ConnectionPool {
    if (!this.pool) {
      throw new Error('Database not connected');
    }
    return this.pool;
  }

  // User management
  async upsertUser(user: UpsertUser): Promise<User> {
    const pool = this.getPool();
    const request = pool.request();

    const query = `
      MERGE users AS target
      USING (VALUES (@id, @email, @firstName, @lastName, @profileImageUrl, @role, @isActive))
      AS source (id, email, firstName, lastName, profileImageUrl, role, isActive)
      ON target.id = source.id
      WHEN MATCHED THEN
        UPDATE SET
          email = source.email,
          firstName = source.firstName,
          lastName = source.lastName,
          profileImageUrl = source.profileImageUrl
      WHEN NOT MATCHED THEN
        INSERT (id, email, firstName, lastName, profileImageUrl, role, isActive, createdAt)
        VALUES (source.id, source.email, source.firstName, source.lastName, source.profileImageUrl,
                COALESCE(source.role, 'employee'), COALESCE(source.isActive, 1), GETUTCDATE())
      OUTPUT INSERTED.*;
    `;

    request.input('id', sql.VarChar(255), user.id);
    request.input('email', sql.VarChar(255), user.email);
    request.input('firstName', sql.VarChar(255), user.firstName);
    request.input('lastName', sql.VarChar(255), user.lastName);
    request.input('profileImageUrl', sql.VarChar(255), user.profileImageUrl);
    request.input('role', sql.VarChar(50), user.role || 'employee');
    request.input('isActive', sql.Bit, user.isActive !== false);

    const result = await request.query(query);
    return result.recordset[0];
  }

  async getUser(id: string): Promise<User | null> {
    const pool = this.getPool();
    const request = pool.request();

    request.input('id', sql.VarChar(255), id);
    const result = await request.query('SELECT * FROM users WHERE id = @id');

    return result.recordset[0] || null;
  }

  async updateUserRole(id: string, role: string): Promise<void> {
    const pool = this.getPool();
    const request = pool.request();

    request.input('id', sql.VarChar(255), id);
    request.input('role', sql.VarChar(50), role);

    await request.query('UPDATE users SET role = @role WHERE id = @id');
  }

  // Project management
  async createProject(projectData: InsertProject): Promise<Project> {
    console.log('📝 [FMB-STORAGE] Creating project:', projectData);

    const pool = this.getPool();
    const request = pool.request();

    const id = randomUUID();
    const query = `
      INSERT INTO projects (id, name, projectNumber, description, color, startDate, endDate,
                          isEnterpriseWide, userId, isTemplate, allowTimeTracking, requireTaskSelection,
                          enableBudgetTracking, enableBilling, createdAt)
      OUTPUT INSERTED.*
      VALUES (@id, @name, @projectNumber, @description, @color, @startDate, @endDate,
              @isEnterpriseWide, @userId, @isTemplate, @allowTimeTracking, @requireTaskSelection,
              @enableBudgetTracking, @enableBilling, GETUTCDATE())
    `;

    request.input('id', sql.VarChar(255), id);
    request.input('name', sql.VarChar(255), projectData.name);
    request.input('projectNumber', sql.VarChar(50), projectData.projectNumber);
    request.input('description', sql.Text, projectData.description);
    request.input('color', sql.VarChar(7), projectData.color || '#1976D2');
    request.input('startDate', sql.DateTime2, projectData.startDate);
    request.input('endDate', sql.DateTime2, projectData.endDate);
    request.input('isEnterpriseWide', sql.Bit, projectData.isEnterpriseWide !== false);
    request.input('userId', sql.VarChar(255), projectData.userId);
    request.input('isTemplate', sql.Bit, projectData.isTemplate || false);
    request.input('allowTimeTracking', sql.Bit, projectData.allowTimeTracking !== false);
    request.input('requireTaskSelection', sql.Bit, projectData.requireTaskSelection || false);
    request.input('enableBudgetTracking', sql.Bit, projectData.enableBudgetTracking || false);
    request.input('enableBilling', sql.Bit, projectData.enableBilling || false);

    const result = await request.query(query);
    return result.recordset[0];
  }

  async getProjects(userId: string): Promise<Project[]> {
    const pool = this.getPool();
    const request = pool.request();

    request.input('userId', sql.VarChar(255), userId);
    const result = await request.query(`
      SELECT * FROM projects
      WHERE isEnterpriseWide = 1 OR userId = @userId
      ORDER BY createdAt DESC
    `);

    return result.recordset;
  }

  // Time entry management
  async createTimeEntry(timeEntryData: InsertTimeEntry): Promise<TimeEntry> {
    console.log('⏰ [FMB-STORAGE] Creating time entry:', timeEntryData);

    const pool = this.getPool();
    const request = pool.request();

    const id = randomUUID();
    const query = `
      INSERT INTO time_entries (id, userId, projectId, taskId, description, date, startTime, endTime,
                               duration, isTemplate, isBillable, isApproved, isManualEntry, isTimerEntry,
                               createdAt)
      OUTPUT INSERTED.*
      VALUES (@id, @userId, @projectId, @taskId, @description, @date, @startTime, @endTime,
              @duration, @isTemplate, @isBillable, @isApproved, @isManualEntry, @isTimerEntry,
              GETUTCDATE())
    `;

    request.input('id', sql.VarChar(255), id);
    request.input('userId', sql.VarChar(255), timeEntryData.userId);
    request.input('projectId', sql.VarChar(255), timeEntryData.projectId);
    request.input('taskId', sql.VarChar(255), timeEntryData.taskId);
    request.input('description', sql.Text, timeEntryData.description);
    request.input('date', sql.Date, timeEntryData.date);
    request.input('startTime', sql.VarChar(5), timeEntryData.startTime);
    request.input('endTime', sql.VarChar(5), timeEntryData.endTime);
    request.input('duration', sql.Decimal(5, 2), timeEntryData.duration);
    request.input('isTemplate', sql.Bit, timeEntryData.isTemplate || false);
    request.input('isBillable', sql.Bit, timeEntryData.isBillable || false);
    request.input('isApproved', sql.Bit, timeEntryData.isApproved || false);
    request.input('isManualEntry', sql.Bit, timeEntryData.isManualEntry !== false);
    request.input('isTimerEntry', sql.Bit, timeEntryData.isTimerEntry || false);

    const result = await request.query(query);
    return result.recordset[0];
  }

  async getTimeEntries(userId: string, userRole: string): Promise<TimeEntry[]> {
    const pool = this.getPool();
    const request = pool.request();

    let query = 'SELECT * FROM time_entries';

    if (userRole !== 'admin') {
      query += ' WHERE userId = @userId';
      request.input('userId', sql.VarChar(255), userId);
    }

    query += ' ORDER BY date DESC, createdAt DESC';

    const result = await request.query(query);
    return result.recordset;
  }

  // Organization management
  async createOrganization(org: InsertOrganization): Promise<Organization> {
    const pool = this.getPool();
    const request = pool.request();

    const id = randomUUID();
    const query = `
      INSERT INTO organizations (id, name, description, userId, createdAt)
      OUTPUT INSERTED.*
      VALUES (@id, @name, @description, @userId, GETUTCDATE())
    `;

    request.input('id', sql.VarChar(255), id);
    request.input('name', sql.VarChar(255), org.name);
    request.input('description', sql.Text, org.description);
    request.input('userId', sql.VarChar(255), org.userId);

    const result = await request.query(query);
    return result.recordset[0];
  }

  async getOrganizations(): Promise<Organization[]> {
    const pool = this.getPool();
    const result = await pool.request().query('SELECT * FROM organizations ORDER BY name');
    return result.recordset;
  }

  // Department management
  async createDepartment(dept: InsertDepartment): Promise<Department> {
    const pool = this.getPool();
    const request = pool.request();

    const id = randomUUID();
    const query = `
      INSERT INTO departments (id, name, organizationId, managerId, description, userId, createdAt)
      OUTPUT INSERTED.*
      VALUES (@id, @name, @organizationId, @managerId, @description, @userId, GETUTCDATE())
    `;

    request.input('id', sql.VarChar(255), id);
    request.input('name', sql.VarChar(255), dept.name);
    request.input('organizationId', sql.VarChar(255), dept.organizationId);
    request.input('managerId', sql.VarChar(255), dept.managerId);
    request.input('description', sql.VarChar(255), dept.description);
    request.input('userId', sql.VarChar(255), dept.userId);

    const result = await request.query(query);
    return result.recordset[0];
  }

  async getDepartments(): Promise<Department[]> {
    const pool = this.getPool();
    const result = await pool.request().query('SELECT * FROM departments ORDER BY name');
    return result.recordset;
  }

  // Employee management
  async createEmployee(emp: InsertEmployee): Promise<Employee> {
    const pool = this.getPool();
    const request = pool.request();

    const id = randomUUID();
    const query = `
      INSERT INTO employees (id, employeeId, firstName, lastName, department, userId, createdAt)
      OUTPUT INSERTED.*
      VALUES (@id, @employeeId, @firstName, @lastName, @department, @userId, GETUTCDATE())
    `;

    request.input('id', sql.VarChar(255), id);
    request.input('employeeId', sql.VarChar(255), emp.employeeId);
    request.input('firstName', sql.VarChar(255), emp.firstName);
    request.input('lastName', sql.VarChar(255), emp.lastName);
    request.input('department', sql.VarChar(255), emp.department);
    request.input('userId', sql.VarChar(255), emp.userId);

    const result = await request.query(query);
    return result.recordset[0];
  }

  async getEmployees(): Promise<Employee[]> {
    const pool = this.getPool();
    const result = await pool.request().query('SELECT * FROM employees ORDER BY firstName, lastName');
    return result.recordset;
  }

  // Task management
  async createTask(taskData: InsertTask): Promise<Task> {
    const pool = this.getPool();
    const request = pool.request();

    const id = randomUUID();
    const query = `
      INSERT INTO tasks (id, projectId, name, description, status, createdAt)
      OUTPUT INSERTED.*
      VALUES (@id, @projectId, @name, @description, @status, GETUTCDATE())
    `;

    request.input('id', sql.VarChar(255), id);
    request.input('projectId', sql.VarChar(255), taskData.projectId);
    request.input('name', sql.VarChar(255), taskData.name);
    request.input('description', sql.Text, taskData.description);
    request.input('status', sql.VarChar(50), taskData.status || 'active');

    const result = await request.query(query);
    return result.recordset[0];
  }

  async getTasks(projectId: string): Promise<Task[]> {
    const pool = this.getPool();
    const request = pool.request();

    request.input('projectId', sql.VarChar(255), projectId);
    const result = await request.query('SELECT * FROM tasks WHERE projectId = @projectId ORDER BY name');
    return result.recordset;
  }

  async updateTask(id: string, updates: Partial<Task>): Promise<Task> {
    const pool = this.getPool();
    const request = pool.request();

    const setParts = [];
    if (updates.name !== undefined) {
      setParts.push('name = @name');
      request.input('name', sql.VarChar(255), updates.name);
    }
    if (updates.description !== undefined) {
      setParts.push('description = @description');
      request.input('description', sql.Text, updates.description);
    }
    if (updates.status !== undefined) {
      setParts.push('status = @status');
      request.input('status', sql.VarChar(50), updates.status);
    }

    if (setParts.length === 0) {
      throw new Error('No updates provided');
    }

    setParts.push('updatedAt = GETUTCDATE()');

    const query = `
      UPDATE tasks 
      SET ${setParts.join(', ')} 
      OUTPUT INSERTED.*
      WHERE id = @id
    `;

    request.input('id', sql.VarChar(255), id);
    const result = await request.query(query);
    return result.recordset[0];
  }

  async deleteTask(id: string): Promise<void> {
    const pool = this.getPool();
    const request = pool.request();

    request.input('id', sql.VarChar(255), id);
    await request.query('DELETE FROM tasks WHERE id = @id');
  }

  // Project employee management
  async addProjectEmployee(projectId: string, employeeId: string, userId: string): Promise<void> {
    const pool = this.getPool();
    const request = pool.request();

    const id = randomUUID();
    request.input('id', sql.VarChar(255), id);
    request.input('projectId', sql.VarChar(255), projectId);
    request.input('employeeId', sql.VarChar(255), employeeId);
    request.input('userId', sql.VarChar(255), userId);

    await request.query(`
      INSERT INTO project_employees (id, projectId, employeeId, userId, createdAt)
      VALUES (@id, @projectId, @employeeId, @userId, GETUTCDATE())
    `);
  }

  async removeProjectEmployee(projectId: string, employeeId: string): Promise<void> {
    const pool = this.getPool();
    const request = pool.request();

    request.input('projectId', sql.VarChar(255), projectId);
    request.input('employeeId', sql.VarChar(255), employeeId);

    await request.query(`
      DELETE FROM project_employees 
      WHERE projectId = @projectId AND employeeId = @employeeId
    `);
  }

  async getProjectEmployees(projectId: string): Promise<any[]> {
    const pool = this.getPool();
    const request = pool.request();

    request.input('projectId', sql.VarChar(255), projectId);
    const result = await request.query(`
      SELECT pe.*, e.firstName, e.lastName, e.employeeId
      FROM project_employees pe
      JOIN employees e ON pe.employeeId = e.id
      WHERE pe.projectId = @projectId
    `);

    return result.recordset;
  }

  // Dashboard stats
  async getDashboardStats(userId: string, userRole: string, startDate: string, endDate: string): Promise<any> {
    const pool = this.getPool();
    const request = pool.request();

    let whereClause = '';
    if (userRole !== 'admin') {
      whereClause = 'AND te.userId = @userId';
      request.input('userId', sql.VarChar(255), userId);
    }

    request.input('startDate', sql.Date, startDate);
    request.input('endDate', sql.Date, endDate);

    const query = `
      SELECT
        COALESCE(SUM(CASE WHEN te.date = CAST(GETUTCDATE() AS DATE) THEN te.duration ELSE 0 END), 0) as todayHours,
        COALESCE(SUM(CASE WHEN te.date >= @startDate AND te.date <= @endDate THEN te.duration ELSE 0 END), 0) as weekHours,
        COALESCE(SUM(CASE WHEN te.date >= DATEADD(month, DATEDIFF(month, 0, GETUTCDATE()), 0) THEN te.duration ELSE 0 END), 0) as monthHours,
        COUNT(DISTINCT p.id) as activeProjects
      FROM time_entries te
      LEFT JOIN projects p ON te.projectId = p.id
      WHERE 1=1 ${whereClause}
    `;

    const result = await request.query(query);
    return result.recordset[0] || { todayHours: 0, weekHours: 0, monthHours: 0, activeProjects: 0 };
  }

  async getProjectTimeBreakdown(userId: string, startDate?: string, endDate?: string): Promise<Array<{
    project: Project;
    totalHours: number;
    percentage: number;
  }>> {
    const pool = this.getPool();

    // Get user role to determine access level
    const user = await this.getUser(userId);
    const userRole = user?.role || 'employee';

    let whereConditions = [];
    let parameters: any = {};

    // Role-based access control
    if (userRole === 'admin') {
      // Admin sees everything
    } else if (userRole === 'project_manager') {
      // Project managers see enterprise-wide projects
      whereConditions.push('p.isEnterpriseWide = 1');
    } else {
      // Employees see enterprise-wide projects only
      whereConditions.push('p.isEnterpriseWide = 1');
      whereConditions.push('te.userId = @userId');
      parameters.userId = userId;
    }

    if (startDate) {
      whereConditions.push('te.date >= @startDate');
      parameters.startDate = startDate;
    }

    if (endDate) {
      whereConditions.push('te.date <= @endDate');
      parameters.endDate = endDate;
    }

    const whereClause = whereConditions.length > 0 ? `WHERE ${whereConditions.join(' AND ')}` : '';

    const request = pool.request();
    Object.keys(parameters).forEach(key => {
      request.input(key, sql.NVarChar, parameters[key]);
    });

    const result = await request.query(`
      SELECT 
        p.id, p.name, p.description, p.userId, p.isEnterpriseWide, p.createdAt, p.updatedAt,
        COALESCE(SUM(CAST(te.duration AS DECIMAL(10,2))), 0) as totalHours
      FROM projects p
      LEFT JOIN time_entries te ON p.id = te.projectId
      ${whereClause}
      GROUP BY p.id, p.name, p.description, p.userId, p.isEnterpriseWide, p.createdAt, p.updatedAt
      HAVING COALESCE(SUM(CAST(te.duration AS DECIMAL(10,2))), 0) > 0
      ORDER BY totalHours DESC
    `);

    const totalHours = result.recordset.reduce((sum, row) => sum + Number(row.totalHours), 0);

    return result.recordset.map(row => ({
      project: {
        id: row.id,
        name: row.name,
        description: row.description,
        userId: row.userId,
        isEnterpriseWide: row.isEnterpriseWide,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      },
      totalHours: Number(row.totalHours),
      percentage: totalHours > 0 ? Math.round((Number(row.totalHours) / totalHours) * 100) : 0,
    }));
  }

  async getRecentActivity(userId: string, limit = 10, startDate?: string, endDate?: string): Promise<TimeEntryWithProject[]> {
    const pool = this.getPool();
    const request = pool.request();

    let query = `
      SELECT 
        te.id, te.userId, te.projectId, te.taskId, te.description, te.date, te.startTime, te.endTime, te.duration,
        te.isTemplate, te.isBillable, te.isApproved, te.isManualEntry, te.isTimerEntry, te.createdAt, te.updatedAt,
        p.name as projectName
      FROM time_entries te
      JOIN projects p ON te.projectId = p.id
      WHERE te.userId = @userId
    `;

    if (startDate) {
      query += ' AND te.date >= @startDate';
      request.input('startDate', sql.Date, startDate);
    }
    if (endDate) {
      query += ' AND te.date <= @endDate';
      request.input('endDate', sql.Date, endDate);
    }

    query += ' ORDER BY te.date DESC, te.createdAt DESC';
    query += ` OFFSET 0 ROWS FETCH NEXT ${limit} ROWS ONLY`;

    request.input('userId', sql.VarChar(255), userId);

    const result = await request.query(query);

    return result.recordset.map(row => ({
      id: row.id,
      userId: row.userId,
      projectId: row.projectId,
      taskId: row.taskId,
      description: row.description,
      date: row.date,
      startTime: row.startTime,
      endTime: row.endTime,
      duration: row.duration,
      isTemplate: row.isTemplate,
      isBillable: row.isBillable,
      isApproved: row.isApproved,
      isManualEntry: row.isManualEntry,
      isTimerEntry: row.isTimerEntry,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      projectName: row.projectName,
    }));
  }

  async getTestUsers(): Promise<User[]> {
    const pool = this.getPool();
    const result = await pool.request()
      .query(`
        SELECT id, email, firstName, lastName, role, profileImageUrl, isActive, lastLoginAt, createdAt, updatedAt
        FROM users 
        WHERE email LIKE '%timetracker.test'
        ORDER BY created_at ASC
      `);

    return result.recordset.map(row => ({
      id: row.id,
      email: row.email,
      firstName: row.firstName,
      lastName: row.lastName,
      role: row.role,
      profileImageUrl: row.profileImageUrl,
      isActive: row.isActive,
      lastLoginAt: row.lastLoginAt,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    }));
  }
}
