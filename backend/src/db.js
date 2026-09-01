const { Pool } = require('pg');
const { requiredEnv } = require('./app');

const pool = new Pool({
  host: process.env.PGHOST || '127.0.0.1',
  port: Number(process.env.PGPORT || 5434),
  user: process.env.PGUSER || 'kupuna_user',
  password: requiredEnv('PGPASSWORD'),
  database: process.env.PGDATABASE || 'kupuna_db',
});

const CANONICAL_ROLES = new Set(['customer', 'merchant', 'brand', 'admin', 'agent']);


module.exports = { pool, CANONICAL_ROLES };
