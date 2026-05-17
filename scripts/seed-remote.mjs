#!/usr/bin/env node
// =============================================================================
// seed-remote.mjs — apply supabase/seed.sql against the remote DB.
// =============================================================================
// Local db:reset auto-runs seed.sql after migrations, but for the remote
// there's no equivalent — supabase db push only applies migrations.
// During early development (no real users yet, RLS-public-read) this
// script wires the same seed file to the remote via SUPABASE_DB_URL,
// using the `pg` driver to avoid a `psql` dependency.
//
// Re-run is idempotent — seed.sql uses ON CONFLICT DO NOTHING.
//
// Run via `npm run db:seed` (which loads .env automatically).
// =============================================================================

import pg from "pg";
import { readFileSync } from "node:fs";

const SEED_FILE = "supabase/seed.sql";

const dbUrl = process.env.SUPABASE_DB_URL;
if (!dbUrl) {
  console.error(
    "error: SUPABASE_DB_URL is not set. Add it to .env (see .env.example) " +
      "and run `npm run db:seed` again."
  );
  process.exit(1);
}

const sql = readFileSync(SEED_FILE, "utf8");

const client = new pg.Client({ connectionString: dbUrl });
await client.connect();

try {
  await client.query(sql);
  console.log(`applied ${SEED_FILE} to remote.`);
} finally {
  await client.end();
}
