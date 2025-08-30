var __defProp = Object.defineProperty;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __esm = (fn, res) => function __init() {
  return fn && (res = (0, fn[__getOwnPropNames(fn)[0]])(fn = 0)), res;
};
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};

// fmb-onprem/config/fmb-env.ts
function loadFmbOnPremConfig() {
  const requiredVars = [
    "FMB_DB_SERVER",
    "FMB_DB_NAME",
    "FMB_DB_USER",
    "FMB_DB_PASSWORD",
    "FMB_SAML_ENTITY_ID",
    "FMB_SAML_SSO_URL",
    "FMB_SAML_CERTIFICATE",
    "FMB_SESSION_SECRET"
  ];
  const missing = requiredVars.filter((varName) => !process.env[varName]);
  if (missing.length > 0) {
    throw new Error(`Missing required FMB environment variables: ${missing.join(", ")}`);
  }
  return {
    database: {
      server: process.env.FMB_DB_SERVER,
      database: process.env.FMB_DB_NAME,
      user: process.env.FMB_DB_USER,
      password: process.env.FMB_DB_PASSWORD,
      port: parseInt(process.env.FMB_DB_PORT || "1433", 10),
      encrypt: process.env.FMB_DB_ENCRYPT !== "false",
      trustServerCertificate: process.env.FMB_DB_TRUST_CERT === "true"
    },
    saml: {
      entityId: process.env.FMB_SAML_ENTITY_ID,
      ssoUrl: process.env.FMB_SAML_SSO_URL,
      certificate: process.env.FMB_SAML_CERTIFICATE,
      acsUrl: process.env.FMB_SAML_ACS_URL || "https://timetracker.fmb.com/saml/acs"
    },
    app: {
      port: parseInt(process.env.PORT || "3000", 10),
      host: process.env.HOST || "0.0.0.0",
      sessionSecret: process.env.FMB_SESSION_SECRET,
      nodeEnv: process.env.NODE_ENV || "production"
    }
  };
}
function isFmbOnPremEnvironment() {
  return process.env.FMB_DEPLOYMENT === "onprem";
}
var init_fmb_env = __esm({
  "fmb-onprem/config/fmb-env.ts"() {
    "use strict";
  }
});

// fmb-onprem/storage/fmb-storage.ts
import sql from "mssql";
var FmbStorage;
var init_fmb_storage = __esm({
  "fmb-onprem/storage/fmb-storage.ts"() {
    "use strict";
    FmbStorage = class {
      constructor(config) {
        this.config = config;
      }
      pool = null;
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
      async getUser(id) {
        const pool2 = await this.connect();
        const result = await pool2.request().input("id", sql.VarChar, id).query("SELECT * FROM users WHERE id = @id");
        return result.recordset[0];
      }
      async upsertUser(userData) {
        const pool2 = await this.connect();
        const existingUser = await this.getUser(userData.id);
        if (existingUser) {
          const result = await pool2.request().input("id", sql.VarChar, userData.id).input("email", sql.VarChar, userData.email).input("firstName", sql.VarChar, userData.firstName).input("lastName", sql.VarChar, userData.lastName).input("lastLoginAt", sql.DateTime, /* @__PURE__ */ new Date()).query(`
          UPDATE users 
          SET email = @email, first_name = @firstName, last_name = @lastName, 
              last_login_at = @lastLoginAt, updated_at = GETDATE()
          WHERE id = @id;
          SELECT * FROM users WHERE id = @id;
        `);
          return result.recordset[0];
        } else {
          const result = await pool2.request().input("id", sql.VarChar, userData.id).input("email", sql.VarChar, userData.email).input("firstName", sql.VarChar, userData.firstName).input("lastName", sql.VarChar, userData.lastName).input("role", sql.VarChar, userData.role || "employee").input("lastLoginAt", sql.DateTime, /* @__PURE__ */ new Date()).query(`
          INSERT INTO users (id, email, first_name, last_name, role, last_login_at, created_at, updated_at)
          VALUES (@id, @email, @firstName, @lastName, @role, @lastLoginAt, GETDATE(), GETDATE());
          SELECT * FROM users WHERE id = @id;
        `);
          return result.recordset[0];
        }
      }
      async updateUserRole(userId, role) {
        const pool2 = await this.connect();
        const result = await pool2.request().input("userId", sql.VarChar, userId).input("role", sql.VarChar, role).query(`
        UPDATE users SET role = @role, updated_at = GETDATE() WHERE id = @userId;
        SELECT * FROM users WHERE id = @userId;
      `);
        return result.recordset[0];
      }
      // Project operations
      async getProjects() {
        const pool2 = await this.connect();
        const result = await pool2.request().query("SELECT * FROM projects ORDER BY created_at DESC");
        return result.recordset;
      }
      // Time entry operations
      async getTimeEntries(userId, startDate, endDate) {
        const pool2 = await this.connect();
        let query = "SELECT * FROM time_entries WHERE user_id = @userId";
        const request = pool2.request().input("userId", sql.VarChar, userId);
        if (startDate) {
          query += " AND date >= @startDate";
          request.input("startDate", sql.Date, startDate);
        }
        if (endDate) {
          query += " AND date <= @endDate";
          request.input("endDate", sql.Date, endDate);
        }
        query += " ORDER BY date DESC, created_at DESC";
        const result = await request.query(query);
        return result.recordset;
      }
      // Dashboard operations
      async getDashboardStats(userId, userRole, startDate, endDate) {
        const pool2 = await this.connect();
        const todayResult = await pool2.request().input("userId", sql.VarChar, userId).input("today", sql.Date, /* @__PURE__ */ new Date()).query(`
        SELECT ISNULL(SUM(hours), 0) as total
        FROM time_entries 
        WHERE ${userRole === "admin" ? "1=1" : "user_id = @userId"} 
        AND date = @today
      `);
        return {
          todayHours: parseFloat(todayResult.recordset[0]?.total || "0"),
          weekHours: 0,
          // Implement similar queries for week/month
          monthHours: 0,
          activeProjects: 0
        };
      }
      // Add missing methods that are called by database config
      async execute(query, params = []) {
        const pool2 = await this.connect();
        const request = pool2.request();
        params.forEach((param, index2) => {
          request.input(`param${index2}`, param);
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
    };
  }
});

// fmb-onprem/config/fmb-database.ts
async function initializeFmbDatabase() {
  console.log("\u{1F527} Initializing FMB on-premises MS SQL database...");
  const config = loadFmbOnPremConfig();
  fmbStorage = new FmbStorage({
    server: config.database.server,
    database: config.database.name,
    user: config.database.user,
    password: config.database.password,
    options: config.database.options
  });
  try {
    await fmbStorage.connect();
    console.log("\u2705 FMB MS SQL database connected successfully");
  } catch (error) {
    console.error("\u274C Failed to connect to FMB database:", error);
    throw error;
  }
}
function getFmbStorage() {
  if (!fmbStorage) {
    throw new Error("FMB database not initialized. Call initializeFmbDatabase() first.");
  }
  return fmbStorage;
}
var fmbStorage;
var init_fmb_database = __esm({
  "fmb-onprem/config/fmb-database.ts"() {
    "use strict";
    init_fmb_env();
    init_fmb_storage();
    fmbStorage = null;
  }
});

// shared/schema.ts
var schema_exports = {};
__export(schema_exports, {
  departments: () => departments,
  departmentsRelations: () => departmentsRelations,
  employees: () => employees,
  employeesRelations: () => employeesRelations,
  insertDepartmentSchema: () => insertDepartmentSchema,
  insertEmployeeSchema: () => insertEmployeeSchema,
  insertOrganizationSchema: () => insertOrganizationSchema,
  insertProjectEmployeeSchema: () => insertProjectEmployeeSchema,
  insertProjectSchema: () => insertProjectSchema,
  insertTaskSchema: () => insertTaskSchema,
  insertTimeEntrySchema: () => insertTimeEntrySchema,
  organizations: () => organizations,
  organizationsRelations: () => organizationsRelations,
  projectEmployees: () => projectEmployees,
  projectEmployeesRelations: () => projectEmployeesRelations,
  projects: () => projects,
  projectsRelations: () => projectsRelations,
  sessions: () => sessions,
  tasks: () => tasks,
  tasksRelations: () => tasksRelations,
  timeEntries: () => timeEntries,
  timeEntriesRelations: () => timeEntriesRelations,
  users: () => users,
  usersRelations: () => usersRelations
});
import { sql as sql2 } from "drizzle-orm";
import {
  index,
  jsonb,
  pgTable,
  timestamp,
  varchar,
  text,
  decimal,
  date,
  boolean
} from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";
import { relations } from "drizzle-orm";
var sessions, users, projects, tasks, timeEntries, usersRelations, projectsRelations, tasksRelations, timeEntriesRelations, insertProjectSchema, insertTaskSchema, insertTimeEntrySchema, employees, projectEmployees, employeesRelations, projectEmployeesRelations, insertEmployeeSchema, insertProjectEmployeeSchema, organizations, departments, organizationsRelations, departmentsRelations, insertOrganizationSchema, insertDepartmentSchema;
var init_schema = __esm({
  "shared/schema.ts"() {
    "use strict";
    sessions = pgTable(
      "sessions",
      {
        sid: varchar("sid").primaryKey(),
        sess: jsonb("sess").notNull(),
        expire: timestamp("expire").notNull()
      },
      (table) => [index("IDX_session_expire").on(table.expire)]
    );
    users = pgTable("users", {
      id: varchar("id").primaryKey().default(sql2`gen_random_uuid()`),
      email: varchar("email").unique(),
      firstName: varchar("first_name"),
      lastName: varchar("last_name"),
      profileImageUrl: varchar("profile_image_url"),
      role: varchar("role", { length: 50 }).default("employee"),
      // admin, manager, employee, viewer
      isActive: boolean("is_active").default(true),
      lastLoginAt: timestamp("last_login_at"),
      createdAt: timestamp("created_at").defaultNow(),
      updatedAt: timestamp("updated_at").defaultNow()
    });
    projects = pgTable("projects", {
      id: varchar("id").primaryKey().default(sql2`gen_random_uuid()`),
      name: varchar("name", { length: 255 }).notNull(),
      projectNumber: varchar("project_number", { length: 50 }),
      // Optional alphanumeric project number
      description: text("description"),
      color: varchar("color", { length: 7 }).default("#1976D2"),
      // Hex color code
      startDate: timestamp("start_date"),
      endDate: timestamp("end_date"),
      isEnterpriseWide: boolean("is_enterprise_wide").default(true).notNull(),
      // true = enterprise-wide, false = restricted
      userId: varchar("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
      createdAt: timestamp("created_at").defaultNow(),
      updatedAt: timestamp("updated_at").defaultNow()
    });
    tasks = pgTable("tasks", {
      id: varchar("id").primaryKey().default(sql2`gen_random_uuid()`),
      projectId: varchar("project_id").notNull().references(() => projects.id, { onDelete: "cascade" }),
      name: varchar("name", { length: 255 }).notNull(),
      description: text("description"),
      status: varchar("status", { length: 50 }).notNull().default("active"),
      // active, completed, archived
      createdAt: timestamp("created_at").defaultNow(),
      updatedAt: timestamp("updated_at").defaultNow()
    });
    timeEntries = pgTable("time_entries", {
      id: varchar("id").primaryKey().default(sql2`gen_random_uuid()`),
      userId: varchar("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
      projectId: varchar("project_id").notNull().references(() => projects.id, { onDelete: "cascade" }),
      taskId: varchar("task_id").references(() => tasks.id, { onDelete: "set null" }),
      description: text("description"),
      date: date("date").notNull(),
      startTime: varchar("start_time", { length: 5 }).notNull(),
      // HH:MM format
      endTime: varchar("end_time", { length: 5 }).notNull(),
      // HH:MM format
      duration: decimal("duration", { precision: 5, scale: 2 }).notNull(),
      // Hours with 2 decimal places
      createdAt: timestamp("created_at").defaultNow(),
      updatedAt: timestamp("updated_at").defaultNow()
    });
    usersRelations = relations(users, ({ many }) => ({
      projects: many(projects),
      timeEntries: many(timeEntries)
    }));
    projectsRelations = relations(projects, ({ one, many }) => ({
      user: one(users, {
        fields: [projects.userId],
        references: [users.id]
      }),
      timeEntries: many(timeEntries),
      tasks: many(tasks),
      projectEmployees: many(projectEmployees)
    }));
    tasksRelations = relations(tasks, ({ one, many }) => ({
      project: one(projects, {
        fields: [tasks.projectId],
        references: [projects.id]
      }),
      timeEntries: many(timeEntries)
    }));
    timeEntriesRelations = relations(timeEntries, ({ one }) => ({
      user: one(users, {
        fields: [timeEntries.userId],
        references: [users.id]
      }),
      project: one(projects, {
        fields: [timeEntries.projectId],
        references: [projects.id]
      }),
      task: one(tasks, {
        fields: [timeEntries.taskId],
        references: [tasks.id]
      })
    }));
    insertProjectSchema = createInsertSchema(projects).omit({
      id: true,
      createdAt: true,
      updatedAt: true
    }).extend({
      startDate: z.coerce.date().optional(),
      endDate: z.coerce.date().optional()
    });
    insertTaskSchema = createInsertSchema(tasks).omit({
      id: true,
      createdAt: true,
      updatedAt: true
    });
    insertTimeEntrySchema = createInsertSchema(timeEntries).omit({
      id: true,
      createdAt: true,
      updatedAt: true
    }).extend({
      taskId: z.string().optional()
    });
    employees = pgTable("employees", {
      id: varchar("id").primaryKey().default(sql2`gen_random_uuid()`),
      employeeId: varchar("employee_id").notNull().unique(),
      firstName: varchar("first_name").notNull(),
      lastName: varchar("last_name").notNull(),
      department: varchar("department").notNull(),
      userId: varchar("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
      createdAt: timestamp("created_at").defaultNow(),
      updatedAt: timestamp("updated_at").defaultNow()
    });
    projectEmployees = pgTable("project_employees", {
      id: varchar("id").primaryKey().default(sql2`gen_random_uuid()`),
      projectId: varchar("project_id").notNull().references(() => projects.id, { onDelete: "cascade" }),
      employeeId: varchar("employee_id").notNull().references(() => employees.id, { onDelete: "cascade" }),
      userId: varchar("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
      createdAt: timestamp("created_at").defaultNow()
    });
    employeesRelations = relations(employees, ({ one, many }) => ({
      user: one(users, {
        fields: [employees.userId],
        references: [users.id]
      }),
      projectEmployees: many(projectEmployees),
      managedDepartments: many(departments)
    }));
    projectEmployeesRelations = relations(projectEmployees, ({ one }) => ({
      project: one(projects, {
        fields: [projectEmployees.projectId],
        references: [projects.id]
      }),
      employee: one(employees, {
        fields: [projectEmployees.employeeId],
        references: [employees.id]
      }),
      user: one(users, {
        fields: [projectEmployees.userId],
        references: [users.id]
      })
    }));
    insertEmployeeSchema = createInsertSchema(employees).omit({
      id: true,
      createdAt: true,
      updatedAt: true
    });
    insertProjectEmployeeSchema = createInsertSchema(projectEmployees).omit({
      id: true,
      createdAt: true
    });
    organizations = pgTable("organizations", {
      id: varchar("id").primaryKey().default(sql2`gen_random_uuid()`),
      name: varchar("name").notNull(),
      description: text("description"),
      userId: varchar("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
      createdAt: timestamp("created_at").defaultNow(),
      updatedAt: timestamp("updated_at").defaultNow()
    });
    departments = pgTable("departments", {
      id: varchar("id").primaryKey().default(sql2`gen_random_uuid()`),
      name: varchar("name").notNull(),
      organizationId: varchar("organization_id").notNull().references(() => organizations.id, { onDelete: "cascade" }),
      managerId: varchar("manager_id").references(() => employees.id),
      description: varchar("description"),
      userId: varchar("user_id").notNull().references(() => users.id, { onDelete: "cascade" }),
      createdAt: timestamp("created_at").defaultNow(),
      updatedAt: timestamp("updated_at").defaultNow()
    });
    organizationsRelations = relations(organizations, ({ one, many }) => ({
      user: one(users, {
        fields: [organizations.userId],
        references: [users.id]
      }),
      departments: many(departments)
    }));
    departmentsRelations = relations(departments, ({ one }) => ({
      organization: one(organizations, {
        fields: [departments.organizationId],
        references: [organizations.id]
      }),
      manager: one(employees, {
        fields: [departments.managerId],
        references: [employees.id]
      }),
      user: one(users, {
        fields: [departments.userId],
        references: [users.id]
      })
    }));
    insertOrganizationSchema = createInsertSchema(organizations).omit({
      id: true,
      createdAt: true,
      updatedAt: true
    });
    insertDepartmentSchema = createInsertSchema(departments).omit({
      id: true,
      createdAt: true,
      updatedAt: true
    });
  }
});

// server/db.ts
import { Pool, neonConfig } from "@neondatabase/serverless";
import { drizzle } from "drizzle-orm/neon-serverless";
import ws from "ws";
async function withDatabaseRetry(operation, maxRetries = 3) {
  let lastError;
  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      return await operation();
    } catch (error) {
      lastError = error;
      console.error(`\u{1F7E1} [DATABASE] Operation failed (attempt ${attempt}/${maxRetries}):`, error);
      if (error instanceof Error && (error.message.includes("authentication") || error.message.includes("permission"))) {
        throw error;
      }
      if (attempt < maxRetries) {
        await new Promise((resolve) => setTimeout(resolve, 1e3 * attempt));
      }
    }
  }
  throw lastError;
}
var databaseUrl, pool, db;
var init_db = __esm({
  "server/db.ts"() {
    "use strict";
    init_schema();
    neonConfig.webSocketConstructor = ws;
    databaseUrl = process.env.DATABASE_URL || process.env.REPLIT_DB_URL || "postgresql://neondb_owner:password@localhost:5432/neondb";
    if (!databaseUrl) {
      throw new Error(
        "DATABASE_URL must be set. Did you forget to provision a database?"
      );
    }
    pool = new Pool({
      connectionString: databaseUrl,
      max: 20,
      // Maximum connections
      idleTimeoutMillis: 3e4,
      // 30 seconds idle timeout
      connectionTimeoutMillis: 5e3
      // 5 seconds connection timeout
    });
    pool.on("error", (err) => {
      console.error("\u{1F534} [DATABASE] Unexpected database pool error:", err);
    });
    db = drizzle({ client: pool, schema: schema_exports });
  }
});

// server/storage.ts
import { eq, and, or, desc, asc, gte, lte, sql as sql3, notInArray } from "drizzle-orm";
function storageLog(operation, message, data) {
  const timestamp2 = (/* @__PURE__ */ new Date()).toISOString();
  const logMessage = `${timestamp2} \u{1F5C4}\uFE0F [STORAGE] ${operation}: ${message}`;
  if (data) {
    console.log(logMessage, typeof data === "object" ? JSON.stringify(data, null, 2) : data);
  } else {
    console.log(logMessage);
  }
}
var DatabaseStorage, storage;
var init_storage = __esm({
  "server/storage.ts"() {
    "use strict";
    init_schema();
    init_db();
    DatabaseStorage = class {
      // User operations
      // (IMPORTANT) these user operations are mandatory for Replit Auth.
      async getUser(id) {
        try {
          storageLog("GET_USER", `Fetching user with id: ${id}`);
          const [user] = await db.select().from(users).where(eq(users.id, id));
          storageLog("GET_USER", `Found user: ${user ? user.email : "not found"}`);
          return user;
        } catch (error) {
          storageLog("GET_USER", `Error fetching user ${id}:`, error);
          throw error;
        }
      }
      async upsertUser(userData) {
        try {
          storageLog("UPSERT_USER", `Upserting user: ${userData.email} (${userData.id})`);
          const [user] = await db.insert(users).values({
            ...userData,
            lastLoginAt: /* @__PURE__ */ new Date()
          }).onConflictDoUpdate({
            target: users.id,
            set: {
              ...userData,
              lastLoginAt: /* @__PURE__ */ new Date(),
              updatedAt: /* @__PURE__ */ new Date()
            }
          }).returning();
          storageLog("UPSERT_USER", `Successfully upserted user ${user.email}`, {
            userId: user.id,
            email: user.email,
            role: user.role,
            isNewUser: !userData.id
          });
          return user;
        } catch (error) {
          storageLog("UPSERT_USER", `Failed to upsert user ${userData.email}:`, {
            userData,
            error: error instanceof Error ? {
              message: error.message,
              stack: error.stack
            } : error
          });
          throw error;
        }
      }
      async getAllUsers() {
        return await db.select().from(users).orderBy(asc(users.createdAt));
      }
      async getUsersWithoutEmployeeProfile() {
        const usersWithEmployees = await db.select({ userId: employees.userId }).from(employees).where(sql3`${employees.userId} IS NOT NULL`);
        const userIdsWithEmployees = usersWithEmployees.map((row) => row.userId).filter((id) => id !== null);
        if (userIdsWithEmployees.length === 0) {
          return await this.getAllUsers();
        }
        return await db.select().from(users).where(notInArray(users.id, userIdsWithEmployees)).orderBy(asc(users.createdAt));
      }
      async getEmployeeByUserId(userId) {
        const [employee] = await db.select().from(employees).where(eq(employees.userId, userId));
        return employee;
      }
      async updateUserRole(userId, role) {
        storageLog("UPDATE_USER_ROLE", `Updating role for user ${userId} to ${role}`);
        try {
          const [user] = await db.update(users).set({
            role,
            updatedAt: /* @__PURE__ */ new Date()
          }).where(eq(users.id, userId)).returning();
          storageLog("UPDATE_USER_ROLE", `Successfully updated role for ${user?.email}`, {
            userId,
            newRole: role,
            userEmail: user?.email
          });
          return user;
        } catch (error) {
          storageLog("UPDATE_USER_ROLE", `Failed to update role for user ${userId}:`, {
            userId,
            role,
            error: error instanceof Error ? {
              message: error.message,
              stack: error.stack
            } : error
          });
          throw error;
        }
      }
      async deactivateUser(userId) {
        const [user] = await db.update(users).set({
          isActive: false,
          updatedAt: /* @__PURE__ */ new Date()
        }).where(eq(users.id, userId)).returning();
        return user;
      }
      async createTestUsers() {
        const testUsersData = [
          {
            id: "test-admin-001",
            email: "admin@timetracker.test",
            firstName: "Admin",
            lastName: "User",
            role: "admin",
            profileImageUrl: null
          },
          {
            id: "test-manager-001",
            email: "manager@timetracker.test",
            firstName: "Department",
            lastName: "Manager",
            role: "manager",
            profileImageUrl: null
          },
          {
            id: "test-pm-001",
            email: "pm@timetracker.test",
            firstName: "Project",
            lastName: "Manager",
            role: "project_manager",
            profileImageUrl: null
          },
          {
            id: "test-employee-001",
            email: "employee@timetracker.test",
            firstName: "Regular",
            lastName: "Employee",
            role: "employee",
            profileImageUrl: null
          },
          {
            id: "test-viewer-001",
            email: "viewer@timetracker.test",
            firstName: "Viewer",
            lastName: "User",
            role: "viewer",
            profileImageUrl: null
          }
        ];
        const createdUsers = [];
        for (const userData of testUsersData) {
          try {
            const [user] = await db.insert(users).values(userData).onConflictDoUpdate({
              target: users.id,
              set: {
                ...userData,
                updatedAt: /* @__PURE__ */ new Date()
              }
            }).returning();
            createdUsers.push(user);
          } catch (error) {
            console.error(`Error creating test user ${userData.email}:`, error);
          }
        }
        return createdUsers;
      }
      async getTestUsers() {
        return await db.select().from(users).where(sql3`${users.email} LIKE '%timetracker.test'`);
      }
      // Project operations
      async getProjects() {
        return await withDatabaseRetry(async () => {
          return await db.select().from(projects).orderBy(asc(projects.name));
        });
      }
      async getEmployeeProjects(userId) {
        return await withDatabaseRetry(async () => {
          const enterpriseProjects = await db.select().from(projects).where(eq(projects.isEnterpriseWide, true)).orderBy(asc(projects.name));
          return enterpriseProjects;
        });
      }
      async getProject(id, userId) {
        return await withDatabaseRetry(async () => {
          const [project] = await db.select().from(projects).where(eq(projects.id, id));
          return project;
        });
      }
      async createProject(project, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("CREATE_PROJECT", `Creating project by user with role ${userRole}`);
          if (!["admin", "project_manager"].includes(userRole)) {
            throw new Error("Insufficient permissions to create projects");
          }
          const [newProject] = await db.insert(projects).values(project).returning();
          storageLog("CREATE_PROJECT", `Successfully created project: ${newProject.name}`);
          return newProject;
        });
      }
      async updateProject(id, project, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("UPDATE_PROJECT", `Updating project ${id} by user ${userId} with role ${userRole}`);
          if (!["admin", "project_manager"].includes(userRole)) {
            throw new Error("Insufficient permissions to update projects");
          }
          storageLog("UPDATE_PROJECT", `Role ${userRole} authorized - proceeding with update`);
          const [updatedProject] = await db.update(projects).set({ ...project, updatedAt: /* @__PURE__ */ new Date() }).where(eq(projects.id, id)).returning();
          if (updatedProject) {
            storageLog("UPDATE_PROJECT", `Successfully updated project: ${updatedProject.name}`);
          } else {
            storageLog("UPDATE_PROJECT", `Project ${id} not found`);
          }
          return updatedProject;
        });
      }
      async deleteProject(id, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("DELETE_PROJECT", `Deleting project by user with role ${userRole}`);
          if (!["admin", "project_manager"].includes(userRole)) {
            throw new Error("Insufficient permissions to delete projects");
          }
          const result = await db.delete(projects).where(eq(projects.id, id));
          const success = (result.rowCount ?? 0) > 0;
          if (success) {
            storageLog("DELETE_PROJECT", `Successfully deleted project ${id}`);
          } else {
            storageLog("DELETE_PROJECT", `Project ${id} not found or already deleted`);
          }
          return success;
        });
      }
      // Task operations
      async getTasks(projectId, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("GET_TASKS", `Getting tasks for project ${projectId} by user with role ${userRole}`);
          return await db.select().from(tasks).where(eq(tasks.projectId, projectId)).orderBy(asc(tasks.createdAt));
        });
      }
      async getTask(id, userId) {
        const [task] = await db.select({
          id: tasks.id,
          projectId: tasks.projectId,
          name: tasks.name,
          description: tasks.description,
          status: tasks.status,
          createdAt: tasks.createdAt,
          updatedAt: tasks.updatedAt
        }).from(tasks).where(eq(tasks.id, id));
        return task || void 0;
      }
      async createTask(task, userId) {
        return await withDatabaseRetry(async () => {
          if (userId) {
            const user = await this.getUser(userId);
            const userRole = user?.role || "employee";
            storageLog("CREATE_TASK", `Creating task by user with role ${userRole}`);
            if (!["admin", "project_manager"].includes(userRole)) {
              throw new Error("Insufficient permissions to create tasks");
            }
          }
          const [newTask] = await db.insert(tasks).values(task).returning();
          storageLog("CREATE_TASK", `Successfully created task: ${newTask.name}`);
          return newTask;
        });
      }
      async updateTask(id, taskData, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("UPDATE_TASK", `Updating task ${id} by user with role ${userRole}`);
          if (!["admin", "project_manager"].includes(userRole)) {
            throw new Error("Insufficient permissions to update tasks");
          }
          const existingTask = await this.getTask(id, userId);
          if (!existingTask) {
            return void 0;
          }
          const [updatedTask] = await db.update(tasks).set({ ...taskData, updatedAt: /* @__PURE__ */ new Date() }).where(eq(tasks.id, id)).returning();
          if (updatedTask) {
            storageLog("UPDATE_TASK", `Successfully updated task: ${updatedTask.name}`);
          }
          return updatedTask || void 0;
        });
      }
      async deleteTask(id, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("DELETE_TASK", `Deleting task ${id} by user with role ${userRole}`);
          if (!["admin", "project_manager"].includes(userRole)) {
            throw new Error("Insufficient permissions to delete tasks");
          }
          const existingTask = await this.getTask(id, userId);
          if (!existingTask) {
            return false;
          }
          const result = await db.delete(tasks).where(eq(tasks.id, id)).returning();
          const success = result.length > 0;
          if (success) {
            storageLog("DELETE_TASK", `Successfully deleted task ${id}`);
          }
          return success;
        });
      }
      async getAllUserTasks(userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("GET_ALL_TASKS", `Getting all tasks for user with role ${userRole}`);
          let whereCondition;
          if (["admin", "project_manager"].includes(userRole)) {
            whereCondition = void 0;
            storageLog("GET_ALL_TASKS", `${userRole} role - showing all tasks`);
          } else {
            whereCondition = eq(projects.isEnterpriseWide, true);
            storageLog("GET_ALL_TASKS", `${userRole} role - showing enterprise-wide project tasks only`);
          }
          const results = await db.select({
            id: tasks.id,
            projectId: tasks.projectId,
            name: tasks.name,
            description: tasks.description,
            status: tasks.status,
            createdAt: tasks.createdAt,
            updatedAt: tasks.updatedAt,
            project: projects
          }).from(tasks).innerJoin(projects, eq(tasks.projectId, projects.id)).where(whereCondition).orderBy(desc(tasks.createdAt));
          return results.map((row) => ({
            ...row,
            project: row.project
          }));
        });
      }
      // Time entry operations
      async getTimeEntries(userId, filters) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("GET_TIME_ENTRIES", `Getting time entries for user with role ${userRole}`);
          let whereConditions = [];
          if (userRole === "admin") {
            storageLog("GET_TIME_ENTRIES", "Admin role - showing all time entries");
          } else if (userRole === "project_manager") {
            storageLog("GET_TIME_ENTRIES", "Project Manager role - showing all time entries");
          } else {
            whereConditions.push(eq(timeEntries.userId, userId));
            storageLog("GET_TIME_ENTRIES", `${userRole} role - showing own time entries only`);
          }
          if (filters?.projectId) {
            whereConditions.push(eq(timeEntries.projectId, filters.projectId));
          }
          if (filters?.taskId) {
            whereConditions.push(eq(timeEntries.taskId, filters.taskId));
          }
          if (filters?.startDate) {
            whereConditions.push(gte(timeEntries.date, filters.startDate));
          }
          if (filters?.endDate) {
            whereConditions.push(lte(timeEntries.date, filters.endDate));
          }
          let query = db.select({
            id: timeEntries.id,
            userId: timeEntries.userId,
            projectId: timeEntries.projectId,
            taskId: timeEntries.taskId,
            description: timeEntries.description,
            date: timeEntries.date,
            startTime: timeEntries.startTime,
            endTime: timeEntries.endTime,
            duration: timeEntries.duration,
            createdAt: timeEntries.createdAt,
            updatedAt: timeEntries.updatedAt,
            project: projects,
            task: tasks
          }).from(timeEntries).innerJoin(projects, eq(timeEntries.projectId, projects.id)).leftJoin(tasks, eq(timeEntries.taskId, tasks.id)).where(whereConditions.length > 0 ? and(...whereConditions) : void 0).orderBy(desc(timeEntries.date), desc(timeEntries.startTime));
          if (filters?.limit) {
            query = query.limit(filters.limit);
          }
          if (filters?.offset) {
            query = query.offset(filters.offset);
          }
          const results = await query;
          return results.map((row) => ({
            ...row,
            taskId: row.taskId || null,
            project: row.project,
            task: row.task || null
          }));
        });
      }
      async getTimeEntry(id, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("GET_TIME_ENTRY", `Getting time entry ${id} for user with role ${userRole}`);
          let whereConditions = [eq(timeEntries.id, id)];
          if (!["admin", "project_manager"].includes(userRole)) {
            whereConditions.push(eq(timeEntries.userId, userId));
            storageLog("GET_TIME_ENTRY", `${userRole} role - restricting to own time entries`);
          } else {
            storageLog("GET_TIME_ENTRY", `${userRole} role - can view any time entry`);
          }
          const [result] = await db.select({
            id: timeEntries.id,
            userId: timeEntries.userId,
            projectId: timeEntries.projectId,
            taskId: timeEntries.taskId,
            description: timeEntries.description,
            date: timeEntries.date,
            startTime: timeEntries.startTime,
            endTime: timeEntries.endTime,
            duration: timeEntries.duration,
            createdAt: timeEntries.createdAt,
            updatedAt: timeEntries.updatedAt,
            project: projects,
            task: tasks
          }).from(timeEntries).innerJoin(projects, eq(timeEntries.projectId, projects.id)).leftJoin(tasks, eq(timeEntries.taskId, tasks.id)).where(and(...whereConditions));
          if (!result) return void 0;
          return {
            ...result,
            taskId: result.taskId || null,
            project: result.project,
            task: result.task || null
          };
        });
      }
      async createTimeEntry(entry) {
        return await withDatabaseRetry(async () => {
          storageLog("CREATE_TIME_ENTRY", `Creating time entry for project ${entry.projectId}`);
          const [newEntry] = await db.insert(timeEntries).values(entry).returning();
          storageLog("CREATE_TIME_ENTRY", `Successfully created time entry ${newEntry.id}`);
          return newEntry;
        });
      }
      async updateTimeEntry(id, entry, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("UPDATE_TIME_ENTRY", `Updating time entry ${id} by user with role ${userRole}`);
          let whereConditions = [eq(timeEntries.id, id)];
          if (!["admin", "project_manager"].includes(userRole)) {
            whereConditions.push(eq(timeEntries.userId, userId));
            storageLog("UPDATE_TIME_ENTRY", `${userRole} role - restricting to own time entries`);
          } else {
            storageLog("UPDATE_TIME_ENTRY", `${userRole} role - can update any time entry`);
          }
          const [updatedEntry] = await db.update(timeEntries).set({ ...entry, updatedAt: /* @__PURE__ */ new Date() }).where(and(...whereConditions)).returning();
          if (updatedEntry) {
            storageLog("UPDATE_TIME_ENTRY", `Successfully updated time entry ${updatedEntry.id}`);
          }
          return updatedEntry;
        });
      }
      async deleteTimeEntry(id, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("DELETE_TIME_ENTRY", `Deleting time entry ${id} by user with role ${userRole}`);
          let whereConditions = [eq(timeEntries.id, id)];
          if (!["admin", "project_manager"].includes(userRole)) {
            whereConditions.push(eq(timeEntries.userId, userId));
            storageLog("DELETE_TIME_ENTRY", `${userRole} role - restricting to own time entries`);
          } else {
            storageLog("DELETE_TIME_ENTRY", `${userRole} role - can delete any time entry`);
          }
          const result = await db.delete(timeEntries).where(and(...whereConditions));
          const success = (result.rowCount ?? 0) > 0;
          if (success) {
            storageLog("DELETE_TIME_ENTRY", `Successfully deleted time entry ${id}`);
          }
          return success;
        });
      }
      // Dashboard stats
      async getDashboardStats(userId, startDate, endDate) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("GET_DASHBOARD_STATS", `Getting dashboard stats for user with role ${userRole}`);
          const now = /* @__PURE__ */ new Date();
          const todayPST = now.toLocaleDateString("en-CA", { timeZone: "America/Los_Angeles" });
          const start = startDate || new Date(Date.now() - 7 * 24 * 60 * 60 * 1e3).toLocaleDateString("en-CA", { timeZone: "America/Los_Angeles" });
          const end = endDate || todayPST;
          console.log(`\u{1F4CA} Dashboard Stats Debug - userId: ${userId}, role: ${userRole}`);
          console.log(`\u{1F4C5} Date Info PST: today: ${todayPST}, start: ${start}, end: ${end}`);
          const todayToUse = todayPST;
          let userFilter;
          if (["admin", "project_manager"].includes(userRole)) {
            userFilter = void 0;
            storageLog("GET_DASHBOARD_STATS", `${userRole} role - showing organization-wide stats`);
          } else {
            userFilter = eq(timeEntries.userId, userId);
            storageLog("GET_DASHBOARD_STATS", `${userRole} role - showing personal stats only`);
          }
          const [todayResult] = await db.select({ total: sql3`COALESCE(SUM(${timeEntries.duration}), 0)` }).from(timeEntries).where(userFilter ? and(userFilter, eq(timeEntries.date, todayToUse)) : eq(timeEntries.date, todayToUse));
          console.log(`\u23F0 Today's Hours Query Result (${todayToUse}):`, todayResult);
          const todayEntries = await db.select().from(timeEntries).where(and(eq(timeEntries.userId, userId), eq(timeEntries.date, todayToUse)));
          console.log(`\u{1F4CB} Today's Time Entries (${todayEntries.length}):`, todayEntries);
          const recentEntries = await db.select().from(timeEntries).where(userFilter).orderBy(sql3`${timeEntries.date} DESC`).limit(5);
          console.log(`\u{1F4CB} Recent 5 Time Entries (role: ${userRole}):`, recentEntries);
          const [weekResult] = await db.select({ total: sql3`COALESCE(SUM(${timeEntries.duration}), 0)` }).from(timeEntries).where(
            userFilter ? and(userFilter, gte(timeEntries.date, start), lte(timeEntries.date, end)) : and(gte(timeEntries.date, start), lte(timeEntries.date, end))
          );
          const monthStart = new Date(now.getFullYear(), now.getMonth(), 1).toLocaleDateString("en-CA", { timeZone: "America/Los_Angeles" });
          const [monthResult] = await db.select({ total: sql3`COALESCE(SUM(${timeEntries.duration}), 0)` }).from(timeEntries).where(
            userFilter ? and(userFilter, gte(timeEntries.date, monthStart), lte(timeEntries.date, todayToUse)) : and(gte(timeEntries.date, monthStart), lte(timeEntries.date, todayToUse))
          );
          const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1e3).toLocaleDateString("en-CA", { timeZone: "America/Los_Angeles" });
          const activeProjects = await db.select({ projectId: timeEntries.projectId }).from(timeEntries).where(
            userFilter ? and(userFilter, gte(timeEntries.date, thirtyDaysAgo)) : gte(timeEntries.date, thirtyDaysAgo)
          ).groupBy(timeEntries.projectId);
          const stats = {
            todayHours: parseFloat(todayResult?.total?.toString() || "0"),
            weekHours: parseFloat(weekResult?.total?.toString() || "0"),
            monthHours: parseFloat(monthResult?.total?.toString() || "0"),
            activeProjects: activeProjects.length
          };
          console.log(`\u{1F4CA} Final Dashboard Stats:`, stats);
          return stats;
        });
      }
      async getProjectTimeBreakdown(userId, startDate, endDate) {
        const user = await this.getUser(userId);
        const userRole = user?.role || "employee";
        let projectConditions = [];
        let timeEntryConditions = [];
        if (userRole === "admin") {
        } else if (userRole === "project_manager") {
          projectConditions.push(or(
            eq(projects.isEnterpriseWide, true),
            eq(projects.userId, userId)
          ));
        } else if (userRole === "manager") {
          projectConditions.push(eq(projects.isEnterpriseWide, true));
        } else {
          projectConditions.push(eq(projects.isEnterpriseWide, true));
        }
        if (startDate) {
          timeEntryConditions.push(gte(timeEntries.date, startDate));
        }
        if (endDate) {
          timeEntryConditions.push(lte(timeEntries.date, endDate));
        }
        let whereConditions = [];
        if (projectConditions.length > 0) {
          whereConditions.push(...projectConditions);
        }
        if (timeEntryConditions.length > 0) {
          whereConditions.push(...timeEntryConditions);
        }
        console.log(`\u{1F4CA} Project Breakdown - userId: ${userId}, role: ${userRole}, conditions: ${whereConditions.length}`);
        console.log(`\u{1F4CA} Conditions array:`, whereConditions);
        try {
          const results = await db.select({
            project: projects,
            totalHours: sql3`COALESCE(SUM(CAST(${timeEntries.duration} AS DECIMAL)), 0)`
          }).from(projects).leftJoin(timeEntries, eq(projects.id, timeEntries.projectId)).where(whereConditions.length > 0 ? and(...whereConditions) : void 0).groupBy(projects.id).orderBy(desc(sql3`SUM(CAST(${timeEntries.duration} AS DECIMAL))`));
          console.log(`\u{1F4CA} Project breakdown found ${results.length} projects`);
          const totalHours = results.reduce((sum, row) => sum + Number(row.totalHours), 0);
          return results.filter((row) => Number(row.totalHours) > 0).map((row) => ({
            project: row.project,
            totalHours: Number(row.totalHours),
            percentage: totalHours > 0 ? Math.round(Number(row.totalHours) / totalHours * 100) : 0
          }));
        } catch (error) {
          console.error(`\u{1F4CA} Error in getProjectTimeBreakdown:`, error);
          return [];
        }
      }
      async getRecentActivity(userId, limit = 10, startDate, endDate) {
        return this.getTimeEntries(userId, {
          limit,
          startDate: startDate || void 0,
          endDate: endDate || void 0
        });
      }
      async getProjectTaskBreakdown(userId, startDate, endDate) {
        return [];
      }
      // Employee operations
      async getEmployees(userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("GET_EMPLOYEES", `Getting employees for user with role ${userRole}`);
          let whereCondition;
          if (userRole === "admin") {
            whereCondition = void 0;
            storageLog("GET_EMPLOYEES", "Admin role - showing all employees");
          } else {
            whereCondition = void 0;
            storageLog("GET_EMPLOYEES", `${userRole} role - showing all employees for project management`);
          }
          return await db.select().from(employees).where(whereCondition).orderBy(asc(employees.firstName), asc(employees.lastName));
        });
      }
      async getEmployee(id, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("GET_EMPLOYEE", `Getting employee ${id} for user with role ${userRole}`);
          let whereConditions = [eq(employees.id, id)];
          if (!["admin", "manager"].includes(userRole)) {
            storageLog("GET_EMPLOYEE", `${userRole} role - allowing employee access for project management`);
          } else {
            storageLog("GET_EMPLOYEE", `${userRole} role - full employee access`);
          }
          const [employee] = await db.select().from(employees).where(and(...whereConditions));
          return employee;
        });
      }
      async createEmployee(employee) {
        const [newEmployee] = await db.insert(employees).values(employee).returning();
        return newEmployee;
      }
      async updateEmployee(id, employeeData, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("UPDATE_EMPLOYEE", `Updating employee ${id} by user with role ${userRole}`);
          if (!["admin", "manager"].includes(userRole)) {
            throw new Error("Insufficient permissions to update employee information");
          }
          const [updatedEmployee] = await db.update(employees).set({ ...employeeData, updatedAt: /* @__PURE__ */ new Date() }).where(eq(employees.id, id)).returning();
          if (updatedEmployee) {
            storageLog("UPDATE_EMPLOYEE", `Successfully updated employee: ${updatedEmployee.firstName} ${updatedEmployee.lastName}`);
          }
          return updatedEmployee;
        });
      }
      async deleteEmployee(id, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("DELETE_EMPLOYEE", `Deleting employee ${id} by user with role ${userRole}`);
          if (userRole !== "admin") {
            throw new Error("Insufficient permissions to delete employees");
          }
          const result = await db.delete(employees).where(eq(employees.id, id));
          const success = (result.rowCount ?? 0) > 0;
          if (success) {
            storageLog("DELETE_EMPLOYEE", `Successfully deleted employee ${id}`);
          }
          return success;
        });
      }
      async linkUserToEmployee(userId, employeeId) {
        const [updatedEmployee] = await db.update(employees).set({ userId, updatedAt: /* @__PURE__ */ new Date() }).where(eq(employees.id, employeeId)).returning();
        return updatedEmployee;
      }
      // Project access control operations
      async getProjectWithEmployees(id, userId) {
        const project = await this.getProject(id, userId);
        if (!project) return void 0;
        if (project.isEnterpriseWide) {
          return { ...project, assignedEmployees: [] };
        }
        const assignedEmployees = await db.select({
          id: employees.id,
          employeeId: employees.employeeId,
          firstName: employees.firstName,
          lastName: employees.lastName,
          department: employees.department,
          userId: employees.userId,
          createdAt: employees.createdAt,
          updatedAt: employees.updatedAt
        }).from(projectEmployees).innerJoin(employees, eq(projectEmployees.employeeId, employees.id)).where(and(
          eq(projectEmployees.projectId, id),
          eq(projectEmployees.userId, userId)
        ));
        return { ...project, assignedEmployees };
      }
      async assignEmployeesToProject(projectId, employeeIds, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("ASSIGN_EMPLOYEES", `Assigning employees to project ${projectId} by user ${userId} with role ${userRole}`);
          if (!["admin", "project_manager"].includes(userRole)) {
            throw new Error("Insufficient permissions to assign employees to projects");
          }
          const project = await db.select().from(projects).where(eq(projects.id, projectId)).limit(1);
          if (project.length === 0) {
            throw new Error("Project not found");
          }
          storageLog("ASSIGN_EMPLOYEES", `Role ${userRole} authorized - proceeding with assignment`);
          await db.delete(projectEmployees).where(eq(projectEmployees.projectId, projectId));
          if (employeeIds.length > 0) {
            await db.insert(projectEmployees).values(
              employeeIds.map((employeeId) => ({
                projectId,
                employeeId,
                userId
                // For audit trail only
              }))
            );
            storageLog("ASSIGN_EMPLOYEES", `Successfully assigned ${employeeIds.length} employees to project`);
          } else {
            storageLog("ASSIGN_EMPLOYEES", `Cleared all employee assignments for project`);
          }
        });
      }
      async getProjectEmployees(projectId, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("GET_PROJECT_EMPLOYEES", `Fetching project employees for user with role ${userRole}`);
          if (!["admin", "project_manager"].includes(userRole)) {
            throw new Error("Insufficient permissions to view project employee assignments");
          }
          const result = await db.select({
            id: employees.id,
            employeeId: employees.employeeId,
            firstName: employees.firstName,
            lastName: employees.lastName,
            department: employees.department,
            userId: employees.userId,
            createdAt: employees.createdAt,
            updatedAt: employees.updatedAt
          }).from(projectEmployees).innerJoin(employees, eq(projectEmployees.employeeId, employees.id)).where(eq(projectEmployees.projectId, projectId));
          storageLog("GET_PROJECT_EMPLOYEES", `Retrieved ${result.length} assigned employees`);
          return result;
        });
      }
      async removeEmployeeFromProject(projectId, employeeId, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("REMOVE_EMPLOYEE", `Removing employee from project by user with role ${userRole}`);
          if (!["admin", "project_manager"].includes(userRole)) {
            throw new Error("Insufficient permissions to remove employees from projects");
          }
          const result = await db.delete(projectEmployees).where(and(
            eq(projectEmployees.projectId, projectId),
            eq(projectEmployees.employeeId, employeeId)
          )).returning();
          const success = result.length > 0;
          if (success) {
            storageLog("REMOVE_EMPLOYEE", `Successfully removed employee ${employeeId} from project ${projectId}`);
          } else {
            storageLog("REMOVE_EMPLOYEE", `No employee assignment found to remove`);
          }
          return success;
        });
      }
      // Department operations
      async getDepartments() {
        const result = await db.select({
          id: departments.id,
          name: departments.name,
          organizationId: departments.organizationId,
          managerId: departments.managerId,
          description: departments.description,
          userId: departments.userId,
          createdAt: departments.createdAt,
          updatedAt: departments.updatedAt,
          manager: {
            id: employees.id,
            employeeId: employees.employeeId,
            firstName: employees.firstName,
            lastName: employees.lastName,
            department: employees.department,
            userId: employees.userId,
            createdAt: employees.createdAt,
            updatedAt: employees.updatedAt
          },
          organization: {
            id: organizations.id,
            name: organizations.name,
            description: organizations.description,
            userId: organizations.userId,
            createdAt: organizations.createdAt,
            updatedAt: organizations.updatedAt
          }
        }).from(departments).leftJoin(employees, eq(departments.managerId, employees.id)).leftJoin(organizations, eq(departments.organizationId, organizations.id)).orderBy(asc(departments.name));
        return result.map((row) => ({
          ...row,
          manager: row.manager && row.manager.id ? row.manager : null,
          organization: row.organization || null
        }));
      }
      async getDepartment(id) {
        const [result] = await db.select({
          id: departments.id,
          name: departments.name,
          organizationId: departments.organizationId,
          managerId: departments.managerId,
          description: departments.description,
          userId: departments.userId,
          createdAt: departments.createdAt,
          updatedAt: departments.updatedAt,
          manager: {
            id: employees.id,
            employeeId: employees.employeeId,
            firstName: employees.firstName,
            lastName: employees.lastName,
            department: employees.department,
            userId: employees.userId,
            createdAt: employees.createdAt,
            updatedAt: employees.updatedAt
          },
          organization: {
            id: organizations.id,
            name: organizations.name,
            description: organizations.description,
            userId: organizations.userId,
            createdAt: organizations.createdAt,
            updatedAt: organizations.updatedAt
          }
        }).from(departments).leftJoin(employees, eq(departments.managerId, employees.id)).leftJoin(organizations, eq(departments.organizationId, organizations.id)).where(eq(departments.id, id));
        if (!result) return void 0;
        return {
          ...result,
          manager: result.manager && result.manager.id ? result.manager : null,
          organization: result.organization || null
        };
      }
      async createDepartment(department) {
        const [newDepartment] = await db.insert(departments).values(department).returning();
        return newDepartment;
      }
      async updateDepartment(id, department, userId) {
        const [updatedDepartment] = await db.update(departments).set({ ...department, updatedAt: /* @__PURE__ */ new Date() }).where(eq(departments.id, id)).returning();
        return updatedDepartment;
      }
      async deleteDepartment(id, userId) {
        const result = await db.delete(departments).where(eq(departments.id, id));
        return (result.rowCount || 0) > 0;
      }
      async assignManagerToDepartment(departmentId, managerId, userId) {
        await db.update(departments).set({ managerId, updatedAt: /* @__PURE__ */ new Date() }).where(eq(departments.id, departmentId));
      }
      // Organization operations
      async getOrganizations() {
        return await db.select().from(organizations).orderBy(asc(organizations.name));
      }
      async getOrganization(id) {
        const [org] = await db.select().from(organizations).where(eq(organizations.id, id));
        if (!org) return void 0;
        const deps = await this.getDepartmentsByOrganization(id);
        return {
          ...org,
          departments: deps
        };
      }
      async createOrganization(organization) {
        const [newOrganization] = await db.insert(organizations).values(organization).returning();
        return newOrganization;
      }
      async updateOrganization(id, organization, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("UPDATE_ORGANIZATION", `Updating organization ${id} by user with role ${userRole}`);
          if (userRole !== "admin") {
            throw new Error("Insufficient permissions to update organizations");
          }
          const [updatedOrganization] = await db.update(organizations).set({ ...organization, updatedAt: /* @__PURE__ */ new Date() }).where(eq(organizations.id, id)).returning();
          if (updatedOrganization) {
            storageLog("UPDATE_ORGANIZATION", `Successfully updated organization: ${updatedOrganization.name}`);
          }
          return updatedOrganization;
        });
      }
      async deleteOrganization(id, userId) {
        return await withDatabaseRetry(async () => {
          const user = await this.getUser(userId);
          const userRole = user?.role || "employee";
          storageLog("DELETE_ORGANIZATION", `Deleting organization ${id} by user with role ${userRole}`);
          if (userRole !== "admin") {
            throw new Error("Insufficient permissions to delete organizations");
          }
          const result = await db.delete(organizations).where(eq(organizations.id, id));
          const success = (result.rowCount || 0) > 0;
          if (success) {
            storageLog("DELETE_ORGANIZATION", `Successfully deleted organization ${id}`);
          }
          return success;
        });
      }
      async getDepartmentsByOrganization(organizationId) {
        const result = await db.select({
          id: departments.id,
          name: departments.name,
          organizationId: departments.organizationId,
          managerId: departments.managerId,
          description: departments.description,
          userId: departments.userId,
          createdAt: departments.createdAt,
          updatedAt: departments.updatedAt,
          manager: {
            id: employees.id,
            employeeId: employees.employeeId,
            firstName: employees.firstName,
            lastName: employees.lastName,
            department: employees.department,
            userId: employees.userId,
            createdAt: employees.createdAt,
            updatedAt: employees.updatedAt
          },
          organization: {
            id: organizations.id,
            name: organizations.name,
            description: organizations.description,
            userId: organizations.userId,
            createdAt: organizations.createdAt,
            updatedAt: organizations.updatedAt
          }
        }).from(departments).leftJoin(employees, eq(departments.managerId, employees.id)).leftJoin(organizations, eq(departments.organizationId, organizations.id)).where(eq(departments.organizationId, organizationId)).orderBy(asc(departments.name));
        return result.map((row) => ({
          ...row,
          manager: row.manager && row.manager.id ? row.manager : null,
          organization: row.organization || null
        }));
      }
      async getDepartmentHoursSummary(userId, startDate, endDate) {
        const user = await this.getUser(userId);
        const userRole = user?.role || "employee";
        const dateFilter = startDate && endDate ? and(
          gte(timeEntries.date, startDate),
          lte(timeEntries.date, endDate)
        ) : void 0;
        const result = await db.select({
          departmentId: sql3`${employees.department}`,
          departmentName: sql3`${employees.department}`,
          totalHours: sql3`COALESCE(SUM(CAST(${timeEntries.duration} AS DECIMAL)), 0)`,
          employeeCount: sql3`COUNT(DISTINCT ${employees.id})`
        }).from(employees).leftJoin(
          timeEntries,
          dateFilter ? and(
            eq(employees.userId, timeEntries.userId),
            dateFilter
          ) : eq(employees.userId, timeEntries.userId)
        ).where(
          userRole === "admin" ? void 0 : eq(employees.userId, userId)
        ).groupBy(employees.department).having(sql3`${employees.department} IS NOT NULL AND ${employees.department} != ''`).orderBy(sql3`SUM(CAST(${timeEntries.duration} AS DECIMAL)) DESC`);
        return result.filter((r) => r.departmentName && r.totalHours > 0);
      }
      // Reports operations
      async getTimeEntriesForProject(projectId) {
        const result = await db.select({
          id: timeEntries.id,
          duration: sql3`CAST(${timeEntries.duration} AS NUMERIC)`,
          description: timeEntries.description,
          date: timeEntries.date,
          createdAt: timeEntries.createdAt,
          userId: timeEntries.userId,
          taskId: timeEntries.taskId,
          employee: {
            id: users.id,
            firstName: users.firstName,
            lastName: users.lastName,
            email: users.email
          },
          task: {
            id: tasks.id,
            name: tasks.name,
            description: tasks.description,
            status: tasks.status
          }
        }).from(timeEntries).leftJoin(users, eq(timeEntries.userId, users.id)).leftJoin(tasks, eq(timeEntries.taskId, tasks.id)).where(eq(timeEntries.projectId, projectId)).orderBy(desc(timeEntries.date), desc(timeEntries.createdAt));
        return result;
      }
    };
    storage = new DatabaseStorage();
  }
});

// fmb-onprem/auth/fmb-saml-auth.ts
var fmb_saml_auth_exports = {};
__export(fmb_saml_auth_exports, {
  isAuthenticated: () => isAuthenticated,
  setupFmbSamlAuth: () => setupFmbSamlAuth
});
import session from "express-session";
import passport from "passport";
import { Strategy as SamlStrategy } from "passport-saml";
function authLog(level, message, data) {
  const timestamp2 = (/* @__PURE__ */ new Date()).toISOString();
  const emoji = level === "ERROR" ? "\u{1F534}" : level === "WARN" ? "\u{1F7E1}" : level === "INFO" ? "\u{1F535}" : "\u{1F7E2}";
  const logMessage = `${timestamp2} ${emoji} [FMB-SAML] ${message}`;
  if (data) {
    console.log(logMessage, typeof data === "object" ? JSON.stringify(data, null, 2) : data);
  } else {
    console.log(logMessage);
  }
}
async function setupFmbSamlAuth(app2) {
  authLog("INFO", "Initializing FMB SAML Authentication...");
  const config = loadFmbOnPremConfig();
  const sessionTtl = 7 * 24 * 60 * 60 * 1e3;
  app2.use(session({
    secret: config.app.sessionSecret,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      secure: false,
      // Set to true in production with HTTPS
      maxAge: sessionTtl,
      sameSite: "lax"
    },
    name: "fmb.timetracker.sid"
  }));
  app2.use(passport.initialize());
  app2.use(passport.session());
  const samlStrategy = new SamlStrategy(
    {
      entryPoint: config.saml.ssoUrl,
      issuer: config.saml.entityId,
      callbackUrl: config.saml.acsUrl,
      cert: config.saml.certificate,
      validateInResponseTo: false,
      disableRequestedAuthnContext: true
    },
    async (profile, done) => {
      try {
        authLog("INFO", "SAML authentication successful", {
          nameID: profile.nameID,
          email: profile.email || profile.nameID,
          firstName: profile.firstName,
          lastName: profile.lastName
        });
        const user = {
          id: profile.nameID,
          email: profile.email || profile.nameID,
          firstName: profile.firstName || "Unknown",
          lastName: profile.lastName || "User",
          profileImageUrl: null
        };
        const fmbStorage2 = getFmbStorage();
        await fmbStorage2.upsertUser(user);
        return done(null, user);
      } catch (error) {
        authLog("ERROR", "Error processing SAML profile:", error);
        return done(error);
      }
    }
  );
  passport.use(samlStrategy);
  passport.serializeUser((user, done) => {
    done(null, user.id);
  });
  passport.deserializeUser(async (id, done) => {
    try {
      const fmbStorage2 = getFmbStorage();
      const user = await fmbStorage2.getUser(id);
      done(null, user);
    } catch (error) {
      done(error);
    }
  });
  app2.get("/api/login", passport.authenticate("saml", {
    failureRedirect: "/login-error",
    failureFlash: true
  }));
  app2.post("/saml/acs", passport.authenticate("saml", {
    failureRedirect: "/login-error",
    successRedirect: "/"
  }));
  app2.get("/api/logout", (req, res) => {
    req.logout(() => {
      res.redirect("/");
    });
  });
  authLog("INFO", "FMB SAML Authentication configured successfully");
}
var isAuthenticated;
var init_fmb_saml_auth = __esm({
  "fmb-onprem/auth/fmb-saml-auth.ts"() {
    "use strict";
    init_fmb_database();
    init_fmb_env();
    isAuthenticated = async (req, res, next) => {
      try {
        authLog("DEBUG", `Authentication check for ${req.method} ${req.path}`, {
          ip: req.ip,
          userAgent: req.get("User-Agent"),
          sessionId: req.sessionID,
          hasSession: !!req.session,
          isAuthenticated: req.isAuthenticated ? req.isAuthenticated() : false
        });
        if (process.env.NODE_ENV === "development" && (!req.isAuthenticated() || !req.user)) {
          authLog("DEBUG", "Development mode: Creating test admin user");
          authLog("WARN", "SECURITY: Authentication bypass active - DO NOT USE IN PRODUCTION");
          const testUser = {
            id: "test-admin-user",
            email: "admin@test.com",
            firstName: "Test",
            lastName: "Admin",
            profileImageUrl: null
          };
          req.user = testUser;
          try {
            const fmbStorage2 = getFmbStorage();
            await fmbStorage2.upsertUser(testUser);
            const currentUser = await fmbStorage2.getUser("test-admin-user");
            const currentRole = currentUser?.role || "admin";
            if (!currentUser || !currentUser.role) {
              await fmbStorage2.updateUserRole("test-admin-user", "admin");
              authLog("INFO", "Test admin user authenticated successfully");
            } else {
              authLog("INFO", `Test user authenticated with current role: ${currentRole}`);
            }
          } catch (dbError) {
            authLog("ERROR", "Failed to setup test user:", dbError);
          }
          return next();
        }
        if (!req.isAuthenticated() || !req.user) {
          authLog("WARN", "Unauthorized access attempt", {
            path: req.path,
            method: req.method,
            ip: req.ip,
            userAgent: req.get("User-Agent"),
            sessionId: req.sessionID
          });
          return res.status(401).json({ message: "Unauthorized" });
        }
        const user = req.user;
        authLog("DEBUG", "User authenticated", {
          userId: user.id || "unknown",
          email: user.email || "unknown",
          sessionId: req.sessionID
        });
        authLog("DEBUG", "Authentication successful, proceeding to next middleware");
        return next();
      } catch (error) {
        authLog("ERROR", "Authentication middleware error:", {
          error: error instanceof Error ? {
            message: error.message,
            stack: error.stack,
            name: error.name
          } : error,
          request: {
            method: req.method,
            path: req.path,
            ip: req.ip,
            sessionId: req.sessionID
          }
        });
        return res.status(500).json({ message: "Internal server error" });
      }
    };
  }
});

// server/replitAuth.ts
var replitAuth_exports = {};
__export(replitAuth_exports, {
  getSession: () => getSession,
  isAuthenticated: () => isAuthenticated2,
  setupAuth: () => setupAuth
});
import * as client from "openid-client";
import { Strategy } from "openid-client/passport";
import passport2 from "passport";
import session2 from "express-session";
import memoize from "memoizee";
import connectPg from "connect-pg-simple";
function getSession() {
  const sessionTtl = 7 * 24 * 60 * 60 * 1e3;
  const isProduction = process.env.NODE_ENV === "production";
  if (!process.env.SESSION_SECRET) {
    throw new Error("SESSION_SECRET environment variable is required");
  }
  if (isProduction && process.env.SESSION_SECRET.length < 32) {
    console.warn("\u26A0\uFE0F  WARNING: SESSION_SECRET should be at least 32 characters for production security");
  }
  if (isProduction && !process.env.DATABASE_URL) {
    throw new Error("DATABASE_URL is required for production session store");
  }
  if (isProduction) {
    const pgStore = connectPg(session2);
    const sessionStore = new pgStore({
      conString: process.env.DATABASE_URL,
      createTableIfMissing: true,
      ttl: sessionTtl,
      tableName: "sessions"
    });
    return session2({
      secret: process.env.SESSION_SECRET,
      store: sessionStore,
      resave: false,
      saveUninitialized: false,
      cookie: {
        httpOnly: true,
        secure: true,
        maxAge: sessionTtl,
        sameSite: "lax"
      },
      name: "timetracker.sid"
    });
  } else {
    return session2({
      secret: process.env.SESSION_SECRET,
      resave: true,
      saveUninitialized: true,
      rolling: true,
      cookie: {
        httpOnly: false,
        secure: false,
        maxAge: sessionTtl,
        sameSite: "lax"
      },
      name: "timetracker.sid"
    });
  }
}
function updateUserSession(user, tokens) {
  user.claims = tokens.claims();
  user.access_token = tokens.access_token;
  user.refresh_token = tokens.refresh_token;
  user.expires_at = user.claims?.exp;
}
async function upsertUser(claims) {
  await storage.upsertUser({
    id: claims["sub"],
    email: claims["email"],
    firstName: claims["first_name"],
    lastName: claims["last_name"],
    profileImageUrl: claims["profile_image_url"]
  });
}
async function setupAuth(app2) {
  app2.set("trust proxy", 1);
  app2.use(getSession());
  app2.use(passport2.initialize());
  app2.use(passport2.session());
  const config = await getOidcConfig();
  const verify = async (tokens, verified) => {
    const user = {};
    updateUserSession(user, tokens);
    await upsertUser(tokens.claims());
    verified(null, user);
  };
  const domains = process.env.REPLIT_DOMAINS.split(",");
  console.log("\u{1F310} Configuring OAuth strategies for domains:", domains);
  for (const domain of domains) {
    console.log(`\u{1F527} Setting up strategy for domain: ${domain}`);
    console.log(`\u{1F517} Callback URL: https://${domain}/api/callback`);
    const strategy = new Strategy(
      {
        name: `replitauth:${domain}`,
        config,
        scope: "openid email profile offline_access",
        callbackURL: `https://${domain}/api/callback`
      },
      verify
    );
    passport2.use(strategy);
  }
  passport2.serializeUser((user, cb) => cb(null, user));
  passport2.deserializeUser((user, cb) => cb(null, user));
  app2.get("/api/login", (req, res, next) => {
    console.log("\u{1F510} Login attempt for hostname:", req.hostname);
    console.log("\u{1F510} Available domains:", process.env.REPLIT_DOMAINS);
    const configuredDomains = process.env.REPLIT_DOMAINS.split(",");
    const targetDomain = configuredDomains.includes(req.hostname) ? req.hostname : configuredDomains[0];
    const strategyName = `replitauth:${targetDomain}`;
    console.log("\u{1F510} Using domain:", targetDomain, "for strategy:", strategyName);
    passport2.authenticate(strategyName, {
      prompt: "login consent",
      scope: ["openid", "email", "profile", "offline_access"]
    })(req, res, next);
  });
  app2.get("/api/callback", (req, res, next) => {
    console.log("\u{1F517} OAuth callback for hostname:", req.hostname);
    console.log("\u{1F517} Full callback URL:", req.url);
    const configuredDomains = process.env.REPLIT_DOMAINS.split(",");
    const targetDomain = configuredDomains.includes(req.hostname) ? req.hostname : configuredDomains[0];
    console.log("\u{1F517} Using domain:", targetDomain, "for callback");
    passport2.authenticate(`replitauth:${targetDomain}`, (err, user, info) => {
      if (err) {
        console.error("\u274C OAuth callback error:", err);
        return res.redirect("/api/login?error=oauth_error");
      }
      if (!user) {
        console.error("\u274C OAuth callback failed - no user:", info);
        return res.redirect("/api/login?error=oauth_failed");
      }
      req.logIn(user, (loginErr) => {
        if (loginErr) {
          console.error("\u274C Login error:", loginErr);
          return res.redirect("/api/login?error=login_failed");
        }
        console.log("\u2705 OAuth callback successful, redirecting to /");
        return res.redirect("/");
      });
    })(req, res, next);
  });
  app2.get("/api/logout", (req, res) => {
    req.logout(() => {
      res.redirect(
        client.buildEndSessionUrl(config, {
          client_id: process.env.REPL_ID,
          post_logout_redirect_uri: `${req.protocol}://${req.hostname}`
        }).href
      );
    });
  });
}
function authLog2(level, message, data) {
  const timestamp2 = (/* @__PURE__ */ new Date()).toISOString();
  const emoji = level === "ERROR" ? "\u{1F534}" : level === "WARN" ? "\u{1F7E1}" : level === "INFO" ? "\u{1F535}" : "\u{1F7E2}";
  const logMessage = `${timestamp2} ${emoji} [AUTH] ${message}`;
  if (data) {
    console.log(logMessage, typeof data === "object" ? JSON.stringify(data, null, 2) : data);
  } else {
    console.log(logMessage);
  }
}
var getOidcConfig, isAuthenticated2;
var init_replitAuth = __esm({
  "server/replitAuth.ts"() {
    "use strict";
    init_storage();
    if (!process.env.REPLIT_DOMAINS) {
      throw new Error("Environment variable REPLIT_DOMAINS not provided");
    }
    getOidcConfig = memoize(
      async () => {
        const issuerUrl = process.env.ISSUER_URL || "https://replit.com/oidc";
        console.log("\u{1F511} Using OIDC issuer:", issuerUrl);
        return await client.discovery(
          new URL(issuerUrl),
          process.env.REPL_ID
        );
      },
      { maxAge: 3600 * 1e3 }
    );
    isAuthenticated2 = async (req, res, next) => {
      try {
        authLog2("DEBUG", `Authentication check for ${req.method} ${req.path}`, {
          ip: req.ip,
          userAgent: req.get("User-Agent"),
          sessionId: req.sessionID,
          hasSession: !!req.session,
          isAuthenticated: req.isAuthenticated ? req.isAuthenticated() : false
        });
        if (process.env.NODE_ENV === "development" && (!req.isAuthenticated() || !req.user)) {
          authLog2("DEBUG", "Development mode: Creating test admin user");
          authLog2("WARN", "SECURITY: Authentication bypass active - DO NOT USE IN PRODUCTION");
          req.user = {
            claims: {
              sub: "test-admin-user",
              email: "admin@test.com",
              first_name: "Test",
              last_name: "Admin"
            }
          };
          try {
            await storage.upsertUser({
              id: "test-admin-user",
              email: "admin@test.com",
              firstName: "Test",
              lastName: "Admin",
              profileImageUrl: null
            });
            const currentUser = await storage.getUser("test-admin-user");
            const currentRole = currentUser?.role || "admin";
            if (!currentUser || !currentUser.role) {
              await storage.updateUserRole("test-admin-user", "admin");
              authLog2("INFO", "Test admin user authenticated successfully");
            } else {
              authLog2("INFO", `Test user authenticated with current role: ${currentRole}`);
            }
          } catch (dbError) {
            authLog2("ERROR", "Failed to setup test user:", dbError);
          }
          return next();
        }
        if (!req.isAuthenticated() || !req.user) {
          authLog2("WARN", "Unauthorized access attempt", {
            path: req.path,
            method: req.method,
            ip: req.ip,
            userAgent: req.get("User-Agent"),
            sessionId: req.sessionID
          });
          return res.status(401).json({ message: "Unauthorized" });
        }
        const user = req.user;
        authLog2("DEBUG", "User authenticated", {
          userId: user.claims?.sub || "unknown",
          email: user.claims?.email || "unknown",
          sessionId: req.sessionID
        });
        if (user.expires_at && Date.now() / 1e3 > user.expires_at) {
          authLog2("WARN", "Access token expired, attempting refresh", {
            userId: user.claims?.sub,
            expiresAt: user.expires_at,
            hasRefreshToken: !!user.refresh_token
          });
          if (user.refresh_token) {
            try {
              const config = await getOidcConfig();
              const tokens = await client.refreshTokenGrant(
                config,
                user.refresh_token
              );
              updateUserSession(user, tokens);
              await upsertUser(tokens.claims());
              authLog2("INFO", "Token refreshed successfully", {
                userId: tokens.claims().sub
              });
            } catch (refreshError) {
              authLog2("ERROR", "Token refresh failed:", {
                userId: user.claims?.sub,
                error: refreshError instanceof Error ? {
                  message: refreshError.message,
                  stack: refreshError.stack
                } : refreshError
              });
              return res.status(401).json({ message: "Unauthorized" });
            }
          } else {
            authLog2("ERROR", "No refresh token available for expired session", {
              userId: user.claims?.sub
            });
            return res.status(401).json({ message: "Unauthorized" });
          }
        }
        authLog2("DEBUG", "Authentication successful, proceeding to next middleware");
        return next();
      } catch (error) {
        authLog2("ERROR", "Authentication middleware error:", {
          error: error instanceof Error ? {
            message: error.message,
            stack: error.stack,
            name: error.name
          } : error,
          request: {
            method: req.method,
            path: req.path,
            ip: req.ip,
            sessionId: req.sessionID
          }
        });
        return res.status(500).json({ message: "Internal server error" });
      }
    };
  }
});

// server/index.ts
init_fmb_env();
init_fmb_database();
import dotenv from "dotenv";
import express2 from "express";

// server/routes.ts
init_storage();
init_fmb_env();
init_schema();
import { createServer } from "http";
import { z as z2 } from "zod";
function getRolePermissions(role) {
  const permissions = {
    admin: [
      "manage_users",
      "manage_system",
      "view_all_projects",
      "manage_all_departments",
      "generate_all_reports",
      "system_configuration"
    ],
    manager: [
      "manage_department",
      "view_department_projects",
      "manage_employees",
      "generate_department_reports",
      "view_department_analytics"
    ],
    project_manager: [
      "create_projects",
      "manage_projects",
      "view_project_analytics",
      "generate_project_reports",
      "manage_tasks",
      "assign_team_members"
    ],
    employee: [
      "log_time",
      "view_assigned_projects",
      "view_own_reports",
      "manage_profile",
      "complete_tasks"
    ],
    viewer: [
      "view_assigned_projects",
      "view_own_time_entries",
      "view_basic_reports"
    ]
  };
  return permissions[role] || permissions.employee;
}
async function registerRoutes(app2) {
  let isAuthenticated3;
  if (isFmbOnPremEnvironment()) {
    console.log("\u{1F680} Setting up FMB SAML Authentication for On-Premises environment...");
    const { setupFmbSamlAuth: setupFmbSamlAuth2, isAuthenticated: fmbAuth } = await Promise.resolve().then(() => (init_fmb_saml_auth(), fmb_saml_auth_exports));
    await setupFmbSamlAuth2(app2);
    isAuthenticated3 = fmbAuth;
  } else {
    console.log("\u{1F680} Setting up Replit Authentication...");
    const { setupAuth: setupAuth2, isAuthenticated: replitAuth } = await Promise.resolve().then(() => (init_replitAuth(), replitAuth_exports));
    await setupAuth2(app2);
    isAuthenticated3 = replitAuth;
  }
  app2.get("/api/auth/user", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const response = {
        ...user,
        authContext: {
          role: user?.role || "employee",
          permissions: getRolePermissions(user?.role || "employee")
        }
      };
      res.json(response);
    } catch (error) {
      console.error("Error fetching user:", error);
      res.status(500).json({ message: "Failed to fetch user" });
    }
  });
  app2.get("/api/projects", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const projects2 = await storage.getProjects();
      res.json(projects2);
    } catch (error) {
      console.error("Error fetching projects:", error);
      res.status(500).json({ message: "Failed to fetch projects" });
    }
  });
  app2.get("/api/projects/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { id } = req.params;
      const project = await storage.getProject(id, userId);
      if (!project) {
        return res.status(404).json({ message: "Project not found" });
      }
      res.json(project);
    } catch (error) {
      console.error("Error fetching project:", error);
      res.status(500).json({ message: "Failed to fetch project" });
    }
  });
  app2.post("/api/projects", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (!["admin", "project_manager"].includes(userRole)) {
        return res.status(403).json({ message: "Insufficient permissions to create projects" });
      }
      const projectData = insertProjectSchema.parse({ ...req.body, userId });
      const project = await storage.createProject(projectData, userId);
      res.status(201).json(project);
    } catch (error) {
      if (error instanceof z2.ZodError) {
        return res.status(400).json({ message: "Invalid project data", errors: error.errors });
      }
      console.error("Error creating project:", error);
      res.status(500).json({ message: "Failed to create project" });
    }
  });
  app2.patch("/api/projects/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { id } = req.params;
      console.log("Received project update data:", req.body);
      const projectData = insertProjectSchema.partial().parse(req.body);
      const project = await storage.updateProject(id, projectData, userId);
      if (!project) {
        return res.status(404).json({ message: "Project not found" });
      }
      res.json(project);
    } catch (error) {
      if (error instanceof z2.ZodError) {
        console.error("Project validation error:", error.errors);
        return res.status(400).json({ message: "Invalid project data", errors: error.errors });
      }
      if (error instanceof Error && error.message.includes("Insufficient permissions")) {
        return res.status(403).json({ message: error.message });
      }
      console.error("Error updating project:", error);
      res.status(500).json({ message: "Failed to update project" });
    }
  });
  app2.put("/api/projects/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { id } = req.params;
      console.log("Received project PUT update data:", req.body);
      const projectData = insertProjectSchema.partial().parse(req.body);
      const project = await storage.updateProject(id, projectData, userId);
      if (!project) {
        return res.status(404).json({ message: "Project not found" });
      }
      res.json(project);
    } catch (error) {
      if (error instanceof z2.ZodError) {
        console.error("Project validation error:", error.errors);
        return res.status(400).json({ message: "Invalid project data", errors: error.errors });
      }
      console.error("Error updating project:", error);
      res.status(500).json({ message: "Failed to update project" });
    }
  });
  app2.delete("/api/projects/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { id } = req.params;
      const deleted = await storage.deleteProject(id, userId);
      if (!deleted) {
        return res.status(404).json({ message: "Project not found" });
      }
      res.status(204).send();
    } catch (error) {
      if (error instanceof Error && error.message.includes("Insufficient permissions")) {
        return res.status(403).json({ message: error.message });
      }
      console.error("Error deleting project:", error);
      res.status(500).json({ message: "Failed to delete project" });
    }
  });
  app2.get("/api/projects/:id/employees", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (!["admin", "project_manager"].includes(userRole)) {
        return res.status(403).json({ message: "Insufficient permissions to view project employee assignments" });
      }
      const { id } = req.params;
      const employees2 = await storage.getProjectEmployees(id, userId);
      res.json(employees2);
    } catch (error) {
      console.error("Error fetching project employees:", error);
      res.status(500).json({ message: "Failed to fetch project employees" });
    }
  });
  app2.post("/api/projects/:id/employees", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (!["admin", "project_manager"].includes(userRole)) {
        return res.status(403).json({ message: "Insufficient permissions to assign employees to projects" });
      }
      const { id } = req.params;
      const { employeeIds } = req.body;
      if (!Array.isArray(employeeIds)) {
        return res.status(400).json({ message: "employeeIds must be an array" });
      }
      await storage.assignEmployeesToProject(id, employeeIds, userId);
      res.status(200).json({ message: "Employees assigned successfully" });
    } catch (error) {
      console.error("Error assigning employees to project:", error);
      res.status(500).json({ message: "Failed to assign employees to project" });
    }
  });
  app2.delete("/api/projects/:id/employees/:employeeId", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (!["admin", "project_manager"].includes(userRole)) {
        return res.status(403).json({ message: "Insufficient permissions to remove employees from projects" });
      }
      const { id, employeeId } = req.params;
      const removed = await storage.removeEmployeeFromProject(id, employeeId, userId);
      if (!removed) {
        return res.status(404).json({ message: "Employee assignment not found" });
      }
      res.status(204).send();
    } catch (error) {
      console.error("Error removing employee from project:", error);
      res.status(500).json({ message: "Failed to remove employee from project" });
    }
  });
  app2.get("/api/projects/:projectId/tasks", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { projectId } = req.params;
      const tasks2 = await storage.getTasks(projectId, userId);
      res.json(tasks2);
    } catch (error) {
      console.error("Error fetching tasks:", error);
      res.status(500).json({ message: "Failed to fetch tasks" });
    }
  });
  app2.get("/api/tasks/all", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const tasks2 = await storage.getAllUserTasks(userId);
      res.json(tasks2);
    } catch (error) {
      console.error("Error fetching all tasks:", error);
      res.status(500).json({ message: "Failed to fetch tasks" });
    }
  });
  app2.get("/api/tasks/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { id } = req.params;
      const task = await storage.getTask(id, userId);
      if (!task) {
        return res.status(404).json({ message: "Task not found" });
      }
      res.json(task);
    } catch (error) {
      console.error("Error fetching task:", error);
      res.status(500).json({ message: "Failed to fetch task" });
    }
  });
  app2.post("/api/tasks", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (!["admin", "project_manager"].includes(userRole)) {
        return res.status(403).json({ message: "Insufficient permissions to create tasks" });
      }
      const taskData = insertTaskSchema.parse(req.body);
      const project = await storage.getProject(taskData.projectId, userId);
      if (!project) {
        return res.status(404).json({ message: "Project not found" });
      }
      const task = await storage.createTask(taskData);
      res.status(201).json(task);
    } catch (error) {
      if (error instanceof z2.ZodError) {
        return res.status(400).json({ message: "Invalid task data", errors: error.errors });
      }
      console.error("Error creating task:", error);
      res.status(500).json({ message: "Failed to create task" });
    }
  });
  app2.put("/api/tasks/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (!["admin", "project_manager"].includes(userRole)) {
        return res.status(403).json({ message: "Insufficient permissions to edit tasks" });
      }
      const { id } = req.params;
      const taskData = insertTaskSchema.partial().parse(req.body);
      const task = await storage.updateTask(id, taskData, userId);
      if (!task) {
        return res.status(404).json({ message: "Task not found" });
      }
      res.json(task);
    } catch (error) {
      if (error instanceof z2.ZodError) {
        return res.status(400).json({ message: "Invalid task data", errors: error.errors });
      }
      console.error("Error updating task:", error);
      res.status(500).json({ message: "Failed to update task" });
    }
  });
  app2.delete("/api/tasks/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { id } = req.params;
      const deleted = await storage.deleteTask(id, userId);
      if (!deleted) {
        return res.status(404).json({ message: "Task not found" });
      }
      res.status(204).send();
    } catch (error) {
      console.error("Error deleting task:", error);
      res.status(500).json({ message: "Failed to delete task" });
    }
  });
  app2.post("/api/tasks/:id/clone", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { id } = req.params;
      const { targetProjectId } = req.body;
      if (!targetProjectId) {
        return res.status(400).json({ message: "Target project ID is required" });
      }
      const originalTask = await storage.getTask(id, userId);
      if (!originalTask) {
        return res.status(404).json({ message: "Task not found" });
      }
      const targetProject = await storage.getProject(targetProjectId, userId);
      if (!targetProject) {
        return res.status(403).json({ message: "Access denied to target project" });
      }
      const clonedTask = await storage.createTask({
        projectId: targetProjectId,
        name: originalTask.name,
        description: originalTask.description,
        status: "active"
        // Reset status to active for cloned tasks
      });
      res.status(201).json(clonedTask);
    } catch (error) {
      console.error("Error cloning task:", error);
      res.status(500).json({ message: "Failed to clone task" });
    }
  });
  app2.get("/api/time-entries", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { projectId, startDate, endDate, limit, offset } = req.query;
      const filters = {
        projectId: projectId === "all" || !projectId ? void 0 : projectId,
        startDate,
        endDate,
        limit: limit ? parseInt(limit) : void 0,
        offset: offset ? parseInt(offset) : void 0
      };
      const timeEntries2 = await storage.getTimeEntries(userId, filters);
      res.json(timeEntries2);
    } catch (error) {
      console.error("Error fetching time entries:", error);
      res.status(500).json({ message: "Failed to fetch time entries" });
    }
  });
  app2.get("/api/time-entries/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { id } = req.params;
      const timeEntry = await storage.getTimeEntry(id, userId);
      if (!timeEntry) {
        return res.status(404).json({ message: "Time entry not found" });
      }
      res.json(timeEntry);
    } catch (error) {
      console.error("Error fetching time entry:", error);
      res.status(500).json({ message: "Failed to fetch time entry" });
    }
  });
  app2.post("/api/time-entries", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      console.log("\u{1F4DD} Time Entry Request Body:", JSON.stringify(req.body, null, 2));
      let processedData = { ...req.body, userId };
      if (processedData.duration && !processedData.startTime && !processedData.endTime) {
        processedData.startTime = "09:00";
        const durationHours = parseFloat(processedData.duration);
        const endHour = 9 + Math.floor(durationHours);
        const endMinute = Math.round(durationHours % 1 * 60);
        processedData.endTime = `${endHour.toString().padStart(2, "0")}:${endMinute.toString().padStart(2, "0")}`;
      }
      const entryData = insertTimeEntrySchema.parse(processedData);
      console.log("\u2705 Parsed Entry Data:", JSON.stringify(entryData, null, 2));
      const timeEntry = await storage.createTimeEntry(entryData);
      res.status(201).json(timeEntry);
    } catch (error) {
      if (error instanceof z2.ZodError) {
        console.error("\u274C Validation Error:", error.errors);
        return res.status(400).json({ message: "Invalid time entry data", errors: error.errors });
      }
      console.error("Error creating time entry:", error);
      res.status(500).json({ message: "Failed to create time entry" });
    }
  });
  app2.put("/api/time-entries/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { id } = req.params;
      const partialSchema = insertTimeEntrySchema.deepPartial();
      const entryData = partialSchema.parse(req.body);
      const timeEntry = await storage.updateTimeEntry(id, entryData, userId);
      if (!timeEntry) {
        return res.status(404).json({ message: "Time entry not found" });
      }
      res.json(timeEntry);
    } catch (error) {
      if (error instanceof z2.ZodError) {
        return res.status(400).json({ message: "Invalid time entry data", errors: error.errors });
      }
      console.error("Error updating time entry:", error);
      res.status(500).json({ message: "Failed to update time entry" });
    }
  });
  app2.delete("/api/time-entries/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { id } = req.params;
      const deleted = await storage.deleteTimeEntry(id, userId);
      if (!deleted) {
        return res.status(404).json({ message: "Time entry not found" });
      }
      res.status(204).send();
    } catch (error) {
      console.error("Error deleting time entry:", error);
      res.status(500).json({ message: "Failed to delete time entry" });
    }
  });
  app2.get("/api/dashboard/stats", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { startDate, endDate } = req.query;
      const stats = await storage.getDashboardStats(
        userId,
        startDate,
        endDate
      );
      res.json(stats);
    } catch (error) {
      console.error("Error fetching dashboard stats:", error);
      res.status(500).json({ message: "Failed to fetch dashboard stats" });
    }
  });
  app2.get("/api/dashboard/project-breakdown", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { startDate, endDate } = req.query;
      const breakdown = await storage.getProjectTimeBreakdown(
        userId,
        startDate,
        endDate
      );
      res.json(breakdown);
    } catch (error) {
      console.error("Error fetching project breakdown:", error);
      res.status(500).json({ message: "Failed to fetch project breakdown" });
    }
  });
  app2.get("/api/dashboard/recent-activity", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { limit, startDate, endDate } = req.query;
      const activity = await storage.getRecentActivity(
        userId,
        limit ? parseInt(limit) : void 0,
        startDate,
        endDate
      );
      res.json(activity);
    } catch (error) {
      console.error("Error fetching recent activity:", error);
      res.status(500).json({ message: "Failed to fetch recent activity" });
    }
  });
  app2.get("/api/dashboard/department-hours", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { startDate, endDate } = req.query;
      console.log("\u{1F3E2} Fetching department hours for user:", userId, "dates:", startDate, endDate);
      const departmentHours = await storage.getDepartmentHoursSummary(userId, startDate, endDate);
      console.log("\u{1F4CA} Department hours result:", JSON.stringify(departmentHours, null, 2));
      res.json(departmentHours);
    } catch (error) {
      console.error("\u274C Error fetching department hours:", error);
      res.status(500).json({ message: "Failed to fetch department hours" });
    }
  });
  app2.get("/api/users/current-role", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      res.json({
        role: user?.role || "employee",
        permissions: getRolePermissions(user?.role || "employee")
      });
    } catch (error) {
      console.error("Error fetching user role:", error);
      res.status(500).json({ message: "Failed to fetch user role" });
    }
  });
  app2.post("/api/users/change-role", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { role } = req.body;
      const validRoles = ["admin", "manager", "project_manager", "employee", "viewer"];
      if (!validRoles.includes(role)) {
        return res.status(400).json({ message: "Invalid role" });
      }
      await storage.updateUserRole(userId, role);
      res.json({ message: "Role updated successfully", role });
    } catch (error) {
      console.error("Error changing user role:", error);
      res.status(500).json({ message: "Failed to change user role" });
    }
  });
  app2.post("/api/admin/test-role", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { testRole } = req.body;
      const currentUser = await storage.getUser(userId);
      if (!currentUser || currentUser.role !== "admin") {
        return res.status(403).json({ message: "Only administrators can use role testing" });
      }
      const validRoles = ["admin", "manager", "project_manager", "employee", "viewer"];
      if (!validRoles.includes(testRole)) {
        return res.status(400).json({ message: "Invalid test role" });
      }
      req.session.originalRole = currentUser.role;
      req.session.testingRole = true;
      await storage.updateUserRole(userId, testRole);
      console.log(`\u{1F9EA} [ROLE-TEST] Admin ${currentUser.email} testing role: ${testRole} (original: ${req.session.originalRole})`);
      res.json({
        message: `Now testing as ${testRole}. Use restore-admin-role to return to admin.`,
        testRole,
        originalRole: req.session.originalRole,
        testing: true
      });
    } catch (error) {
      console.error("Error changing to test role:", error);
      res.status(500).json({ message: "Failed to change to test role" });
    }
  });
  app2.post("/api/admin/restore-role", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const currentUser = await storage.getUser(userId);
      if (!req.session.originalRole || !req.session.testingRole) {
        return res.status(400).json({ message: "No role testing session found" });
      }
      await storage.updateUserRole(userId, req.session.originalRole);
      console.log(`\u{1F9EA} [ROLE-TEST] Restored ${currentUser?.email} to original role: ${req.session.originalRole}`);
      const originalRole = req.session.originalRole;
      delete req.session.originalRole;
      delete req.session.testingRole;
      res.json({
        message: `Role restored to ${originalRole}`,
        role: originalRole,
        testing: false
      });
    } catch (error) {
      console.error("Error restoring admin role:", error);
      res.status(500).json({ message: "Failed to restore admin role" });
    }
  });
  app2.get("/api/admin/test-status", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const currentUser = await storage.getUser(userId);
      res.json({
        currentRole: currentUser?.role || "employee",
        originalRole: req.session.originalRole || null,
        testing: !!req.session.testingRole,
        canTest: currentUser?.role === "admin" || !!req.session.originalRole
      });
    } catch (error) {
      console.error("Error getting test status:", error);
      res.status(500).json({ message: "Failed to get test status" });
    }
  });
  app2.post("/api/admin/create-test-users", isAuthenticated3, async (req, res) => {
    try {
      const currentUserId = req.user.claims.sub;
      const currentUser = await storage.getUser(currentUserId);
      if (!currentUser || !["admin", "manager"].includes(currentUser.role || "employee")) {
        return res.status(403).json({ message: "Insufficient permissions" });
      }
      const testUsers = await storage.createTestUsers();
      res.json({ message: "Test users created successfully", users: testUsers });
    } catch (error) {
      console.error("Error creating test users:", error);
      res.status(500).json({ message: "Failed to create test users" });
    }
  });
  app2.get("/api/admin/test-users", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      if (!user || !["admin", "manager"].includes(user.role || "employee")) {
        return res.status(403).json({ message: "Insufficient permissions" });
      }
      const testUsers = await storage.getTestUsers();
      res.json(testUsers);
    } catch (error) {
      console.error("Error fetching test users:", error);
      res.status(500).json({ message: "Failed to fetch test users" });
    }
  });
  app2.get("/api/reports/project-time-entries/:projectId", isAuthenticated3, async (req, res) => {
    try {
      const { projectId } = req.params;
      const userId = req.user.claims.sub;
      if (!userId) {
        return res.status(401).json({ message: "User not authenticated" });
      }
      const currentUser = await storage.getUser(userId);
      const allowedRoles = ["project_manager", "admin", "manager"];
      if (!currentUser || !allowedRoles.includes(currentUser.role || "employee")) {
        return res.status(403).json({ message: "Insufficient permissions to view reports" });
      }
      const timeEntries2 = await storage.getTimeEntriesForProject(projectId);
      res.json(timeEntries2);
    } catch (error) {
      console.error("Error fetching project time entries:", error);
      res.status(500).json({ message: "Failed to fetch project time entries" });
    }
  });
  app2.get("/api/employees", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const employees2 = await storage.getEmployees(userId);
      res.json(employees2);
    } catch (error) {
      console.error("Error fetching employees:", error);
      res.status(500).json({ message: "Failed to fetch employees" });
    }
  });
  app2.get("/api/employees/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const { id } = req.params;
      const employee = await storage.getEmployee(id, userId);
      if (!employee) {
        return res.status(404).json({ message: "Employee not found" });
      }
      res.json(employee);
    } catch (error) {
      console.error("Error fetching employee:", error);
      res.status(500).json({ message: "Failed to fetch employee" });
    }
  });
  app2.post("/api/employees", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (!["admin", "manager"].includes(userRole)) {
        return res.status(403).json({ message: "Insufficient permissions to create employees" });
      }
      const employeeData = insertEmployeeSchema.parse({ ...req.body, userId });
      const employee = await storage.createEmployee(employeeData);
      res.status(201).json(employee);
    } catch (error) {
      if (error instanceof z2.ZodError) {
        return res.status(400).json({ message: "Invalid employee data", errors: error.errors });
      }
      console.error("Error creating employee:", error);
      res.status(500).json({ message: "Failed to create employee" });
    }
  });
  app2.put("/api/employees/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (!["admin", "manager"].includes(userRole)) {
        return res.status(403).json({ message: "Insufficient permissions to update employees" });
      }
      const { id } = req.params;
      const employeeData = insertEmployeeSchema.partial().parse(req.body);
      const employee = await storage.updateEmployee(id, employeeData, userId);
      if (!employee) {
        return res.status(404).json({ message: "Employee not found" });
      }
      res.json(employee);
    } catch (error) {
      if (error instanceof z2.ZodError) {
        return res.status(400).json({ message: "Invalid employee data", errors: error.errors });
      }
      console.error("Error updating employee:", error);
      res.status(500).json({ message: "Failed to update employee" });
    }
  });
  app2.delete("/api/employees/:id", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (!["admin", "manager"].includes(userRole)) {
        return res.status(403).json({ message: "Insufficient permissions to delete employees" });
      }
      const { id } = req.params;
      const deleted = await storage.deleteEmployee(id, userId);
      if (!deleted) {
        return res.status(404).json({ message: "Employee not found" });
      }
      res.status(204).send();
    } catch (error) {
      console.error("Error deleting employee:", error);
      res.status(500).json({ message: "Failed to delete employee" });
    }
  });
  app2.get("/api/departments", isAuthenticated3, async (req, res) => {
    try {
      const departments2 = await storage.getDepartments();
      console.log(`\u{1F4CB} Departments API: Found ${departments2.length} departments`);
      res.json(departments2);
    } catch (error) {
      console.error("\u274C Error fetching departments:", error);
      res.status(500).json({ message: "Failed to fetch departments" });
    }
  });
  app2.get("/api/departments/:id", isAuthenticated3, async (req, res) => {
    try {
      const { id } = req.params;
      const department = await storage.getDepartment(id);
      if (!department) {
        return res.status(404).json({ message: "Department not found" });
      }
      res.json(department);
    } catch (error) {
      console.error("Error fetching department:", error);
      res.status(500).json({ message: "Failed to fetch department" });
    }
  });
  app2.post("/api/departments", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (userRole !== "admin") {
        return res.status(403).json({ message: "Insufficient permissions to create departments" });
      }
      const departmentData = { ...req.body, userId };
      const department = await storage.createDepartment(departmentData);
      res.status(201).json(department);
    } catch (error) {
      console.error("Error creating department:", error);
      res.status(500).json({ message: "Failed to create department" });
    }
  });
  app2.put("/api/departments/:id", isAuthenticated3, async (req, res) => {
    try {
      const { id } = req.params;
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (userRole !== "admin") {
        return res.status(403).json({ message: "Insufficient permissions to update departments" });
      }
      const department = await storage.updateDepartment(id, req.body, userId);
      if (!department) {
        return res.status(404).json({ message: "Department not found" });
      }
      res.json(department);
    } catch (error) {
      console.error("Error updating department:", error);
      res.status(500).json({ message: "Failed to update department" });
    }
  });
  app2.delete("/api/departments/:id", isAuthenticated3, async (req, res) => {
    try {
      const { id } = req.params;
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (userRole !== "admin") {
        return res.status(403).json({ message: "Insufficient permissions to delete departments" });
      }
      const success = await storage.deleteDepartment(id, userId);
      if (!success) {
        return res.status(404).json({ message: "Department not found" });
      }
      res.json({ message: "Department deleted successfully" });
    } catch (error) {
      console.error("Error deleting department:", error);
      res.status(500).json({ message: "Failed to delete department" });
    }
  });
  app2.post("/api/departments/:id/manager", isAuthenticated3, async (req, res) => {
    try {
      const { id } = req.params;
      const { managerId } = req.body;
      const userId = req.user.claims.sub;
      await storage.assignManagerToDepartment(id, managerId, userId);
      res.json({ message: "Manager assigned successfully" });
    } catch (error) {
      console.error("Error assigning manager:", error);
      res.status(500).json({ message: "Failed to assign manager" });
    }
  });
  app2.get("/api/admin/users", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      if (user?.role !== "admin") {
        return res.status(403).json({ message: "Only System Administrators can view all users" });
      }
      const users2 = await storage.getAllUsers();
      res.json(users2);
    } catch (error) {
      console.error("Error fetching users:", error);
      res.status(500).json({ message: "Failed to fetch users" });
    }
  });
  app2.get("/api/admin/users/without-employee", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      if (user?.role !== "admin") {
        return res.status(403).json({ message: "Only System Administrators can view unlinked users" });
      }
      const users2 = await storage.getUsersWithoutEmployeeProfile();
      res.json(users2);
    } catch (error) {
      console.error("Error fetching unlinked users:", error);
      res.status(500).json({ message: "Failed to fetch unlinked users" });
    }
  });
  app2.post("/api/admin/employees/:employeeId/link-user", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      if (user?.role !== "admin") {
        return res.status(403).json({ message: "Only System Administrators can link users to employees" });
      }
      const { employeeId } = req.params;
      const { userId: targetUserId } = req.body;
      const linkedEmployee = await storage.linkUserToEmployee(targetUserId, employeeId);
      if (!linkedEmployee) {
        return res.status(404).json({ message: "Employee not found" });
      }
      res.json({ message: "User successfully linked to employee", employee: linkedEmployee });
    } catch (error) {
      console.error("Error linking user to employee:", error);
      res.status(500).json({ message: "Failed to link user to employee" });
    }
  });
  app2.post("/api/admin/users/:userId/role", isAuthenticated3, async (req, res) => {
    try {
      console.log("\u{1F464} Role update request - User:", req.user?.claims?.sub);
      console.log("\u{1F3AF} Target user ID:", req.params.userId);
      console.log("\u{1F504} New role:", req.body.role);
      const currentUserId = req.user.claims.sub;
      console.log("\u{1F50D} Fetching current user...");
      const currentUser = await storage.getUser(currentUserId);
      console.log("\u{1F4CB} Current user role:", currentUser?.role);
      if (currentUser?.role !== "admin") {
        console.log("\u274C Access denied - user is not admin");
        return res.status(403).json({ message: "Only System Administrators can change user roles" });
      }
      const { userId: targetUserId } = req.params;
      const { role } = req.body;
      if (!role) {
        console.log("\u274C No role provided in request body");
        return res.status(400).json({ message: "Role is required" });
      }
      const validRoles = ["admin", "manager", "project_manager", "employee", "viewer"];
      if (!validRoles.includes(role)) {
        console.log("\u274C Invalid role:", role);
        return res.status(400).json({ message: `Invalid role specified. Valid roles: ${validRoles.join(", ")}` });
      }
      if (currentUserId === targetUserId && role !== "admin") {
        console.log("\u274C User trying to remove their own admin privileges");
        return res.status(400).json({ message: "Cannot remove your own admin privileges" });
      }
      console.log("\u{1F504} Updating user role in database...");
      const updatedUser = await storage.updateUserRole(targetUserId, role);
      console.log("\u2705 Role update result:", !!updatedUser);
      if (!updatedUser) {
        console.log("\u274C User not found for ID:", targetUserId);
        return res.status(404).json({ message: "User not found" });
      }
      console.log("\u2705 Role updated successfully");
      res.json({ message: "User role updated successfully", user: updatedUser });
    } catch (error) {
      console.error("\u{1F4A5} Error updating user role:", error);
      console.error("Error details:", {
        message: error.message,
        stack: error.stack,
        name: error.name
      });
      res.status(500).json({
        message: "Failed to update user role",
        error: process.env.NODE_ENV === "production" ? "Internal server error" : error.message
      });
    }
  });
  app2.get("/api/organizations", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const organizations2 = await storage.getOrganizations();
      res.json(organizations2);
    } catch (error) {
      console.error("Error fetching organizations:", error);
      res.status(500).json({ message: "Failed to fetch organizations" });
    }
  });
  app2.get("/api/organizations/:id", isAuthenticated3, async (req, res) => {
    try {
      const { id } = req.params;
      const organization = await storage.getOrganization(id);
      if (!organization) {
        return res.status(404).json({ message: "Organization not found" });
      }
      res.json(organization);
    } catch (error) {
      console.error("Error fetching organization:", error);
      res.status(500).json({ message: "Failed to fetch organization" });
    }
  });
  app2.post("/api/organizations", isAuthenticated3, async (req, res) => {
    try {
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (userRole !== "admin") {
        return res.status(403).json({ message: "Insufficient permissions to create organizations" });
      }
      const organizationData = { ...req.body, userId };
      const organization = await storage.createOrganization(organizationData);
      res.status(201).json(organization);
    } catch (error) {
      console.error("Error creating organization:", error);
      res.status(500).json({ message: "Failed to create organization" });
    }
  });
  app2.put("/api/organizations/:id", isAuthenticated3, async (req, res) => {
    try {
      const { id } = req.params;
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (userRole !== "admin") {
        return res.status(403).json({ message: "Insufficient permissions to update organizations" });
      }
      const organization = await storage.updateOrganization(id, req.body, userId);
      if (!organization) {
        return res.status(404).json({ message: "Organization not found" });
      }
      res.json(organization);
    } catch (error) {
      console.error("Error updating organization:", error);
      res.status(500).json({ message: "Failed to update organization" });
    }
  });
  app2.delete("/api/organizations/:id", isAuthenticated3, async (req, res) => {
    try {
      const { id } = req.params;
      const userId = req.user.claims.sub;
      const user = await storage.getUser(userId);
      const userRole = user?.role || "employee";
      if (userRole !== "admin") {
        return res.status(403).json({ message: "Insufficient permissions to delete organizations" });
      }
      const success = await storage.deleteOrganization(id, userId);
      if (!success) {
        return res.status(404).json({ message: "Organization not found" });
      }
      res.json({ message: "Organization deleted successfully" });
    } catch (error) {
      console.error("Error deleting organization:", error);
      res.status(500).json({ message: "Failed to delete organization" });
    }
  });
  app2.get("/api/organizations/:id/departments", isAuthenticated3, async (req, res) => {
    try {
      const { id } = req.params;
      const departments2 = await storage.getDepartmentsByOrganization(id);
      res.json(departments2);
    } catch (error) {
      console.error("Error fetching organization departments:", error);
      res.status(500).json({ message: "Failed to fetch organization departments" });
    }
  });
  app2.post("/api/log/frontend-error", async (req, res) => {
    try {
      const { timestamp: timestamp2, level, category, message, data, url, userAgent } = req.body;
      const logMessage = `${timestamp2} \u{1F534} [FRONTEND-${category}] ${message}`;
      console.log(logMessage, {
        data,
        url,
        userAgent,
        ip: req.ip,
        sessionId: req.sessionID
      });
      res.json({ success: true });
    } catch (error) {
      console.error("Failed to log frontend error:", error);
      res.status(500).json({ message: "Logging failed" });
    }
  });
  app2.get("/api/health", (req, res) => {
    res.status(200).json({
      status: "healthy",
      timestamp: (/* @__PURE__ */ new Date()).toISOString(),
      uptime: process.uptime(),
      version: "1.0.0",
      environment: process.env.NODE_ENV || "development"
    });
  });
  const httpServer = createServer(app2);
  return httpServer;
}

// server/vite.ts
import express from "express";
import fs from "fs";
import path2 from "path";
import { createServer as createViteServer, createLogger } from "vite";

// vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";
import runtimeErrorOverlay from "@replit/vite-plugin-runtime-error-modal";
var vite_config_default = defineConfig({
  plugins: [
    react(),
    runtimeErrorOverlay(),
    ...process.env.NODE_ENV !== "production" && process.env.REPL_ID !== void 0 ? [
      await import("@replit/vite-plugin-cartographer").then(
        (m) => m.cartographer()
      )
    ] : []
  ],
  resolve: {
    alias: {
      "@": path.resolve(import.meta.dirname, "client", "src"),
      "@shared": path.resolve(import.meta.dirname, "shared"),
      "@assets": path.resolve(import.meta.dirname, "attached_assets")
    }
  },
  root: path.resolve(import.meta.dirname, "client"),
  build: {
    outDir: path.resolve(import.meta.dirname, "dist/public"),
    emptyOutDir: true
  },
  server: {
    fs: {
      strict: true,
      deny: ["**/.*"]
    }
  }
});

// server/vite.ts
import { nanoid } from "nanoid";
var viteLogger = createLogger();
function log(message, source = "express") {
  const formattedTime = (/* @__PURE__ */ new Date()).toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    second: "2-digit",
    hour12: true
  });
  console.log(`${formattedTime} [${source}] ${message}`);
}
async function setupVite(app2, server) {
  const serverOptions = {
    middlewareMode: true,
    hmr: { server },
    allowedHosts: true
  };
  const vite = await createViteServer({
    ...vite_config_default,
    configFile: false,
    customLogger: {
      ...viteLogger,
      error: (msg, options) => {
        viteLogger.error(msg, options);
        process.exit(1);
      }
    },
    server: serverOptions,
    appType: "custom"
  });
  app2.use(vite.middlewares);
  app2.use("*", async (req, res, next) => {
    const url = req.originalUrl;
    try {
      const clientTemplate = path2.resolve(
        import.meta.dirname,
        "..",
        "client",
        "index.html"
      );
      let template = await fs.promises.readFile(clientTemplate, "utf-8");
      template = template.replace(
        `src="/src/main.tsx"`,
        `src="/src/main.tsx?v=${nanoid()}"`
      );
      const page = await vite.transformIndexHtml(url, template);
      res.status(200).set({ "Content-Type": "text/html" }).end(page);
    } catch (e) {
      vite.ssrFixStacktrace(e);
      next(e);
    }
  });
}
function serveStatic(app2) {
  const distPath = path2.resolve(import.meta.dirname, "public");
  if (!fs.existsSync(distPath)) {
    throw new Error(
      `Could not find the build directory: ${distPath}, make sure to build the client first`
    );
  }
  app2.use(express.static(distPath));
  app2.use("*", (_req, res) => {
    res.sendFile(path2.resolve(distPath, "index.html"));
  });
}

// server/index.ts
dotenv.config();
var LOG_LEVELS = {
  ERROR: "\u{1F534} ERROR",
  WARN: "\u{1F7E1} WARN",
  INFO: "\u{1F535} INFO",
  DEBUG: "\u{1F7E2} DEBUG"
};
function enhancedLog(level, category, message, data) {
  const timestamp2 = (/* @__PURE__ */ new Date()).toISOString();
  const logMessage = `${timestamp2} ${LOG_LEVELS[level]} [${category}] ${message}`;
  if (data) {
    console.log(logMessage, typeof data === "object" ? JSON.stringify(data, null, 2) : data);
  } else {
    console.log(logMessage);
  }
}
process.on("uncaughtException", (error) => {
  enhancedLog("ERROR", "PROCESS", "Uncaught Exception:", {
    message: error.message,
    stack: error.stack,
    name: error.name
  });
  if (error.message.includes("terminating connection") || error.message.includes("database") || error.message.includes("connection")) {
    enhancedLog("WARN", "DATABASE", "Database connection error detected - attempting recovery...");
    setTimeout(() => {
      enhancedLog("INFO", "PROCESS", "Database error recovery timeout reached");
    }, 1e4);
    return;
  }
  enhancedLog("ERROR", "PROCESS", "Critical error - shutting down server");
  process.exit(1);
});
process.on("unhandledRejection", (reason, promise) => {
  const isDbError = reason instanceof Error && (reason.message.includes("terminating connection") || reason.message.includes("database") || reason.message.includes("connection"));
  enhancedLog(isDbError ? "WARN" : "ERROR", "PROCESS", "Unhandled Rejection:", {
    reason: reason instanceof Error ? {
      message: reason.message,
      stack: reason.stack,
      name: reason.name
    } : reason,
    promise: promise.toString(),
    isDatabaseError: isDbError
  });
  if (!isDbError) {
    enhancedLog("ERROR", "PROCESS", "Critical unhandled rejection - shutting down server");
    process.exit(1);
  } else {
    enhancedLog("INFO", "PROCESS", "Database error - continuing operation with connection recovery");
  }
});
function validateProductionEnvironment() {
  let required;
  if (isFmbOnPremEnvironment()) {
    required = ["NODE_ENV", "FMB_SESSION_SECRET", "FMB_DB_SERVER", "FMB_DB_NAME", "FMB_SAML_ENTITY_ID", "FMB_SAML_SSO_URL", "FMB_SAML_CERTIFICATE"];
    enhancedLog("INFO", "ENV", "\u{1F3E2} Running in FMB on-premises mode");
  } else {
    required = ["NODE_ENV", "SESSION_SECRET", "REPL_ID", "REPLIT_DOMAINS", "DATABASE_URL"];
    enhancedLog("INFO", "ENV", "\u2601\uFE0F Running in Replit cloud mode");
  }
  const missing = required.filter((varName) => !process.env[varName]);
  if (missing.length > 0) {
    enhancedLog("ERROR", "ENV", `Missing required environment variables: ${missing.join(", ")}`);
    enhancedLog("ERROR", "ENV", "Please check your environment configuration and .env.example file");
    process.exit(1);
  }
  if (!process.env.NODE_ENV) {
    enhancedLog("ERROR", "ENV", 'NODE_ENV must be explicitly set to "production" or "development"');
    process.exit(1);
  }
  if (process.env.NODE_ENV !== "production" && process.env.NODE_ENV !== "development") {
    enhancedLog("WARN", "ENV", `Unknown NODE_ENV: ${process.env.NODE_ENV}. Expected "production" or "development"`);
  }
  if (process.env.NODE_ENV !== "production") {
    enhancedLog("WARN", "ENV", "\u26A0\uFE0F  WARNING: Running in non-production mode with authentication bypass enabled");
  } else {
    enhancedLog("INFO", "ENV", "\u2705 Production mode enabled - authentication bypass disabled");
  }
  if (process.env.NODE_ENV === "production" && process.env.SESSION_SECRET && process.env.SESSION_SECRET.length < 32) {
    enhancedLog("WARN", "ENV", "\u26A0\uFE0F  WARNING: SESSION_SECRET should be at least 32 characters for production");
  }
  enhancedLog("INFO", "ENV", "Environment validation completed successfully");
}
process.env.TZ = process.env.TZ || "America/Los_Angeles";
enhancedLog("INFO", "TIMEZONE", `Set timezone to ${process.env.TZ}`);
validateProductionEnvironment();
var app = express2();
app.use(express2.json({ limit: "10mb" }));
app.use(express2.urlencoded({ extended: true, limit: "10mb" }));
if (isFmbOnPremEnvironment()) {
  enhancedLog("INFO", "FMB-ONPREM", "Initializing on-premises services...");
  try {
    await initializeFmbDatabase();
    enhancedLog("INFO", "FMB-ONPREM", "On-premises services initialized successfully");
  } catch (error) {
    enhancedLog("ERROR", "FMB-ONPREM", "Failed to initialize on-premises services:", error);
    process.exit(1);
  }
}
if (process.env.NODE_ENV === "production") {
  app.set("trust proxy", 1);
  app.use((req, res, next) => {
    res.setHeader("X-Content-Type-Options", "nosniff");
    res.setHeader("X-Frame-Options", "DENY");
    res.setHeader("X-XSS-Protection", "1; mode=block");
    res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
    res.setHeader("Permissions-Policy", "camera=(), microphone=(), geolocation=()");
    next();
  });
}
app.use((req, res, next) => {
  const start = Date.now();
  const path3 = req.path;
  let capturedJsonResponse = void 0;
  if (path3.startsWith("/api")) {
    enhancedLog("DEBUG", "REQUEST", `Incoming ${req.method} ${path3}`, {
      ip: req.ip,
      userAgent: req.get("User-Agent"),
      query: req.query,
      body: req.method !== "GET" && req.body ? req.body : void 0,
      sessionId: req.sessionID,
      authenticated: req.isAuthenticated ? req.isAuthenticated() : false
    });
  }
  const originalResJson = res.json;
  res.json = function(bodyJson, ...args) {
    capturedJsonResponse = bodyJson;
    return originalResJson.apply(res, [bodyJson, ...args]);
  };
  res.on("finish", () => {
    const duration = Date.now() - start;
    if (path3.startsWith("/api")) {
      let logLine = `${req.method} ${path3} ${res.statusCode} in ${duration}ms`;
      if (capturedJsonResponse) {
        logLine += ` :: ${JSON.stringify(capturedJsonResponse)}`;
      }
      if (logLine.length > 80) {
        logLine = logLine.slice(0, 79) + "\u2026";
      }
      log(logLine);
      if (res.statusCode >= 400) {
        enhancedLog("ERROR", "RESPONSE", `Error response for ${req.method} ${path3}`, {
          status: res.statusCode,
          duration: `${duration}ms`,
          response: capturedJsonResponse,
          request: {
            query: req.query,
            body: req.body,
            ip: req.ip,
            userAgent: req.get("User-Agent")
          }
        });
      }
    }
  });
  next();
});
(async () => {
  const server = await registerRoutes(app);
  app.use((err, req, res, _next) => {
    const status = err.status || err.statusCode || 500;
    const message = err.message || "Internal Server Error";
    enhancedLog("ERROR", "EXPRESS", "Express error middleware triggered:", {
      error: {
        message: err.message,
        stack: err.stack,
        name: err.name,
        code: err.code,
        status
      },
      request: {
        method: req.method,
        path: req.path,
        query: req.query,
        body: req.body,
        ip: req.ip,
        userAgent: req.get("User-Agent"),
        sessionId: req.sessionID,
        authenticated: req.isAuthenticated ? req.isAuthenticated() : false
      }
    });
    res.status(status).json({
      message,
      error: process.env.NODE_ENV === "development" ? {
        name: err.name,
        stack: err.stack
      } : void 0
    });
  });
  if (app.get("env") === "development") {
    await setupVite(app, server);
  } else {
    serveStatic(app);
  }
  const port = parseInt(process.env.PORT || "5000", 10);
  server.listen({
    port,
    host: "0.0.0.0",
    reusePort: true
  }, () => {
    enhancedLog("INFO", "SERVER", `Server started successfully on port ${port}`, {
      port,
      environment: process.env.NODE_ENV,
      timezone: process.env.TZ,
      host: "0.0.0.0"
    });
    log(`serving on port ${port}`);
  });
})();
export {
  enhancedLog
};
