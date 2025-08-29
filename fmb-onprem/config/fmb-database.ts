
/**
 * FMB On-Premises MS SQL Server Database Configuration
 */

import sql from 'mssql';
import { loadFmbOnPremConfig } from './fmb-env.js';

let pool: sql.ConnectionPool | null = null;
let db: any = null;

export async function initializeFmbDatabase() {
  if (pool) {
    return { pool, db };
  }

  const config = loadFmbOnPremConfig();
  
  const sqlConfig: sql.config = {
    server: config.database.server,
    database: config.database.database,
    user: config.database.user,
    password: config.database.password,
    port: config.database.port,
    options: {
      encrypt: config.database.encrypt,
      trustServerCertificate: config.database.trustServerCertificate,
      enableArithAbort: true,
    },
    pool: {
      max: 20,
      min: 0,
      idleTimeoutMillis: 30000,
    },
    connectionTimeout: 15000,
    requestTimeout: 15000,
  };

  try {
    pool = new sql.ConnectionPool(sqlConfig);
    await pool.connect();
    
    console.log('✅ [FMB-DATABASE] Connected to MS SQL Server successfully');
    console.log(`✅ [FMB-DATABASE] Server: ${config.database.server}, Database: ${config.database.database}`);
    
    // For now, we'll use raw SQL queries until we can properly adapt Drizzle for MS SQL
    // TODO: Implement proper MS SQL adapter for Drizzle ORM
    db = pool;
    
    return { pool, db };
  } catch (error) {
    console.error('🔴 [FMB-DATABASE] Failed to connect to MS SQL Server:', error);
    throw error;
  }
}

export async function closeFmbDatabase() {
  if (pool) {
    await pool.close();
    pool = null;
    db = null;
    console.log('✅ [FMB-DATABASE] MS SQL Server connection closed');
  }
}

export { pool as fmbPool, db as fmbDb };

// Database health check for on-prem
export async function checkFmbDatabaseHealth(): Promise<boolean> {
  try {
    if (!pool) {
      await initializeFmbDatabase();
    }
    
    const result = await pool!.request().query('SELECT 1 as health');
    return result.recordset.length > 0;
  } catch (error) {
    console.error('🔴 [FMB-DATABASE] Health check failed:', error);
    return false;
  }
}

// Raw SQL query helper for MS SQL
export async function executeFmbQuery(query: string, params: any[] = []): Promise<any> {
  try {
    if (!pool) {
      await initializeFmbDatabase();
    }
    
    const request = pool!.request();
    
    // Add parameters if provided
    params.forEach((param, index) => {
      request.input(`param${index}`, param);
    });
    
    const result = await request.query(query);
    return result.recordset;
  } catch (error) {
    console.error('🔴 [FMB-DATABASE] Query execution failed:', error);
    throw error;
  }
}
