import sql from 'mssql';
import { loadFmbOnPremConfig } from './fmb-env.js';
import { FmbStorage } from '../storage/fmb-storage.js';

let pool: sql.ConnectionPool | null = null;
let db: any = null;
let fmbStorage: FmbStorage | null = null;

export async function initializeFmbDatabase() {
  console.log('🔧 Initializing FMB on-premises MS SQL database...');

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
    console.log('✅ FMB MS SQL database connected successfully');
  } catch (error) {
    console.error('❌ Failed to connect to FMB database:', error);
    throw error;
  }
}

export function getFmbStorage(): FmbStorage {
  if (!fmbStorage) {
    throw new Error('FMB database not initialized. Call initializeFmbDatabase() first.');
  }
  return fmbStorage;
}

export async function closeFmbDatabase() {
  if (pool) {
    await pool.close();
    pool = null;
    db = null;
    console.log('✅ [FMB-DATABASE] MS SQL Server connection closed');
  }
  if (fmbStorage) {
    await fmbStorage.disconnect();
    fmbStorage = null;
    console.log('✅ [FMB-DATABASE] FMB database connection closed');
  }
}

export { pool as fmbPool, db as fmbDb };

// Database health check for on-prem
export async function checkFmbDatabaseHealth(): Promise<boolean> {
  try {
    if (!fmbStorage) {
      await initializeFmbDatabase();
    }

    // Assuming FmbStorage has a method to check health, e.g., execute a simple query
    // This is a placeholder and should be adapted based on FmbStorage implementation
    const result = await fmbStorage!.execute('SELECT 1 as health');
    return result.length > 0;
  } catch (error) {
    console.error('🔴 [FMB-DATABASE] Health check failed:', error);
    return false;
  }
}

// Raw SQL query helper for MS SQL
export async function executeFmbQuery(query: string, params: any[] = []): Promise<any> {
  try {
    if (!fmbStorage) {
      await initializeFmbDatabase();
    }

    // Assuming FmbStorage has an execute method that accepts query and parameters
    // This is a placeholder and should be adapted based on FmbStorage implementation
    const result = await fmbStorage!.execute(query, params);
    return result;
  } catch (error) {
    console.error('🔴 [FMB-DATABASE] Query execution failed:', error);
    throw error;
  }
}
