/**
 * On-Premises Environment Configuration
 * Loads FMB-specific environment variables and validates on-prem setup
 */

interface FmbOnPremConfig {
  database: {
    server: string;
    database: string;
    name: string;
    user: string;
    password: string;
    port: number;
    encrypt: boolean;
    trustServerCertificate: boolean;
    options: Record<string, any>;
  };
  saml: {
    entityId: string;
    ssoUrl: string;
    certificate: string;
    acsUrl: string;
  };
  app: {
    port: number;
    host: string;
    sessionSecret: string;
    nodeEnv: string;
  };
}

// Helper function to sanitize passwords for logging
function sanitizePassword(password: string): string {
  // Replace all characters except alphanumeric with '*'
  return password.replace(/./g, '*');
}

export function loadFmbOnPremConfig(): FmbOnPremConfig {
  // Validate required environment variables
  const requiredVars = [
    'FMB_DB_SERVER',
    'FMB_DB_NAME', 
    'FMB_DB_USER',
    'FMB_DB_PASSWORD',
    'FMB_SAML_ENTITY_ID',
    'FMB_SAML_SSO_URL',
    'FMB_SAML_CERTIFICATE',
    'FMB_SESSION_SECRET'
  ];

  const missing = requiredVars.filter(varName => !process.env[varName]);
  if (missing.length > 0) {
    throw new Error(`Missing required FMB environment variables: ${missing.join(', ')}`);
  }

  const dbPassword = process.env.FMB_DB_PASSWORD!;
  console.log(`Database password: ${sanitizePassword(dbPassword)}`); // Log sanitized password

  return {
    database: {
      server: process.env.FMB_DB_SERVER!,
      database: process.env.FMB_DB_NAME!,
      name: process.env.FMB_DB_NAME!,
      user: process.env.FMB_DB_USER!,
      password: dbPassword,
      port: parseInt(process.env.FMB_DB_PORT || '1433', 10),
      encrypt: process.env.FMB_DB_ENCRYPT !== 'false',
      trustServerCertificate: process.env.FMB_DB_TRUST_CERT === 'true',
      options: {
        enableArithAbort: true,
        connectTimeout: 30000,
        requestTimeout: 30000
      }
    },
    saml: {
      entityId: process.env.FMB_SAML_ENTITY_ID!,
      ssoUrl: process.env.FMB_SAML_SSO_URL!,
      certificate: process.env.FMB_SAML_CERTIFICATE!,
      acsUrl: process.env.FMB_SAML_ACS_URL || 'https://timetracker.fmb.com/saml/acs'
    },
    app: {
      port: parseInt(process.env.PORT || '3000', 10),
      host: process.env.HOST || '0.0.0.0',
      sessionSecret: process.env.FMB_SESSION_SECRET!,
      nodeEnv: process.env.NODE_ENV || 'production'
    }
  };
}

export function isFmbOnPremEnvironment(): boolean {
  return process.env.FMB_DEPLOYMENT === 'onprem';
}

export function isActualOnPremDeployment(): boolean {
  // Only return true when actually deployed on Windows server with production environment
  return process.env.FMB_DEPLOYMENT === 'onprem' && 
         process.env.NODE_ENV === 'production' &&
         process.platform === 'win32';
}