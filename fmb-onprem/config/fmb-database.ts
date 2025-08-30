import sql from 'mssql';
import { loadFmbOnPremConfig } from './fmb-env.js';
import { FmbStorage } from '../storage/fmb-storage.js';

let pool: sql.ConnectionPool | null = null;
let db: any = null;
let fmbStorageInstance: FmbStorage | null = null;

export async function initializeFmbDatabase() {
  console.log('🔧 Initializing FMB on-premises MS SQL database...');

  const config = loadFmbOnPremConfig();

  fmbStorageInstance = new FmbStorage({
    server: config.database.server,
    database: config.database.database,
    user: config.database.user,
    password: config.database.password,
    options: {
      port: parseInt(config.database.port),
      enableArithAbort: true,
      connectTimeout: 30000,
      requestTimeout: 30000
    },
    encrypt: config.database.encrypt,
    trustServerCertificate: config.database.trustServerCertificate,
  });

  try {
    await fmbStorageInstance.connect();
    console.log('✅ FMB MS SQL database connected successfully');
  } catch (error) {
    console.error('❌ Failed to connect to FMB database:', error);
    throw error;
  }
}

export function getFmbStorage(): import('../../server/storage.js').IStorage {
  if (!fmbStorageInstance) {
    console.log('🔧 [FMB-DATABASE] Creating new FMB storage instance...');
    const config = loadFmbOnPremConfig();
    fmbStorageInstance = new FmbStorage({
      server: config.FMB_DB_SERVER,
      database: config.FMB_DB_NAME,
      user: config.FMB_DB_USER,
      password: config.FMB_DB_PASSWORD,
      options: {
        port: config.FMB_DB_PORT,
        enableArithAbort: true,
        connectTimeout: 30000,
        requestTimeout: 30000,
      },
      encrypt: config.FMB_DB_ENCRYPT,
      trustServerCertificate: config.FMB_DB_TRUST_CERT,
    });

    // Auto-connect to database
    fmbStorageInstance.connect().catch(error => {
      console.error('❌ [FMB-DATABASE] Failed to connect to FMB database:', error);
    });
  }

  return fmbStorageInstance as import('../../server/storage.js').IStorage;
}

// Export the storage instance directly for compatibility
export { fmbStorageInstance as activeStorage };

export async function closeFmbDatabase() {
  if (pool) {
    await pool.close();
    pool = null;
    db = null;
    console.log('✅ [FMB-DATABASE] MS SQL Server connection closed');
  }
  if (fmbStorageInstance) {
    await fmbStorageInstance.disconnect();
    fmbStorageInstance = null;
    console.log('✅ [FMB-DATABASE] FMB database connection closed');
  }
}

export { pool as fmbPool, db as fmbDb };

// Database health check for on-prem
export async function checkFmbDatabaseHealth(): Promise<boolean> {
  try {
    if (!fmbStorageInstance) {
      await initializeFmbDatabase();
    }

    // Assuming FmbStorage has a method to check health, e.g., execute a simple query
    // This is a placeholder and should be adapted based on FmbStorage implementation
    const result = await fmbStorageInstance!.execute('SELECT 1 as health');
    return result.length > 0;
  } catch (error) {
    console.error('🔴 [FMB-DATABASE] Health check failed:', error);
    return false;
  }
}

// Raw SQL query helper for MS SQL
export async function executeFmbQuery(query: string, params: any[] = []): Promise<any> {
  try {
    if (!fmbStorageInstance) {
      await initializeFmbDatabase();
    }

    // Assuming FmbStorage has an execute method that accepts query and parameters
    // This is a placeholder and should be adapted based on FmbStorage implementation
    const result = await fmbStorageInstance!.execute(query, params);
    return result;
  } catch (error) {
    console.error('🔴 [FMB-DATABASE] Query execution failed:', error);
    throw error;
  }
}
