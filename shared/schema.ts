import { sql } from 'drizzle-orm';
import {
  index,
  jsonb,
  pgTable,
  timestamp,
  varchar,
  text,
  decimal,
  date,
  boolean,
} from "drizzle-orm/pg-core";
import { createInsertSchema } from "drizzle-zod";
import { z } from "zod";
import { relations } from "drizzle-orm";

// Session storage table.
// (IMPORTANT) This table is mandatory for Replit Auth, don't drop it.
export const sessions = pgTable(
  "sessions",
  {
    sid: varchar("sid").primaryKey(),
    sess: jsonb("sess").notNull(),
    expire: timestamp("expire").notNull(),
  },
  (table) => [index("IDX_session_expire").on(table.expire)],
);

// User storage table.
// (IMPORTANT) This table is mandatory for Replit Auth, don't drop it.
export const users = pgTable("users", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  email: varchar("email").unique(),
  firstName: varchar("firstName"),
  lastName: varchar("lastName"),
  profileImageUrl: varchar("profileImageUrl"),
  role: varchar("role", { length: 50 }).default("employee"), // admin, manager, employee, viewer
  isActive: boolean("isActive").default(true).notNull(),
  lastLoginAt: timestamp("lastLoginAt"),
  createdAt: timestamp("createdAt").defaultNow(),
  updatedAt: timestamp("updatedAt").defaultNow(),
});

export const projects = pgTable("projects", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  name: varchar("name", { length: 255 }).notNull(),
  projectNumber: varchar("projectNumber", { length: 50 }), // Optional alphanumeric project number
  description: text("description"),
  color: varchar("color", { length: 7 }).default("#1976D2"), // Hex color code
  startDate: timestamp("startDate"),
  endDate: timestamp("endDate"),
  isEnterpriseWide: boolean("isEnterpriseWide").default(true).notNull(), // true = enterprise-wide, false = restricted
  userId: varchar("userId").notNull().references(() => users.id, { onDelete: "cascade" }),
  createdAt: timestamp("createdAt").defaultNow(),
  updatedAt: timestamp("updatedAt").defaultNow(),
  // Project settings
  isTemplate: boolean('isTemplate').default(false).notNull(),
  allowTimeTracking: boolean('allowTimeTracking').default(true).notNull(),
  requireTaskSelection: boolean('requireTaskSelection').default(false).notNull(),

  // Budget and billing
  enableBudgetTracking: boolean('enableBudgetTracking').default(false).notNull(),
  enableBilling: boolean('enableBilling').default(false).notNull(),
});

// Project tasks table
export const tasks = pgTable("tasks", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  projectId: varchar("projectId").notNull().references(() => projects.id, { onDelete: "cascade" }),
  name: varchar("name", { length: 255 }).notNull(),
  description: text("description"),
  status: varchar("status", { length: 50 }).notNull().default("active"), // active, completed, archived
  createdAt: timestamp("createdAt").defaultNow(),
  updatedAt: timestamp("updatedAt").defaultNow(),
});

export const timeEntries = pgTable("time_entries", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  userId: varchar("userId").notNull().references(() => users.id, { onDelete: "cascade" }),
  projectId: varchar("projectId").notNull().references(() => projects.id, { onDelete: "cascade" }),
  taskId: varchar("taskId").references(() => tasks.id, { onDelete: "set null" }),
  description: text("description"),
  date: date("date").notNull(),
  startTime: varchar("startTime", { length: 5 }).notNull(), // HH:MM format
  endTime: varchar("endTime", { length: 5 }).notNull(), // HH:MM format
  duration: decimal("duration", { precision: 5, scale: 2 }).notNull(), // Hours with 2 decimal places
  createdAt: timestamp("createdAt").defaultNow(),
  updatedAt: timestamp("updatedAt").defaultNow(),
  // Entry metadata
  isTemplate: boolean('isTemplate').default(false).notNull(),
  isBillable: boolean('isBillable').default(false).notNull(),
  isApproved: boolean('isApproved').default(false).notNull(),

  // Time tracking settings
  isManualEntry: boolean('isManualEntry').default(true).notNull(),
  isTimerEntry: boolean('isTimerEntry').default(false).notNull(),
});

// Relations
export const usersRelations = relations(users, ({ many }) => ({
  projects: many(projects),
  timeEntries: many(timeEntries),
}));

export const projectsRelations = relations(projects, ({ one, many }) => ({
  user: one(users, {
    fields: [projects.userId],
    references: [users.id],
  }),
  timeEntries: many(timeEntries),
  tasks: many(tasks),
  projectEmployees: many(projectEmployees),
}));

export const tasksRelations = relations(tasks, ({ one, many }) => ({
  project: one(projects, {
    fields: [tasks.projectId],
    references: [projects.id],
  }),
  timeEntries: many(timeEntries),
}));

export const timeEntriesRelations = relations(timeEntries, ({ one }) => ({
  user: one(users, {
    fields: [timeEntries.userId],
    references: [users.id],
  }),
  project: one(projects, {
    fields: [timeEntries.projectId],
    references: [projects.id],
  }),
  task: one(tasks, {
    fields: [timeEntries.taskId],
    references: [tasks.id],
  }),
}));

// Insert schemas
export const insertProjectSchema = createInsertSchema(projects).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
}).extend({
  startDate: z.coerce.date().optional(),
  endDate: z.coerce.date().optional(),
});

export const insertTaskSchema = createInsertSchema(tasks).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertTimeEntrySchema = createInsertSchema(timeEntries).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
}).extend({
  taskId: z.string().optional(),
});

// Employee management table
export const employees = pgTable("employees", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  employeeId: varchar("employeeId").notNull().unique(),
  firstName: varchar("firstName").notNull(),
  lastName: varchar("lastName").notNull(),
  department: varchar("department").notNull(),
  userId: varchar("userId").notNull().references(() => users.id, { onDelete: "cascade" }),
  createdAt: timestamp("createdAt").defaultNow(),
  updatedAt: timestamp("updatedAt").defaultNow(),
});

// Project-Employee assignments table (for restricted projects)
export const projectEmployees = pgTable("project_employees", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  projectId: varchar("projectId").notNull().references(() => projects.id, { onDelete: "cascade" }),
  employeeId: varchar("employeeId").notNull().references(() => employees.id, { onDelete: "cascade" }),
  userId: varchar("userId").notNull().references(() => users.id, { onDelete: "cascade" }),
  createdAt: timestamp("createdAt").defaultNow(),
});

// Relations that depend on all tables being defined
export const employeesRelations = relations(employees, ({ one, many }) => ({
  user: one(users, {
    fields: [employees.userId],
    references: [users.id],
  }),
  projectEmployees: many(projectEmployees),
  managedDepartments: many(departments),
}));

export const projectEmployeesRelations = relations(projectEmployees, ({ one }) => ({
  project: one(projects, {
    fields: [projectEmployees.projectId],
    references: [projects.id],
  }),
  employee: one(employees, {
    fields: [projectEmployees.employeeId],
    references: [employees.id],
  }),
  user: one(users, {
    fields: [projectEmployees.userId],
    references: [users.id],
  }),
}));

// Insert schemas
export const insertEmployeeSchema = createInsertSchema(employees).omit({
  id: true,
  createdAt: true,
  updatedAt: true,
});

export const insertProjectEmployeeSchema = createInsertSchema(projectEmployees).omit({
  id: true,
  createdAt: true,
});

export type InsertEmployee = z.infer<typeof insertEmployeeSchema>;
export type Employee = typeof employees.$inferSelect;
export type InsertProjectEmployee = z.infer<typeof insertProjectEmployeeSchema>;
export type ProjectEmployee = typeof projectEmployees.$inferSelect;

// Types
export type UpsertUser = typeof users.$inferInsert;
export type User = typeof users.$inferSelect;

// Organizations table - departments roll up under organizations
export const organizations = pgTable("organizations", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  name: varchar("name").notNull(),
  description: text("description"),
  userId: varchar("userId").notNull().references(() => users.id, { onDelete: "cascade" }),
  createdAt: timestamp("createdAt").defaultNow(),
  updatedAt: timestamp("updatedAt").defaultNow(),
});

// Departments table for department management - now references organizations
export const departments = pgTable("departments", {
  id: varchar("id").primaryKey().default(sql`gen_random_uuid()`),
  name: varchar("name").notNull(),
  organizationId: varchar("organizationId").notNull().references(() => organizations.id, { onDelete: "cascade" }),
  managerId: varchar("managerId").references(() => employees.id),
  description: varchar("description"),
  userId: varchar("userId").notNull().references(() => users.id, { onDelete: "cascade" }),
  createdAt: timestamp("createdAt").defaultNow(),
  updatedAt: timestamp("updatedAt").defaultNow(),
});

export const organizationsRelations = relations(organizations, ({ one, many }) => ({
  user: one(users, {
    fields: [organizations.userId],
    references: [users.id],
  }),
  departments: many(departments),
}));

export const departmentsRelations = relations(departments, ({ one }) => ({
  organization: one(organizations, {
    fields: [departments.organizationId],
    references: [organizations.id],
  }),
  manager: one(employees, {
    fields: [departments.managerId],
    references: [employees.id],
  }),
  user: one(users, {
    fields: [departments.userId],
    references: [users.id],
  }),
}));

export const insertOrganizationSchema = createInsertSchema(organizations).omit({
  id: true,
  createdAt: true,
  updatedAt: true
});

export const insertDepartmentSchema = createInsertSchema(departments).omit({
  id: true,
  createdAt: true,
  updatedAt: true
});

export type Organization = typeof organizations.$inferSelect;
export type InsertOrganization = z.infer<typeof insertOrganizationSchema>;
export type Department = typeof departments.$inferSelect;
export type InsertDepartment = z.infer<typeof insertDepartmentSchema>;
export type DepartmentWithManager = Department & {
  manager?: Employee | null;
  organization?: Organization | null;
};
export type OrganizationWithDepartments = Organization & {
  departments?: DepartmentWithManager[];
};

export type InsertProject = z.infer<typeof insertProjectSchema>;
export type Project = typeof projects.$inferSelect;
export type InsertTask = z.infer<typeof insertTaskSchema>;
export type Task = typeof tasks.$inferSelect;
export type InsertTimeEntry = z.infer<typeof insertTimeEntrySchema>;
export type TimeEntry = typeof timeEntries.$inferSelect;

// Extended types for API responses
export type TimeEntryWithProject = TimeEntry & {
  project: Project;
  task?: Task | null;
};

export type ProjectWithTimeEntries = Project & {
  timeEntries: TimeEntry[];
  tasks: Task[];
};

export type TaskWithProject = Task & {
  project: Project;
};

export type ProjectWithEmployees = Project & {
  assignedEmployees?: Employee[];
};