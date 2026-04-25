#!/usr/bin/env node
// Health-check for your local dev environment. Run any time things feel off,
// or before opening a PR. Catches the silent failure modes that look like
// "everything is fine" but actually aren't (e.g., husky hooks not wired,
// wrong Node version, .env missing or still has placeholders).
//
// Usage:
//   npm run doctor
//
// Exits non-zero if any check fails, so you can wire this into CI or other
// scripts (it's already part of `npm run verify`).

import { execSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';

const failures = [];
const warnings = [];

function ok(msg) {
  console.log(`  ok    ${msg}`);
}

function warn(msg, fix) {
  console.warn(`  warn  ${msg}`);
  if (fix) console.warn(`        fix: ${fix}`);
  warnings.push(msg);
}

function fail(msg, fix) {
  console.error(`  FAIL  ${msg}`);
  if (fix) console.error(`        fix: ${fix}`);
  failures.push(msg);
}

console.log('\nvenn doctor — checking your dev environment\n');

// --- Node version matches .nvmrc ---------------------------------------------
try {
  const expected = readFileSync('.nvmrc', 'utf8').trim();
  const current = process.version.replace(/^v/, '');
  if (current === expected) {
    ok(`Node ${current} matches .nvmrc`);
  } else {
    fail(`Node ${current} but .nvmrc wants ${expected}`, 'nvm use');
  }
} catch {
  fail('could not read .nvmrc', 'are you running this from the repo root?');
}

// --- Husky git hooks are wired -----------------------------------------------
let hooksPath = '';
try {
  hooksPath = execSync('git config --get core.hooksPath', {
    stdio: ['ignore', 'pipe', 'ignore'],
  })
    .toString()
    .trim();
} catch {
  // not set — handled below
}

if (hooksPath === '.husky/_' || hooksPath === '.husky') {
  ok(`husky hooks wired (core.hooksPath=${hooksPath})`);
} else {
  fail(
    `husky hooks not wired (core.hooksPath=${hooksPath || 'unset'}); commit-msg + pre-commit will silently NOT run`,
    'npm run prepare',
  );
}

// --- apps/mobile/.env exists and has real values -----------------------------
const envPath = 'apps/mobile/.env';
if (existsSync(envPath)) {
  const env = readFileSync(envPath, 'utf8');
  if (env.includes('YOUR_PROJECT') || env.includes('YOUR_ANON_KEY')) {
    warn(
      `${envPath} still has placeholder values`,
      'paste your real Supabase URL and anon key in (see docs/SUPABASE_SETUP.md)',
    );
  } else if (!/EXPO_PUBLIC_SUPABASE_URL=https?:\/\//.test(env)) {
    warn(`${envPath} present but EXPO_PUBLIC_SUPABASE_URL looks empty or malformed`);
  } else {
    ok(`${envPath} present`);
  }
} else {
  fail(
    `${envPath} is missing`,
    'cp apps/mobile/.env.example apps/mobile/.env, then add Supabase creds',
  );
}

// --- Summary -----------------------------------------------------------------
console.log('');
if (failures.length) {
  console.error(`${failures.length} check(s) failed.`);
  if (warnings.length) console.error(`${warnings.length} warning(s).`);
  console.error('Fix the failures above and re-run `npm run doctor`.');
  process.exit(1);
}
if (warnings.length) {
  console.warn(`all required checks passed, with ${warnings.length} warning(s) above.`);
} else {
  console.log('all good.');
}
