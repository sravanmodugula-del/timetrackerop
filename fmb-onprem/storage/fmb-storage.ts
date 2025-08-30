import sql from 'mssql';
import { loadFmbOnPremConfig } from '../config/fmb-env.js';
import type {
  User,
  UpsertUser,
  InsertProject,
  Project,
  InsertTask,
  Task,
  InsertTimeEntry,
  TimeEntry,
  TimeEntryWithProject,
  TaskWithProject,
  InsertEmployee,
  Employee,
  InsertProjectEmployee,
  ProjectEmployee,
  ProjectWithEmployees,
  Department,
  InsertDepartment,
  DepartmentWithManager,
  Organization,
  InsertOrganization,
  OrganizationWithDepartments,
} from '../../shared/schema.js';

interface FmbStorageConfig {
  server: string;
  database: string;
  user: string;
  password: string;
  options: {
    port: number;
    enableArithAbort: boolean;
    connectTimeout: number;
    requestTimeout: number;
  };
  encrypt: boolean;
  trustServerCertificate: boolean;
}

export class FmbStorage implements import('../../server/storage.js').IStorage {
  private pool: sql.ConnectionPool | null = null;
  private config: FmbStorageConfig;

  constructor(config: FmbStorageConfig) {
    this.config = config;
  }

  async connect(): Promise<void> {
    try {
      this.pool = new sql.ConnectionPool(this.config);
      await this.pool.connect();
      console.log('✅ [FMB-STORAGE] Connected to MS SQL Server');
    } catch (error) {
      console.error('❌ [FMB-STORAGE] Connection failed:', error);
      throw error;
    }
  }

  async disconnect(): Promise<void> {
    if (this.pool) {
      await this.pool.close();
      this.pool = null;
      console.log('✅ [FMB-STORAGE] Disconnected from MS SQL Server');
    }
  }

  async execute(query: string, params: any[] = []): Promise<any> {
    if (!this.pool) {
      throw new Error('Database not connected. Call connect() first.');
    }

    try {
      const request = this.pool.request();

      // Add parameters if provided
      params.forEach((param, index) => {
        request.input(`param${index}`, param);
      });

      this.storageLog('EXECUTE', `Running query: ${query.substring(0, 100)}...`, { paramCount: params.length });
      const result = await request.query(query);
      this.storageLog('EXECUTE', `Query completed successfully`, { recordCount: result.recordset?.length || 0 });
      return result.recordset || result.recordsets;
    } catch (error) {
      this.storageLog('EXECUTE', `Query execution failed: ${query.substring(0, 100)}...`, error);
      console.error('❌ [FMB-STORAGE] Query execution failed:', error);
      throw error;
    }
  }

  // Enhanced logging utility
  private storageLog(operation: string, message: string, data?: any) {
    const timestamp = new Date().toISOString();
    const logMessage = `${timestamp} 🗄️ [FMB-STORAGE] ${operation}: ${message}`;

    if (data) {
      console.log(logMessage, typeof data === 'object' ? JSON.stringify(data, null, 2) : data);
    } else {
      console.log(logMessage);
    }
  }

  // User operations
  async getUser(id: string): Promise<User | undefined> {
    try {
      this.storageLog('GET_USER', `Fetching user with id: ${id}`);
      const result = await this.execute(
        'SELECT id, email, firstName, lastName, profileImageUrl, role, isActive, lastLoginAt, createdAt, updatedAt FROM users WHERE id = @param0',
        [id]
      );
      const user = result[0];
      this.storageLog('GET_USER', `Found user: ${user ? user.email : 'not found'}`);
      return user;
    } catch (error) {
      this.storageLog('GET_USER', `Error fetching user ${id}:`, error);
      throw error;
    }
  }

  async upsertUser(user: UpsertUser): Promise<User> {
    try {
      this.storageLog('UPSERT_USER', `Upserting user: ${user.email} (${user.id})`);

      // Check if user exists
      const existingUser = await this.getUser(user.id);

      if (existingUser) {
        // Update existing user
        await this.execute(`
          UPDATE users 
          SET email = @param0, firstName = @param1, lastName = @param2, 
              profileImageUrl = @param3, lastLoginAt = GETUTCDATE(), updatedAt = GETUTCDATE()
          WHERE id = @param4
        `, [user.email, user.firstName, user.lastName, user.profileImageUrl, user.id]);

        const result = await this.execute(`
          SELECT id, email, firstName, lastName, profileImageUrl, role, isActive, lastLoginAt, createdAt, updatedAt 
          FROM users WHERE id = @param0
        `, [user.id]);

        this.storageLog('UPSERT_USER', `Successfully updated user ${user.email}`);
        return result[0];
      } else {
        // Insert new user
        await this.execute(`
          INSERT INTO users (id, email, firstName, lastName, profileImageUrl, role, isActive, lastLoginAt, createdAt, updatedAt)
          VALUES (@param0, @param1, @param2, @param3, @param4, @param5, @param6, GETUTCDATE(), GETUTCDATE(), GETUTCDATE())
        `, [user.id, user.email, user.firstName, user.lastName, user.profileImageUrl, 'employee', 1]);

        const result = await this.execute(`
          SELECT id, email, firstName, lastName, profileImageUrl, role, isActive, lastLoginAt, createdAt, updatedAt 
          FROM users WHERE id = @param0
        `, [user.id]);

        this.storageLog('UPSERT_USER', `Successfully created user ${user.email}`);
        return result[0];
      }
    } catch (error) {
      this.storageLog('UPSERT_USER', `Failed to upsert user ${user.email}:`, error);
      throw error;
    }
  }

  async updateUserRole(id: string, role: string): Promise<void> {
    this.storageLog('UPDATE_USER_ROLE', `Updating role for user ${id} to ${role}`);

    try {
      await this.execute(`
        UPDATE users 
        SET role = @param0, updated_at = GETDATE()
        WHERE id = @param1
      `, [role, id]);

      this.storageLog('UPDATE_USER_ROLE', `Successfully updated role for user ${id}`);
    } catch (error) {
      this.storageLog('UPDATE_USER_ROLE', `Failed to update role for user ${id}:`, error);
      throw error;
    }
  }

  // Project management
  async createProject(projectData: InsertProject): Promise<Project> {
    this.storageLog('CREATE_PROJECT', 'Creating project', projectData);

    const result = await this.execute(`
      INSERT INTO projects (
        id, name, projectNumber, description, color, startDate, endDate, 
        isEnterpriseWide, userId, createdAt, updatedAt, isTemplate, 
        allowTimeTracking, requireTaskSelection, enableBudgetTracking, enableBilling
      )
      OUTPUT INSERTED.*
      VALUES (
        NEWID(), @param0, @param1, @param2, @param3, @param4, @param5, 
        @param6, @param7, GETUTCDATE(), GETUTCDATE(), @param8, 
        @param9, @param10, @param11, @param12
      )
    `, [
      projectData.name, projectData.projectNumber, projectData.description, projectData.color,
      projectData.startDate, projectData.endDate, projectData.isEnterpriseWide, projectData.userId,
      projectData.isTemplate || false, projectData.allowTimeTracking !== false,
      projectData.requireTaskSelection || false, projectData.enableBudgetTracking || false,
      projectData.enableBilling || false
    ]);

    this.storageLog('CREATE_PROJECT', `Successfully created project: ${projectData.name}`);
    return result[0];
  }

  async getProjects(userId?: string): Promise<Project[]> {
    let query = 'SELECT * FROM projects';
    const params: any[] = [];

    if (userId) {
      query += ' WHERE isEnterpriseWide = 1 OR userId = @param0';
      params.push(userId);
    }

    query += ' ORDER BY createdAt DESC';

    const result = await this.execute(query, params);
    return result;
  }

  async getProject(id: string, userId: string): Promise<Project | undefined> {
    this.storageLog('GET_PROJECT', `Fetching project ${id} for user ${userId}`);
    const result = await this.execute(
      'SELECT * FROM projects WHERE id = @param0',
      [id]
    );
    return result[0];
  }

  async updateProject(id: string, projectData: Partial<InsertProject>, userId: string): Promise<Project | undefined> {
    this.storageLog('UPDATE_PROJECT', `Updating project ${id}`, projectData);

    const setParts: string[] = [];
    const params: any[] = [];
    let paramIndex = 0;

    Object.keys(projectData).forEach(key => {
      if (projectData[key as keyof InsertProject] !== undefined) {
        setParts.push(`${key} = @param${paramIndex}`);
        params.push(projectData[key as keyof InsertProject]);
        paramIndex++;
      }
    });

    if (setParts.length === 0) {
      return undefined;
    }

    setParts.push('updatedAt = GETUTCDATE()');
    params.push(id);

    const query = `
      UPDATE projects 
      SET ${setParts.join(', ')} 
      OUTPUT INSERTED.*
      WHERE id = @param${paramIndex}
    `;

    const result = await this.execute(query, params);
    this.storageLog('UPDATE_PROJECT', `Successfully updated project ${id}`);
    return result[0];
  }

  async deleteProject(id: string, userId: string): Promise<boolean> {
    this.storageLog('DELETE_PROJECT', `Deleting project ${id}`);
    try {
      await this.execute('DELETE FROM projects WHERE id = @param0', [id]);
      this.storageLog('DELETE_PROJECT', `Successfully deleted project ${id}`);
      return true;
    } catch (error) {
      this.storageLog('DELETE_PROJECT', `Failed to delete project ${id}:`, error);
      return false;
    }
  }

  // Time entry management
  async createTimeEntry(timeEntryData: InsertTimeEntry): Promise<TimeEntry> {
    this.storageLog('CREATE_TIME_ENTRY', 'Creating time entry', timeEntryData);

    const result = await this.execute(`
      INSERT INTO time_entries (
        id, userId, projectId, taskId, description, date, startTime, endTime, 
        duration, createdAt, updatedAt, isTemplate, isBillable, isApproved, 
        isManualEntry, isTimerEntry
      )
      OUTPUT INSERTED.*
      VALUES (
        NEWID(), @param0, @param1, @param2, @param3, @param4, @param5, @param6,
        @param7, GETUTCDATE(), GETUTCDATE(), @param8, @param9, @param10,
        @param11, @param12
      )
    `, [
      timeEntryData.userId, timeEntryData.projectId, timeEntryData.taskId, timeEntryData.description, timeEntryData.date,
      timeEntryData.startTime, timeEntryData.endTime, timeEntryData.duration, timeEntryData.isTemplate || false,
      timeEntryData.isBillable || false, timeEntryData.isApproved || false, timeEntryData.isManualEntry !== false,
      timeEntryData.isTimerEntry || false
    ]);

    this.storageLog('CREATE_TIME_ENTRY', `Successfully created time entry`);
    return result[0];
  }

  async getTimeEntries(userId: string, options?: { userRole?: string; startDate?: string; endDate?: string; limit?: number }): Promise<TimeEntry[]> {
    let query = 'SELECT * FROM time_entries';
    const params: any[] = [];
    let paramIndex = 0;
    const whereConditions: string[] = [];

    // Role-based filtering
    if (options?.userRole !== 'admin') {
      whereConditions.push(`userId = @param${paramIndex}`);
      params.push(userId);
      paramIndex++;
    }

    // Date range filtering
    if (options?.startDate) {
      whereConditions.push(`date >= @param${paramIndex}`);
      params.push(options.startDate);
      paramIndex++;
    }

    if (options?.endDate) {
      whereConditions.push(`date <= @param${paramIndex}`);
      params.push(options.endDate);
      paramIndex++;
    }

    if (whereConditions.length > 0) {
      query += ' WHERE ' + whereConditions.join(' AND ');
    }

    query += ' ORDER BY date DESC, createdAt DESC';

    // Add limit if specified
    if (options?.limit) {
      query += ` OFFSET 0 ROWS FETCH NEXT ${options.limit} ROWS ONLY`;
    }

    const result = await this.execute(query, params);
    return result;
  }

  async getTimeEntry(id: string, userId: string): Promise<TimeEntry | undefined> {
    this.storageLog('GET_TIME_ENTRY', `Fetching time entry ${id} for user ${userId}`);
    const result = await this.execute(
      'SELECT * FROM time_entries WHERE id = @param0',
      [id]
    );
    return result[0];
  }

  async updateTimeEntry(id: string, entryData: Partial<InsertTimeEntry>, userId: string): Promise<TimeEntry | undefined> {
    this.storageLog('UPDATE_TIME_ENTRY', `Updating time entry ${id}`, entryData);

    const setParts: string[] = [];
    const params: any[] = [];
    let paramIndex = 0;

    Object.keys(entryData).forEach(key => {
      if (entryData[key as keyof InsertTimeEntry] !== undefined) {
        setParts.push(`${key} = @param${paramIndex}`);
        params.push(entryData[key as keyof InsertTimeEntry]);
        paramIndex++;
      }
    });

    if (setParts.length === 0) {
      return undefined;
    }

    setParts.push('updatedAt = GETUTCDATE()');
    params.push(id);

    const query = `
      UPDATE time_entries 
      SET ${setParts.join(', ')} 
      OUTPUT INSERTED.*
      WHERE id = @param${paramIndex}
    `;

    const result = await this.execute(query, params);
    this.storageLog('UPDATE_TIME_ENTRY', `Successfully updated time entry ${id}`);
    return result[0];
  }

  async deleteTimeEntry(id: string, userId: string): Promise<boolean> {
    this.storageLog('DELETE_TIME_ENTRY', `Deleting time entry ${id}`);
    try {
      await this.execute('DELETE FROM time_entries WHERE id = @param0', [id]);
      this.storageLog('DELETE_TIME_ENTRY', `Successfully deleted time entry ${id}`);
      return true;
    } catch (error) {
      this.storageLog('DELETE_TIME_ENTRY', `Failed to delete time entry ${id}:`, error);
      return false;
    }
  }

  // Organization management
  async createOrganization(org: InsertOrganization): Promise<Organization> {
    this.storageLog('CREATE_ORGANIZATION', 'Creating organization', org);
    const result = await this.execute(`
      INSERT INTO organizations (id, name, description, userId, createdAt, updatedAt)
      OUTPUT INSERTED.*
      VALUES (NEWID(), @param0, @param1, @param2, GETUTCDATE(), GETUTCDATE())
    `, [org.name, org.description, org.userId]);
    this.storageLog('CREATE_ORGANIZATION', `Successfully created organization: ${org.name}`);
    return result[0];
  }

  async getOrganizations(): Promise<Organization[]> {
    const result = await this.execute('SELECT * FROM organizations ORDER BY name ASC');
    return result;
  }

  // Department management
  async createDepartment(dept: InsertDepartment): Promise<Department> {
    this.storageLog('CREATE_DEPARTMENT', 'Creating department', dept);
    const result = await this.execute(`
      INSERT INTO departments (id, name, organizationId, managerId, description, userId, createdAt, updatedAt)
      OUTPUT INSERTED.*
      VALUES (NEWID(), @param0, @param1, @param2, @param3, @param4, GETUTCDATE(), GETUTCDATE())
    `, [dept.name, dept.organizationId, dept.managerId, dept.description, dept.userId]);
    this.storageLog('CREATE_DEPARTMENT', `Successfully created department: ${dept.name}`);
    return result[0];
  }

  async getDepartments(): Promise<Department[]> {
    const result = await this.execute('SELECT * FROM departments ORDER BY name ASC');
    return result;
  }

  // Employee management
  async createEmployee(emp: InsertEmployee): Promise<Employee> {
    this.storageLog('CREATE_EMPLOYEE', 'Creating employee', emp);
    const result = await this.execute(`
      INSERT INTO employees (id, employeeId, firstName, lastName, department, userId, createdAt, updatedAt)
      OUTPUT INSERTED.*
      VALUES (NEWID(), @param0, @param1, @param2, @param3, @param4, GETUTCDATE(), GETUTCDATE())
    `, [emp.employeeId, emp.firstName, emp.lastName, emp.department, emp.userId]);
    this.storageLog('CREATE_EMPLOYEE', `Successfully created employee: ${emp.employeeId}`);
    return result[0];
  }

  async getEmployees(): Promise<Employee[]> {
    const result = await this.execute('SELECT * FROM employees ORDER BY firstName ASC, lastName ASC');
    return result;
  }

  // Task management
  async createTask(taskData: InsertTask): Promise<Task> {
    this.storageLog('CREATE_TASK', 'Creating task', taskData);
    const result = await this.execute(`
      INSERT INTO tasks (id, projectId, name, description, status, createdAt, updatedAt)
      OUTPUT INSERTED.*
      VALUES (NEWID(), @param0, @param1, @param2, @param3, GETUTCDATE(), GETUTCDATE())
    `, [taskData.projectId, taskData.name, taskData.description, taskData.status || 'active']);
    this.storageLog('CREATE_TASK', `Successfully created task: ${taskData.name}`);
    return result[0];
  }

  async getTasks(projectId: string): Promise<Task[]> {
    const result = await this.execute('SELECT * FROM tasks WHERE projectId = @param0 ORDER BY name ASC', [projectId]);
    return result;
  }

  async updateTask(id: string, updates: Partial<Task>): Promise<Task> {
    this.storageLog('UPDATE_TASK', `Updating task ${id}`, updates);
    const setParts: string[] = [];
    const params: any[] = [];
    let paramIndex = 0;

    if (updates.name !== undefined) {
      setParts.push('name = @param' + paramIndex);
      params.push(updates.name);
      paramIndex++;
    }
    if (updates.description !== undefined) {
      setParts.push('description = @param' + paramIndex);
      params.push(updates.description);
      paramIndex++;
    }
    if (updates.status !== undefined) {
      setParts.push('status = @param' + paramIndex);
      params.push(updates.status);
      paramIndex++;
    }

    if (setParts.length === 0) {
      throw new Error('No updates provided');
    }

    setParts.push('updatedAt = GETUTCDATE()');

    const query = `
      UPDATE tasks 
      SET ${setParts.join(', ')} 
      OUTPUT INSERTED.*
      WHERE id = @param${paramIndex}
    `;
    params.push(id);

    const result = await this.execute(query, params);
    this.storageLog('UPDATE_TASK', `Successfully updated task ${id}`);
    return result[0];
  }

  async deleteTask(id: string): Promise<void> {
    this.storageLog('DELETE_TASK', `Deleting task ${id}`);
    await this.execute('DELETE FROM tasks WHERE id = @param0', [id]);
    this.storageLog('DELETE_TASK', `Successfully deleted task ${id}`);
  }

  async getTask(id: string, userId: string): Promise<Task | undefined> {
    this.storageLog('GET_TASK', `Fetching task ${id} for user ${userId}`);
    const result = await this.execute(
      'SELECT * FROM tasks WHERE id = @param0',
      [id]
    );
    return result[0];
  }

  // Project employee management
  async addProjectEmployee(projectId: string, employeeId: string, userId: string): Promise<void> {
    this.storageLog('ADD_PROJECT_EMPLOYEE', `Adding employee ${employeeId} to project ${projectId}`);
    await this.execute(`
      INSERT INTO project_employees (id, projectId, employeeId, userId, createdAt)
      VALUES (NEWID(), @param0, @param1, @param2, GETUTCDATE())
    `, [projectId, employeeId, userId]);
    this.storageLog('ADD_PROJECT_EMPLOYEE', `Successfully added employee ${employeeId} to project ${projectId}`);
  }

  async removeProjectEmployee(projectId: string, employeeId: string): Promise<void> {
    this.storageLog('REMOVE_PROJECT_EMPLOYEE', `Removing employee ${employeeId} from project ${projectId}`);
    await this.execute(`
      DELETE FROM project_employees 
      WHERE projectId = @param0 AND employeeId = @param1
    `, [projectId, employeeId]);
    this.storageLog('REMOVE_PROJECT_EMPLOYEE', `Successfully removed employee ${employeeId} from project ${projectId}`);
  }

  async getProjectEmployees(projectId: string): Promise<ProjectEmployee[]> {
    this.storageLog('GET_PROJECT_EMPLOYEES', `Fetching employees for project ${projectId}`);
    const result = await this.execute(`
      SELECT pe.*, e.firstName, e.lastName, e.employeeId
      FROM project_employees pe
      JOIN employees e ON pe.employeeId = e.id
      WHERE pe.projectId = @param0
    `, [projectId]);
    return result;
  }

  // Dashboard stats
  async getDashboardStats(userId: string, startDate?: string, endDate?: string): Promise<{
    todayHours: number;
    weekHours: number;
    monthHours: number;
    activeProjects: number;
  }> {
    this.storageLog('GET_DASHBOARD_STATS', `Getting dashboard stats for user ${userId}`);

    const today = new Date().toISOString().split('T')[0];
    const weekStart = startDate || new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().split('T')[0];

    // Get today's hours
    const todayResult = await this.execute(`
      SELECT COALESCE(SUM(CAST(duration AS DECIMAL(10,2))), 0) as total 
      FROM time_entries 
      WHERE userId = @param0 AND date = @param1
    `, [userId, today]);

    // Get week's hours
    const weekResult = await this.execute(`
      SELECT COALESCE(SUM(CAST(duration AS DECIMAL(10,2))), 0) as total 
      FROM time_entries 
      WHERE userId = @param0 AND date >= @param1 AND date <= @param2
    `, [userId, weekStart, today]);

    // Get month's hours
    const monthResult = await this.execute(`
      SELECT COALESCE(SUM(CAST(duration AS DECIMAL(10,2))), 0) as total 
      FROM time_entries 
      WHERE userId = @param0 AND date >= @param1 AND date <= @param2
    `, [userId, monthStart, today]);

    // Get active projects count
    const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split('T')[0];
    const activeProjectsResult = await this.execute(`
      SELECT COUNT(DISTINCT projectId) as count 
      FROM time_entries 
      WHERE userId = @param0 AND date >= @param1
    `, [userId, thirtyDaysAgo]);

    return {
      todayHours: parseFloat(todayResult[0]?.total?.toString() || '0'),
      weekHours: parseFloat(weekResult[0]?.total?.toString() || '0'),
      monthHours: parseFloat(monthResult[0]?.total?.toString() || '0'),
      activeProjects: activeProjectsResult[0]?.count || 0,
    };
  }

  async getProjectTimeBreakdown(userId: string, startDate?: string, endDate?: string): Promise<Array<{
    project: Project;
    totalHours: number;
    percentage: number;
  }>> {
    let whereClause = 'WHERE te.userId = @param0';
    const params = [userId];
    let paramIndex = 1;

    if (startDate) {
      whereClause += ` AND te.date >= @param${paramIndex}`;
      params.push(startDate);
      paramIndex++;
    }

    if (endDate) {
      whereClause += ` AND te.date <= @param${paramIndex}`;
      params.push(endDate);
      paramIndex++;
    }

    const result = await this.execute(`
      SELECT 
        p.id, p.name, p.projectNumber, p.description, p.color, p.startDate, p.endDate, 
        p.isEnterpriseWide, p.userId, p.createdAt, p.updatedAt, p.isTemplate, 
        p.allowTimeTracking, p.requireTaskSelection, p.enableBudgetTracking, p.enableBilling,
        COALESCE(SUM(CAST(te.duration AS DECIMAL(10,2))), 0) as totalHours
      FROM projects p
      LEFT JOIN time_entries te ON p.id = te.projectId
      ${whereClause}
      GROUP BY p.id, p.name, p.projectNumber, p.description, p.color, p.startDate, p.endDate, 
               p.isEnterpriseWide, p.userId, p.createdAt, p.updatedAt, p.isTemplate, 
               p.allowTimeTracking, p.requireTaskSelection, p.enableBudgetTracking, p.enableBilling
      HAVING SUM(CAST(te.duration AS DECIMAL(10,2))) > 0
      ORDER BY SUM(CAST(te.duration AS DECIMAL(10,2))) DESC
    `, params);

    const totalHours = result.reduce((sum: number, row: any) => sum + Number(row.totalHours), 0);

    return result.map((row: any) => ({
      project: {
        id: row.id,
        name: row.name,
        projectNumber: row.projectNumber,
        description: row.description,
        color: row.color,
        startDate: row.startDate,
        endDate: row.endDate,
        isEnterpriseWide: row.isEnterpriseWide,
        userId: row.userId,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        isTemplate: row.isTemplate,
        allowTimeTracking: row.allowTimeTracking,
        requireTaskSelection: row.requireTaskSelection,
        enableBudgetTracking: row.enableBudgetTracking,
        enableBilling: row.enableBilling,
      },
      totalHours: Number(row.totalHours),
      percentage: totalHours > 0 ? Math.round((Number(row.totalHours) / totalHours) * 100) : 0,
    }));
  }

  async getDepartmentHoursSummary(userId: string, startDate?: string, endDate?: string): Promise<Array<{
    departmentId: string;
    departmentName: string;
    totalHours: number;
    employeeCount: number;
  }>> {
    this.storageLog('GET_DEPARTMENT_HOURS', `Getting department hours for user ${userId}`);

    // For now, return empty array since department structure needs to be properly set up
    // The 'department' column in employees table may not exist or may need to be a string field
    this.storageLog('GET_DEPARTMENT_HOURS', 'Returning empty department hours - department structure needs setup');
    return [];
  }

  async getTestUsers(): Promise<User[]> {
    this.storageLog('GET_TEST_USERS', 'Fetching test users');
    const result = await this.execute(`
      SELECT id, email, firstName, lastName, role, profileImageUrl, isActive, lastLoginAt, createdAt, updatedAt
      FROM users 
      WHERE email LIKE '%timetracker.test'
      ORDER BY createdAt ASC
    `);

    return result.map((row: any) => ({
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

  // Add missing IStorage interface methods
  async getAllUsers(): Promise<User[]> {
    this.storageLog('GET_ALL_USERS', 'Fetching all users');
    const result = await this.execute(`
      SELECT id, email, firstName, lastName, role, profileImageUrl, isActive, lastLoginAt, createdAt, updatedAt
      FROM users 
      ORDER BY createdAt ASC
    `);

    return result.map((row: any) => ({
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

  async getUsersWithoutEmployeeProfile(): Promise<User[]> {
    this.storageLog('GET_USERS_WITHOUT_EMPLOYEE', 'Fetching users without employee profiles');
    const result = await this.execute(`
      SELECT u.id, u.email, u.firstName, u.lastName, u.role, u.profileImageUrl, u.isActive, u.lastLoginAt, u.createdAt, u.updatedAt
      FROM users u
      LEFT JOIN employees e ON u.id = e.userId
      WHERE e.userId IS NULL
      ORDER BY u.createdAt ASC
    `);

    return result.map((row: any) => ({
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

  async getEmployeeProjects(userId: string): Promise<Project[]> {
    this.storageLog('GET_EMPLOYEE_PROJECTS', `Fetching projects for employee ${userId}`);
    // For now, return enterprise-wide projects
    const result = await this.execute(`
      SELECT * FROM projects WHERE isEnterpriseWide = 1 ORDER BY name ASC
    `);
    return result;
  }

  async getAllUserTasks(userId: string): Promise<TaskWithProject[]> {
    this.storageLog('GET_ALL_USER_TASKS', `Fetching all tasks for user ${userId}`);
    const result = await this.execute(`
      SELECT t.*, p.name as projectName, p.description as projectDescription, p.color as projectColor
      FROM tasks t
      INNER JOIN projects p ON t.projectId = p.id
      ORDER BY t.createdAt DESC
    `);

    return result.map((row: any) => ({
      id: row.id,
      projectId: row.projectId,
      name: row.name,
      description: row.description,
      status: row.status,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      project: {
        id: row.projectId,
        name: row.projectName,
        description: row.projectDescription,
        color: row.projectColor,
        projectNumber: '',
        startDate: null,
        endDate: null,
        isEnterpriseWide: true,
        userId: '',
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        isTemplate: false,
        allowTimeTracking: true,
        requireTaskSelection: false,
        enableBudgetTracking: false,
        enableBilling: false,
      }
    }));
  }

  async getRecentActivity(userId: string, limit = 10, startDate?: string, endDate?: string): Promise<TimeEntryWithProject[]> {
    this.storageLog('GET_RECENT_ACTIVITY', `Fetching recent activity for user ${userId}`);
    
    let whereClause = 'WHERE te.userId = @param0';
    const params = [userId];
    let paramIndex = 1;

    if (startDate) {
      whereClause += ` AND te.date >= @param${paramIndex}`;
      params.push(startDate);
      paramIndex++;
    }

    if (endDate) {
      whereClause += ` AND te.date <= @param${paramIndex}`;
      params.push(endDate);
      paramIndex++;
    }

    const result = await this.execute(`
      SELECT TOP ${limit}
        te.id, te.userId, te.projectId, te.taskId, te.description, te.date, 
        te.startTime, te.endTime, te.duration, te.createdAt, te.updatedAt,
        p.name as projectName, p.color as projectColor, p.description as projectDescription,
        t.name as taskName, t.description as taskDescription, t.status as taskStatus
      FROM time_entries te
      INNER JOIN projects p ON te.projectId = p.id
      LEFT JOIN tasks t ON te.taskId = t.id
      ${whereClause}
      ORDER BY te.date DESC, te.createdAt DESC
    `, params);

    return result.map((row: any) => ({
      id: row.id,
      userId: row.userId,
      projectId: row.projectId,
      taskId: row.taskId || null,
      description: row.description,
      date: row.date,
      startTime: row.startTime,
      endTime: row.endTime,
      duration: row.duration,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      project: {
        id: row.projectId,
        name: row.projectName,
        description: row.projectDescription,
        color: row.projectColor,
        projectNumber: '',
        startDate: null,
        endDate: null,
        isEnterpriseWide: true,
        userId: '',
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        isTemplate: false,
        allowTimeTracking: true,
        requireTaskSelection: false,
        enableBudgetTracking: false,
        enableBilling: false,
      },
      task: row.taskId ? {
        id: row.taskId,
        projectId: row.projectId,
        name: row.taskName,
        description: row.taskDescription,
        status: row.taskStatus,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      } : null
    }));
  }

  async getProjectTaskBreakdown(userId: string, startDate?: string, endDate?: string): Promise<Array<{
    project: Project;
    tasks: Array<{
      task: Task | null;
      totalHours: number;
    }>;
    totalHours: number;
  }>> {
    // Return empty array for now - complex query
    return [];
  }

  async linkUserToEmployee(userId: string, employeeId: string): Promise<Employee | undefined> {
    this.storageLog('LINK_USER_TO_EMPLOYEE', `Linking user ${userId} to employee ${employeeId}`);
    const result = await this.execute(`
      UPDATE employees 
      SET userId = @param0, updatedAt = GETUTCDATE() 
      OUTPUT INSERTED.*
      WHERE id = @param1
    `, [userId, employeeId]);
    return result[0];
  }

  async getProjectWithEmployees(id: string, userId: string): Promise<ProjectWithEmployees | undefined> {
    const project = await this.getProject(id, userId);
    if (!project) return undefined;

    if (project.isEnterpriseWide) {
      return { ...project, assignedEmployees: [] };
    }

    const employees = await this.getProjectEmployees(id);
    return { 
      ...project, 
      assignedEmployees: employees.map(emp => ({
        id: emp.id,
        employeeId: emp.employeeId,
        firstName: emp.firstName,
        lastName: emp.lastName,
        department: emp.department,
        userId: emp.userId,
        createdAt: emp.createdAt,
        updatedAt: emp.updatedAt,
      }))
    };
  }

  async assignEmployeesToProject(projectId: string, employeeIds: string[], userId: string): Promise<void> {
    this.storageLog('ASSIGN_EMPLOYEES_TO_PROJECT', `Assigning ${employeeIds.length} employees to project ${projectId}`);
    
    // Remove existing assignments
    await this.execute('DELETE FROM project_employees WHERE projectId = @param0', [projectId]);
    
    // Add new assignments
    for (const employeeId of employeeIds) {
      await this.addProjectEmployee(projectId, employeeId, userId);
    }
  }

  async removeEmployeeFromProject(projectId: string, employeeId: string, userId: string): Promise<boolean> {
    this.storageLog('REMOVE_EMPLOYEE_FROM_PROJECT', `Removing employee ${employeeId} from project ${projectId}`);
    try {
      await this.removeProjectEmployee(projectId, employeeId);
      return true;
    } catch (error) {
      this.storageLog('REMOVE_EMPLOYEE_FROM_PROJECT', `Failed to remove employee:`, error);
      return false;
    }
  }

  async getTimeEntriesForProject(projectId: string): Promise<any[]> {
    this.storageLog('GET_TIME_ENTRIES_FOR_PROJECT', `Fetching time entries for project ${projectId}`);
    const result = await this.execute(`
      SELECT te.*, u.firstName, u.lastName, u.email, t.name as taskName, t.description as taskDescription
      FROM time_entries te
      LEFT JOIN users u ON te.userId = u.id
      LEFT JOIN tasks t ON te.taskId = t.id
      WHERE te.projectId = @param0
      ORDER BY te.date DESC, te.createdAt DESC
    `, [projectId]);

    return result.map((row: any) => ({
      id: row.id,
      duration: parseFloat(row.duration),
      description: row.description,
      date: row.date,
      createdAt: row.createdAt,
      userId: row.userId,
      taskId: row.taskId,
      employee: {
        id: row.userId,
        firstName: row.firstName,
        lastName: row.lastName,
        email: row.email,
      },
      task: row.taskId ? {
        id: row.taskId,
        name: row.taskName,
        description: row.taskDescription,
        status: 'active',
      } : null
    }));
  }

  async createTestUsers(): Promise<User[]> {
    this.storageLog('CREATE_TEST_USERS', 'Creating test users');
    const testUsers = [
      { id: 'test-admin-001', email: 'admin@timetracker.test', firstName: 'Admin', lastName: 'User', role: 'admin' },
      { id: 'test-manager-001', email: 'manager@timetracker.test', firstName: 'Department', lastName: 'Manager', role: 'manager' },
      { id: 'test-pm-001', email: 'pm@timetracker.test', firstName: 'Project', lastName: 'Manager', role: 'project_manager' },
      { id: 'test-employee-001', email: 'employee@timetracker.test', firstName: 'Regular', lastName: 'Employee', role: 'employee' },
      { id: 'test-viewer-001', email: 'viewer@timetracker.test', firstName: 'Viewer', lastName: 'User', role: 'viewer' }
    ];

    const createdUsers: User[] = [];
    for (const userData of testUsers) {
      try {
        const existing = await this.getUser(userData.id);
        if (!existing) {
          await this.execute(`
            INSERT INTO users (id, email, firstName, lastName, role, isActive, createdAt, updatedAt)
            VALUES (@param0, @param1, @param2, @param3, @param4, 1, GETUTCDATE(), GETUTCDATE())
          `, [userData.id, userData.email, userData.firstName, userData.lastName, userData.role]);
        }
        const user = await this.getUser(userData.id);
        if (user) createdUsers.push(user);
      } catch (error) {
        this.storageLog('CREATE_TEST_USERS', `Error creating test user ${userData.email}:`, error);
      }
    }
    return createdUsers;
  }
}
