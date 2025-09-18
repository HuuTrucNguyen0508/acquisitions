import 'dotenv/config';

import { neon, neonConfig } from '@neondatabase/serverless';
import { drizzle } from 'drizzle-orm/neon-http';

// Configure Neon based on environment
if (process.env.NODE_ENV === 'development') {
    // Configuration for Neon Local (development)
    neonConfig.fetchEndpoint = 'http://neon-local:5432/sql';
    neonConfig.useSecureWebSocket = false;
    neonConfig.poolQueryViaFetch = true;
} else {
    // Configuration for Neon Cloud (production)
    // Use default settings for production
    neonConfig.useSecureWebSocket = true;
    neonConfig.poolQueryViaFetch = true;
}

// Validate DATABASE_URL
if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL environment variable is required');
}

const sql = neon(process.env.DATABASE_URL);

const db = drizzle(sql);

export { db, sql };
