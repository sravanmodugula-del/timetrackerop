// Load environment variables first
import dotenv from 'dotenv';
dotenv.config();

// Import FMB on-prem configuration if running on-prem
import { isFmbOnPremEnvironment } from '../fmb-onprem/config/fmb-env.js';
// Import on-prem specific service initializers
import { initializeFmbDatabase, getFmbStorage } from '../fmb-onprem/config/fmb-database.js';

import express, { type Request, Response, NextFunction } from "express";
import { registerRoutes } from "./routes";
import { serveStatic, log } from "./vite";

// Import storage correctly
import { storage } from "./storage";

// Log levels for enhanced logging
const LOG_LEVELS = {
  ERROR: "🔴 ERROR",
  WARN: "🟡 WARN", 
  INFO: "🔵 INFO",
  DEBUG: "🟢 DEBUG"
};

// Enhanced logging utility
function enhancedLog(level: keyof typeof LOG_LEVELS, category: string, message: string, data?: any) {
  const timestamp = new Date().toISOString();
  const logMessage = `${timestamp} ${LOG_LEVELS[level]} [${category}] ${message}`;

  if (data) {
    console.log(logMessage, typeof data === 'object' ? JSON.stringify(data, null, 2) : data);
  } else {
    console.log(logMessage);
  }
}

// Get the appropriate storage instance based on environment
function getActiveStorage() {
  if (isFmbOnPremEnvironment() && process.env.NODE_ENV === "production") {
    try {
      return getFmbStorage();
    } catch (error) {
      enhancedLog("WARN", "STORAGE", "FMB storage not available, falling back to default storage");
      return storage;
    }
  }
  return storage;
}

// Import setupVite
import { setupVite } from "./vite";

// Import authentication functions from replitAuth
import { isAuthenticated } from "./replitAuth";
import { setupAuth } from "./replitAuth";

// Helper function to get current user from request
const getCurrentUser = (req: Request) => {
  const user = req.user as any;
  return {
    id: user?.claims?.sub || user?.id || 'unknown',
    email: user?.claims?.email || user?.email || 'unknown',
    name: `${user?.claims?.first_name || user?.firstName || ''} ${user?.claims?.last_name || user?.lastName || ''}`.trim()
  };
};


// Enhanced global error handlers with database resilience
process.on('uncaughtException', (error) => {
  enhancedLog('ERROR', 'PROCESS', 'Uncaught Exception:', {
    message: error.message,
    stack: error.stack,
    name: error.name
  });

  // Check if it's a database connection error
  if (error.message.includes('terminating connection') ||
      error.message.includes('database') ||
      error.message.includes('connection')) {
    enhancedLog('WARN', 'DATABASE', 'Database connection error detected - attempting recovery...');

    // Don't exit immediately for database errors - let the connection pool recover
    setTimeout(() => {
      enhancedLog('INFO', 'PROCESS', 'Database error recovery timeout reached');
    }, 10000);

    return; // Don't exit for database connection errors
  }

  // For non-database critical errors, still exit
  enhancedLog('ERROR', 'PROCESS', 'Critical error - shutting down server');
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  const isDbError = reason instanceof Error &&
    (reason.message.includes('terminating connection') ||
     reason.message.includes('database') ||
     reason.message.includes('connection'));

  enhancedLog(isDbError ? 'WARN' : 'ERROR', 'PROCESS', 'Unhandled Rejection:', {
    reason: reason instanceof Error ? {
      message: reason.message,
      stack: reason.stack,
      name: reason.name
    } : reason,
    promise: promise.toString(),
    isDatabaseError: isDbError
  });

  if (!isDbError) {
    enhancedLog('ERROR', 'PROCESS', 'Critical unhandled rejection - shutting down server');
    process.exit(1);
  } else {
    enhancedLog('INFO', 'PROCESS', 'Database error - continuing operation with connection recovery');
  }
});

// Environment validation and setup
function validateProductionEnvironment() {
  let required: string[];

  if (isFmbOnPremEnvironment()) {
    // FMB on-premises environment validation
    required = ['NODE_ENV', 'FMB_SESSION_SECRET', 'FMB_DB_SERVER', 'FMB_DB_NAME', 'FMB_SAML_ENTITY_ID', 'FMB_SAML_SSO_URL', 'FMB_SAML_CERTIFICATE'];
    enhancedLog('INFO', 'ENV', '🏢 Running in FMB on-premises mode');
  } else {
    // Replit environment validation
    required = ['NODE_ENV', 'SESSION_SECRET', 'REPL_ID', 'REPLIT_DOMAINS', 'DATABASE_URL'];
    enhancedLog('INFO', 'ENV', '☁️ Running in Replit cloud mode');
  }

  const missing = required.filter(varName => !process.env[varName]);

  if (missing.length > 0) {
    enhancedLog('ERROR', 'ENV', `Missing required environment variables: ${missing.join(', ')}`);
    enhancedLog('ERROR', 'ENV', 'Please check your environment configuration and .env.example file');
    process.exit(1);
  }

  // Validate NODE_ENV specifically
  if (!process.env.NODE_ENV) {
    enhancedLog('ERROR', 'ENV', 'NODE_ENV must be explicitly set to "production" or "development"');
    process.exit(1);
  }

  if (process.env.NODE_ENV !== 'production' && process.env.NODE_ENV !== 'development') {
    enhancedLog('WARN', 'ENV', `Unknown NODE_ENV: ${process.env.NODE_ENV}. Expected "production" or "development"`);
  }

  if (process.env.NODE_ENV !== 'production') {
    enhancedLog('WARN', 'ENV', '⚠️  WARNING: Running in non-production mode with authentication bypass enabled');
  } else {
    enhancedLog('INFO', 'ENV', '✅ Production mode enabled - authentication bypass disabled');
  }

  // Validate SESSION_SECRET strength for production
  if (process.env.NODE_ENV === 'production' && process.env.SESSION_SECRET && process.env.SESSION_SECRET.length < 32) {
    enhancedLog('WARN', 'ENV', '⚠️  WARNING: SESSION_SECRET should be at least 32 characters for production');
  }

  // Additional on-prem validation can be added here if needed

  enhancedLog('INFO', 'ENV', 'Environment validation completed successfully');
}

// Set timezone
process.env.TZ = process.env.TZ || "America/Los_Angeles";
enhancedLog('INFO', 'TIMEZONE', `Set timezone to ${process.env.TZ}`);

// Validate environment before starting application
validateProductionEnvironment();

async function startServer() {
  const app = express();

  // Enhanced middleware for better request handling
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true, limit: '10mb' }));

  // Initialize authentication system
  if (!isFmbOnPremEnvironment()) {
    enhancedLog('INFO', 'REPLIT', 'Setting up Replit Authentication for development...');
    await setupAuth(app);
  } else if (isFmbOnPremEnvironment() && process.env.NODE_ENV === 'production') {
    enhancedLog('INFO', 'FMB-ONPREM', 'Initializing on-premises services for production deployment...');

    // Temporary bypass for testing - set FMB_SKIP_DB=true to skip database connection
    if (process.env.FMB_SKIP_DB === 'true') {
      enhancedLog('WARN', 'FMB-ONPREM', 'Database connection skipped for testing (FMB_SKIP_DB=true)');
    } else {
      try {
        await initializeFmbDatabase();
        enhancedLog('INFO', 'FMB-ONPREM', 'On-premises services initialized successfully');
      } catch (error) {
        enhancedLog('ERROR', 'FMB-ONPREM', 'Failed to initialize on-premises services:', error);
        enhancedLog('ERROR', 'FMB-ONPREM', 'Database connection failed - check credentials and network access');
        process.exit(1);
      }
    }
  } else if (isFmbOnPremEnvironment() && process.env.NODE_ENV === 'development') {
    enhancedLog('INFO', 'FMB-ONPREM', 'Development mode: Skipping MS SQL connection, using Replit PostgreSQL');
  }

  // Security middleware (production-ready)
  if (process.env.NODE_ENV === 'production') {
    // Trust proxy for production load balancers
    app.set('trust proxy', 1);

    // Production security headers with HTTPS enforcement
    app.use((req, res, next) => {
      res.setHeader('X-Content-Type-Options', 'nosniff');
      res.setHeader('X-Frame-Options', 'DENY');
      res.setHeader('X-XSS-Protection', '1; mode=block');
      res.setHeader('Referrer-Policy', 'strict-origin-when-cross-origin');
      res.setHeader('Permissions-Policy', 'camera=(), microphone=(), geolocation=()');
      res.setHeader('Strict-Transport-Security', 'max-age=31536000; includeSubDomains; preload');
      res.setHeader('Content-Security-Policy', "upgrade-insecure-requests");
      next();
    });

    // Redirect HTTP to HTTPS for FMB on-premises (fallback if IIS doesn't handle it)
    if (isFmbOnPremEnvironment()) {
      app.use((req, res, next) => {
        if (req.header('x-forwarded-proto') !== 'https' && req.hostname !== 'localhost') {
          return res.redirect(301, `https://${req.hostname}${req.url}`);
        }
        next();
      });
    }
  }

  app.use((req, res, next) => {
    const start = Date.now();
    const path = req.path;
    let capturedJsonResponse: Record<string, any> | undefined = undefined;

    // Enhanced request logging
    if (path.startsWith("/api")) {
      enhancedLog('DEBUG', 'REQUEST', `Incoming ${req.method} ${path}`, {
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        query: req.query,
        body: req.method !== 'GET' && req.body ? req.body : undefined,
        sessionId: req.sessionID,
        authenticated: req.isAuthenticated ? req.isAuthenticated() : false
      });
    }

    const originalResJson = res.json;
    res.json = function (bodyJson, ...args) {
      capturedJsonResponse = bodyJson;
      return originalResJson.apply(res, [bodyJson, ...args]);
    };

    res.on("finish", () => {
      const duration = Date.now() - start;
      if (path.startsWith("/api")) {
        let logLine = `${req.method} ${path} ${res.statusCode} in ${duration}ms`;
        if (capturedJsonResponse) {
          logLine += ` :: ${JSON.stringify(capturedJsonResponse)}`;
        }

        if (logLine.length > 80) {
          logLine = logLine.slice(0, 79) + "…";
        }

        log(logLine);

        // Enhanced response logging for errors
        if (res.statusCode >= 400) {
          enhancedLog('ERROR', 'RESPONSE', `Error response for ${req.method} ${path}`, {
            status: res.statusCode,
            duration: `${duration}ms`,
            response: capturedJsonResponse,
            request: {
              query: req.query,
              body: req.body,
              ip: req.ip,
              userAgent: req.get('User-Agent')
            }
          });
        }
      }
    });

    next();
  });

  const server = await registerRoutes(app);

  // Dashboard endpoints
  app.get("/api/dashboard/stats", isAuthenticated, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const { startDate, endDate } = req.query;

      const activeStorage = getActiveStorage();
      const stats = await activeStorage.getDashboardStats(
        user.id,
        startDate as string,
        endDate as string
      );

      res.json(stats);
    } catch (error) {
      console.error("Error fetching dashboard stats:", error);
      res.status(500).json({ message: "Failed to fetch dashboard stats" });
    }
  });

  app.get("/api/dashboard/project-breakdown", isAuthenticated, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const { startDate, endDate } = req.query;

      const activeStorage = getActiveStorage();
      const breakdown = await activeStorage.getProjectTimeBreakdown(
        user.id,
        startDate as string,
        endDate as string
      );

      res.json(breakdown);
    } catch (error) {
      console.error("Error fetching project breakdown:", error);
      res.status(500).json({ message: "Failed to fetch project breakdown" });
    }
  });

  app.get("/api/dashboard/recent-activity", isAuthenticated, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const { startDate, endDate, limit } = req.query;

      const activeStorage = getActiveStorage();
      const activity = await activeStorage.getTimeEntries(
        user.id,
        {
          startDate: startDate as string,
          endDate: endDate as string,
          limit: limit ? parseInt(limit as string) : 10
        }
      );

      res.json(activity);
    } catch (error) {
      console.error("Error fetching recent activity:", error);
      res.status(500).json({ message: "Failed to fetch recent activity" });
    }
  });

  app.get("/api/dashboard/department-hours", isAuthenticated, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const { startDate, endDate } = req.query;

      console.log(`🟢 Fetching department hours for user: ${user.id} dates: ${startDate} ${endDate}`);

      const activeStorage = getActiveStorage();
      const departmentHours = await activeStorage.getDepartmentHoursSummary(
        user.id,
        startDate as string,
        endDate as string
      );

      res.json(departmentHours);
    } catch (error) {
      console.error("❌ Error fetching department hours:", error);
      res.status(500).json({ message: "Failed to fetch department hours" });
    }
  });

  // Projects
  app.get("/api/projects", isAuthenticated, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const activeStorage = getActiveStorage();
      const projects = await activeStorage.getProjects(user.id);
      res.json(projects);
    } catch (error) {
      console.error("Error fetching projects:", error);
      res.status(500).json({ message: "Failed to fetch projects" });
    }
  });

  // Employees
  app.get("/api/employees", isAuthenticated, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const activeStorage = getActiveStorage();
      const employees = await activeStorage.getEmployees();
      res.json(employees);
    } catch (error) {
      console.error("Error fetching employees:", error);
      res.status(500).json({ message: "Failed to fetch employees" });
    }
  });

  // Organizations
  app.get("/api/organizations", isAuthenticated, async (req, res) => {
    try {
      const activeStorage = getActiveStorage();
      const organizations = await activeStorage.getOrganizations();
      res.json(organizations);
    } catch (error) {
      console.error("Error fetching organizations:", error);
      res.status(500).json({ message: "Failed to fetch organizations" });
    }
  });

  app.post("/api/projects", isAuthenticated, async (req, res) => {
    try {
      const user = getCurrentUser(req);
      const activeStorage = getActiveStorage();

      // Add userId to project data for FMB storage
      const projectData = {
        ...req.body,
        userId: user.id
      };

      const project = await activeStorage.createProject(projectData);
      res.json(project);
    } catch (error) {
      console.error("Error creating project:", error);
      if (error instanceof Error && error.message.includes("Insufficient permissions")) {
        res.status(403).json({ message: error.message });
      } else {
        res.status(500).json({ message: "Failed to create project" });
      }
    }
  });

  app.use((err: any, req: Request, res: Response, _next: NextFunction) => {
    const status = err.status || err.statusCode || 500;
    const message = err.message || "Internal Server Error";

    // Enhanced error logging
    enhancedLog('ERROR', 'EXPRESS', 'Express error middleware triggered:', {
      error: {
        message: err.message,
        stack: err.stack,
        name: err.name,
        code: err.code,
        status: status
      },
      request: {
        method: req.method,
        path: req.path,
        query: req.query,
        body: req.body,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        sessionId: req.sessionID,
        authenticated: req.isAuthenticated ? req.isAuthenticated() : false
      }
    });

    res.status(status).json({
      message,
      error: process.env.NODE_ENV === 'development' ? {
        name: err.name,
        stack: err.stack
      } : undefined
    });
  });

  // importantly only setup vite in development and after
  // setting up all the other routes so the catch-all route
  // doesn't interfere with the other routes
  if (app.get("env") === "development") {
    await setupVite(app, server);
  } else {
    serveStatic(app);
  }

  // Use environment-appropriate ports
  // Replit development: 5000 (forwards to external 80)
  // FMB On-premises: 3000 (for IIS reverse proxy)
  const defaultPort = isFmbOnPremEnvironment() && process.env.NODE_ENV === 'production' ? '3000' : '5000';
  const port = parseInt(process.env.PORT || defaultPort, 10);
  // Configure server options with Windows-compatible settings
  const serverOptions: any = {
    port,
    host: "0.0.0.0",
  };

  // Only add reusePort on non-Windows platforms
  if (process.platform !== 'win32') {
    serverOptions.reusePort = true;
  }

  server.listen(serverOptions, () => {
    enhancedLog('INFO', 'SERVER', `Server started successfully on port ${port}`, {
      port: port,
      environment: process.env.NODE_ENV,
      timezone: process.env.TZ,
      host: "0.0.0.0"
    });
    log(`serving on port ${port}`);
  });
}

// Start the server
startServer().catch((error) => {
  enhancedLog('ERROR', 'STARTUP', 'Failed to start server:', error);
  process.exit(1);
});