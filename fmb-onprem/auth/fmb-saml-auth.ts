
import type { Express, RequestHandler } from "express";
import session from "express-session";
import passport from "passport";
import { Strategy as SamlStrategy } from "passport-saml";
import { getFmbStorage } from "../config/fmb-database.js";
import { loadFmbOnPremConfig } from "../config/fmb-env";

// Enhanced logging utility
function authLog(level: 'INFO' | 'WARN' | 'ERROR' | 'DEBUG', message: string, data?: any) {
  const timestamp = new Date().toISOString();
  const emoji = level === 'ERROR' ? '🔴' : level === 'WARN' ? '🟡' : level === 'INFO' ? '🔵' : '🟢';
  const logMessage = `${timestamp} ${emoji} [FMB-SAML] ${message}`;
  
  if (data) {
    console.log(logMessage, typeof data === 'object' ? JSON.stringify(data, null, 2) : data);
  } else {
    console.log(logMessage);
  }
}

export async function setupFmbSamlAuth(app: Express) {
  authLog('INFO', 'Initializing FMB SAML Authentication...');
  
  const config = loadFmbOnPremConfig();
  
  // Setup session management
  const sessionTtl = 7 * 24 * 60 * 60 * 1000; // 1 week
  
  app.use(session({
    secret: config.app.sessionSecret,
    resave: false,
    saveUninitialized: false,
    cookie: {
      httpOnly: true,
      secure: false, // Set to true in production with HTTPS
      maxAge: sessionTtl,
      sameSite: 'lax',
    },
    name: 'fmb.timetracker.sid',
  }));

  app.use(passport.initialize());
  app.use(passport.session());

  // Configure SAML strategy
  const samlStrategy = new SamlStrategy(
    {
      entryPoint: config.saml.ssoUrl,
      issuer: config.saml.entityId,
      callbackUrl: config.saml.acsUrl,
      cert: config.saml.certificate,
      validateInResponseTo: false,
      disableRequestedAuthnContext: true,
    },
    async (profile: any, done: any) => {
      try {
        authLog('INFO', 'SAML authentication successful', {
          nameID: profile.nameID,
          email: profile.email || profile.nameID,
          firstName: profile.firstName,
          lastName: profile.lastName
        });

        // Create/update user in storage
        const user = {
          id: profile.nameID,
          email: profile.email || profile.nameID,
          firstName: profile.firstName || 'Unknown',
          lastName: profile.lastName || 'User',
          profileImageUrl: null,
        };

        const fmbStorage = getFmbStorage();
        await fmbStorage.upsertUser(user);
        
        return done(null, user);
      } catch (error) {
        authLog('ERROR', 'Error processing SAML profile:', error);
        return done(error);
      }
    }
  );

  passport.use(samlStrategy);

  passport.serializeUser((user: any, done) => {
    done(null, user.id);
  });

  passport.deserializeUser(async (id: string, done) => {
    try {
      const fmbStorage = getFmbStorage();
      const user = await fmbStorage.getUser(id);
      done(null, user);
    } catch (error) {
      done(error);
    }
  });

  // SAML routes
  app.get('/api/login', passport.authenticate('saml', {
    failureRedirect: '/login-error',
    failureFlash: true
  }));

  app.post('/saml/acs', passport.authenticate('saml', {
    failureRedirect: '/login-error',
    successRedirect: '/'
  }));

  app.get('/api/logout', (req, res) => {
    req.logout(() => {
      res.redirect('/');
    });
  });

  authLog('INFO', 'FMB SAML Authentication configured successfully');
}

export const isAuthenticated: RequestHandler = async (req, res, next) => {
  try {
    authLog('DEBUG', `Authentication check for ${req.method} ${req.path}`, {
      ip: req.ip,
      userAgent: req.get('User-Agent'),
      sessionId: req.sessionID,
      hasSession: !!req.session,
      isAuthenticated: req.isAuthenticated ? req.isAuthenticated() : false
    });

    // CRITICAL SECURITY: Only allow test user in development mode
    if (process.env.NODE_ENV === 'development' && (!req.isAuthenticated() || !req.user)) {
      authLog('DEBUG', 'Development mode: Creating test admin user');
      authLog('WARN', 'SECURITY: Authentication bypass active - DO NOT USE IN PRODUCTION');
      
      // Create a mock authenticated user for testing
      const testUser = {
        id: "test-admin-user",
        email: "admin@test.com",
        firstName: "Test",
        lastName: "Admin",
        profileImageUrl: null,
      };
      
      req.user = testUser;
      
      // Ensure the test user exists in database
      try {
        const fmbStorage = getFmbStorage();
        await fmbStorage.upsertUser(testUser);
        
        // In development mode, respect the current database role instead of forcing admin
        const currentUser = await fmbStorage.getUser("test-admin-user");
        const currentRole = currentUser?.role || "admin";
        
        // Only set admin role if user doesn't exist or has no role
        if (!currentUser || !currentUser.role) {
          await fmbStorage.updateUserRole("test-admin-user", "admin");
          authLog('INFO', 'Test admin user authenticated successfully');
        } else {
          authLog('INFO', `Test user authenticated with current role: ${currentRole}`);
        }
      } catch (dbError) {
        authLog('ERROR', 'Failed to setup test user:', dbError);
      }
      
      return next();
    }

    if (!req.isAuthenticated() || !req.user) {
      authLog('WARN', 'Unauthorized access attempt', {
        path: req.path,
        method: req.method,
        ip: req.ip,
        userAgent: req.get('User-Agent'),
        sessionId: req.sessionID
      });
      return res.status(401).json({ message: "Unauthorized" });
    }

    const user = req.user as any;
    authLog('DEBUG', 'User authenticated', {
      userId: user.id || 'unknown',
      email: user.email || 'unknown',
      sessionId: req.sessionID
    });

    authLog('DEBUG', 'Authentication successful, proceeding to next middleware');
    return next();
    
  } catch (error) {
    authLog('ERROR', 'Authentication middleware error:', {
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
