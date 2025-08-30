
import pkg from 'mssql';
const { sql } = pkg;
import type { 
  User, 
  Project, 
  TimeEntry, 
  Task, 
  Department, 
  Organization 
} from '../../shared/schema';

// FMB On-Premises Storage Implementation
// Uses MS SQL Server instead of PostgreSQL
export class FmbStorage {
  private pool: sql.ConnectionPool | null = null;

  constructor(private config: {
    server: string;
    database: string;
    user: string;
    password: string;
    options?: any;
  }) {}

  async connect() {
    if (!this.pool) {
      this.pool = new sql.ConnectionPool({
        server: this.config.server,
        database: this.config.database,
        user: this.config.user,
        password: this.config.password,
        options: {
          encrypt: true,
          trustServerCertificate: true,
          ...this.config.options
        }
      });
      await this.pool.connect();
    }
    return this.pool;
  }

  // User operations for SAML authentication
  async getUser(id: string): Promise<User | undefined> {
    const pool = await this.connect();
    const result = await pool.request()
      .input('id', sql.VarChar, id)
      .query('SELECT * FROM users WHERE id = @id');
    
    return result.recordset[0];
  }

  async upsertUser(userData: Partial<User>): Promise<User> {
    const pool = await this.connect();
    
    // Check if user exists
    const existingUser = await this.getUser(userData.id!);
    
    if (existingUser) {
      // Update existing user
      const result = await pool.request()
        .input('id', sql.VarChar, userData.id)
        .input('email', sql.VarChar, userData.email)
        .input('firstName', sql.VarChar, userData.firstName)
        .input('lastName', sql.VarChar, userData.lastName)
        .input('lastLoginAt', sql.DateTime, new Date())
        .query(`
          UPDATE users 
          SET email = @email, first_name = @firstName, last_name = @lastName, 
              last_login_at = @lastLoginAt, updated_at = GETDATE()
          WHERE id = @id;
          SELECT * FROM users WHERE id = @id;
        `);
      
      return result.recordset[0];
    } else {
      // Insert new user
      const result = await pool.request()
        .input('id', sql.VarChar, userData.id)
        .input('email', sql.VarChar, userData.email)
        .input('firstName', sql.VarChar, userData.firstName)
        .input('lastName', sql.VarChar, userData.lastName)
        .input('role', sql.VarChar, userData.role || 'employee')
        .input('lastLoginAt', sql.DateTime, new Date())
        .query(`
          INSERT INTO users (id, email, first_name, last_name, role, last_login_at, created_at, updated_at)
          VALUES (@id, @email, @firstName, @lastName, @role, @lastLoginAt, GETDATE(), GETDATE());
          SELECT * FROM users WHERE id = @id;
        `);
      
      return result.recordset[0];
    }
  }

  async updateUserRole(userId: string, role: string): Promise<User | undefined> {
    const pool = await this.connect();
    const result = await pool.request()
      .input('userId', sql.VarChar, userId)
      .input('role', sql.VarChar, role)
      .query(`
        UPDATE users SET role = @role, updated_at = GETDATE() WHERE id = @userId;
        SELECT * FROM users WHERE id = @userId;
      `);
    
    return result.recordset[0];
  }

  // Project operations
  async getProjects(): Promise<Project[]> {
    const pool = await this.connect();
    const result = await pool.request()
      .query('SELECT * FROM projects ORDER BY created_at DESC');
    
    return result.recordset;
  }

  // Time entry operations
  async getTimeEntries(userId: string, startDate?: Date, endDate?: Date): Promise<TimeEntry[]> {
    const pool = await this.connect();
    let query = 'SELECT * FROM time_entries WHERE user_id = @userId';
    const request = pool.request().input('userId', sql.VarChar, userId);
    
    if (startDate) {
      query += ' AND date >= @startDate';
      request.input('startDate', sql.Date, startDate);
    }
    
    if (endDate) {
      query += ' AND date <= @endDate';
      request.input('endDate', sql.Date, endDate);
    }
    
    query += ' ORDER BY date DESC, created_at DESC';
    
    const result = await request.query(query);
    return result.recordset;
  }

  // Dashboard operations
  async getDashboardStats(userId: string, userRole: string, startDate: Date, endDate: Date) {
    const pool = await this.connect();
    
    // Implementation similar to the PostgreSQL version but using MS SQL syntax
    const todayResult = await pool.request()
      .input('userId', sql.VarChar, userId)
      .input('today', sql.Date, new Date())
      .query(`
        SELECT ISNULL(SUM(hours), 0) as total
        FROM time_entries 
        WHERE ${userRole === 'admin' ? '1=1' : 'user_id = @userId'} 
        AND date = @today
      `);

    return {
      todayHours: parseFloat(todayResult.recordset[0]?.total || '0'),
      weekHours: 0, // Implement similar queries for week/month
      monthHours: 0,
      activeProjects: 0
    };
  }

  // Add missing methods that are called by database config
  async execute(query: string, params: any[] = []): Promise<any> {
    const pool = await this.connect();
    const request = pool.request();
    
    // Add parameters if provided
    params.forEach((param, index) => {
      request.input(`param${index}`, param);
    });
    
    const result = await request.query(query);
    return result.recordset;
  }

  async disconnect() {
    await this.close();
  }

  async close() {
    if (this.pool) {
      await this.pool.close();
      this.pool = null;
    }
  }
}
