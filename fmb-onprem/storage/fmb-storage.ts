import sql from 'mssql';
import type { 
  User, UpsertUser, 
  Project, InsertProject,
  TimeEntry, InsertTimeEntry,
  Employee, InsertEmployee,
  Organization, InsertOrganization,
  Department, InsertDepartment
} from '../../shared/schema.js';

// Added missing import types
import { 
  InsertProject, 
  InsertTask, 
  InsertTimeEntry,
  Project,
  Task,
  TimeEntry,
  User
} from '../../shared/schema.js';

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
          profileImageUrl = source.profileImageUrl,
          updatedAt = GETUTCDATE()
      WHEN NOT MATCHED THEN
        INSERT (id, email, firstName, lastName, profileImageUrl, role, isActive, createdAt, updatedAt)
        VALUES (source.id, source.email, source.firstName, source.lastName, source.profileImageUrl, 
                COALESCE(source.role, 'employee'), COALESCE(source.isActive, 1), GETUTCDATE(), GETUTCDATE())
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

    await request.query('UPDATE users SET role = @role, updatedAt = GETUTCDATE() WHERE id = @id');
  }

  // Project management
  async createProject(projectData: InsertProject): Promise<Project> {
    console.log('📝 [FMB-STORAGE] Creating project:', projectData);

    const pool = this.getPool();
    const request = pool.request();

    const id = crypto.randomUUID();
    const query = `
      INSERT INTO projects (id, name, projectNumber, description, color, startDate, endDate, 
                          isEnterpriseWide, userId, isTemplate, allowTimeTracking, requireTaskSelection,
                          enableBudgetTracking, enableBilling, createdAt, updatedAt)
      OUTPUT INSERTED.*
      VALUES (@id, @name, @projectNumber, @description, @color, @startDate, @endDate,
              @isEnterpriseWide, @userId, @isTemplate, @allowTimeTracking, @requireTaskSelection,
              @enableBudgetTracking, @enableBilling, GETUTCDATE(), GETUTCDATE())
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

    const id = crypto.randomUUID();
    const query = `
      INSERT INTO time_entries (id, userId, projectId, taskId, description, date, startTime, endTime,
                               duration, isTemplate, isBillable, isApproved, isManualEntry, isTimerEntry,
                               createdAt, updatedAt)
      OUTPUT INSERTED.*
      VALUES (@id, @userId, @projectId, @taskId, @description, @date, @startTime, @endTime,
              @duration, @isTemplate, @isBillable, @isApproved, @isManualEntry, @isTimerEntry,
              GETUTCDATE(), GETUTCDATE())
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

    const id = crypto.randomUUID();
    const query = `
      INSERT INTO organizations (id, name, description, userId, createdAt, updatedAt)
      OUTPUT INSERTED.*
      VALUES (@id, @name, @description, @userId, GETUTCDATE(), GETUTCDATE())
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
}
