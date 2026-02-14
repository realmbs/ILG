#!/usr/bin/env node

/**
 * ILG Database Initialization
 * Creates SQLite database and applies schema.
 * Safe to run multiple times (uses IF NOT EXISTS).
 *
 * Usage: node db/init.js
 */

import { readFileSync } from 'fs';
import { resolve, dirname } from 'path';
import { fileURLToPath } from 'url';
import Database from 'better-sqlite3';

const __dirname = dirname(fileURLToPath(import.meta.url));
const DB_PATH = process.env.DB_PATH || resolve(__dirname, 'ilg.db');
const SCHEMA_PATH = resolve(__dirname, 'schema.sql');

console.log(`Initializing database at: ${DB_PATH}`);

const db = new Database(DB_PATH);
const schema = readFileSync(SCHEMA_PATH, 'utf-8');

// Execute the full schema file — better-sqlite3's exec handles multiple statements
try {
  db.exec(schema);
} catch (err) {
  console.error('Error executing schema:');
  console.error(err.message);
  process.exit(1);
}

// Verify tables were created
const tables = db
  .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' ORDER BY name")
  .all();

console.log(`\nCreated ${tables.length} tables:`);
tables.forEach(t => console.log(`  - ${t.name}`));

const indexes = db
  .prepare("SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_%' ORDER BY name")
  .all();

console.log(`\nCreated ${indexes.length} indexes:`);
indexes.forEach(i => console.log(`  - ${i.name}`));

db.close();
console.log('\nDatabase initialization complete.');
