# Database — Supabase migrations workflow

Every schema change in venn — adding a column, creating a table, writing an RLS policy, defining an RPC — is checked into git as a SQL migration under `supabase/migrations/`. We never edit the database directly through the Supabase dashboard except for one-off debugging on a throwaway environment.

This doc walks you through the day-to-day workflow.

---

## Why migrations

Without migrations, a few months in nobody knows what state any environment is in. Three people make schema changes, two of them forget to write them down, and "production" and "the schema in `docs/`" silently drift. Migrations make the schema a tracked, reviewable, replayable artifact:

- **Reproducible** — fresh laptops, CI runs, and new environments get the same schema by replaying the same files.
- **Reviewable** — a schema change is a SQL file in a PR; reviewers see it next to the application code that depends on it.
- **Auditable** — `git log supabase/migrations/` is the history of every schema change.
- **Shareable** — when somebody breaks something, the rest of us can `npm run db:reset` and reproduce.

---

## What lives where

```
supabase/
├── config.toml                  Local-dev Supabase config (Docker ports, etc.)
├── .gitignore                   Ignores .branches and .temp
├── migrations/
│   └── 20260425120000_init.sql  Each schema change is its own timestamped file
└── seed.sql                     Local-dev test data (committed)
```

The corresponding TypeScript types are auto-generated to `packages/shared/src/database.types.ts`. Import them as `import type { Database } from '@venn/shared'`.

---

## One-time setup (per developer)

You need Docker running (for the local Postgres) and the Supabase CLI (already installed via `npm install` as `supabase` in devDependencies).

To work against the real Supabase project, link your local CLI to it once:

```bash
npx supabase login
npx supabase link --project-ref hpnpcwndxyhpazgkmxdy
```

`hpnpcwndxyhpazgkmxdy` is the venn Supabase project ref (same as in the dashboard URL). Linking caches credentials in `supabase/.temp/` (gitignored).

---

## Day-to-day commands

All wired into npm scripts at the repo root.

| Command                  | What it does                                                                                                                         |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------ |
| `npm run db:start`       | Spin up a local Postgres + Supabase stack via Docker. Mirrors prod versions.                                                         |
| `npm run db:stop`        | Shut it down.                                                                                                                        |
| `npm run db:reset`       | Wipe the local DB, replay all migrations, then run `seed.sql`. The "redo it from scratch" button.                                    |
| `npm run db:new <name>`  | Create a new empty migration file (`migrations/<timestamp>_<name>.sql`). Edit, then run `db:reset` to apply locally.                 |
| `npm run db:diff <name>` | Auto-generate a migration capturing the diff between local and migrations/. Useful when you've made changes via the local Studio UI. |
| `npm run db:types`       | Regenerate `packages/shared/src/database.types.ts` from the linked remote schema.                                                    |
| `npm run db:push`        | Apply all pending migrations to the linked remote (production). Usually done after PR merge, manually for now.                       |
| `npm run db:pull`        | Pull the linked remote schema into a new migration. Use when reconciling with manual changes that bypassed migrations.               |

---

## Workflow: making a schema change

1. **Branch.** `git checkout -b feat/<name>`.
2. **Create the migration.** `npm run db:new add_likes_table` — opens an empty SQL file under `supabase/migrations/`.
3. **Write the SQL.** Add columns, tables, indexes, policies. Make it idempotent (`CREATE TABLE IF NOT EXISTS`, `DROP POLICY IF EXISTS` then `CREATE POLICY`) so it can replay safely.
4. **Apply locally.** `npm run db:reset` — wipes local DB and applies all migrations in order. If the migration is wrong, you'll find out here.
5. **Regenerate types.** `npm run db:types` — updates `packages/shared/src/database.types.ts` so TypeScript knows about the new shape. Commit this file alongside the migration.
6. **Write the application code.** Service, hook, screen — using the new types.
7. **Verify.** `npm run verify`.
8. **Open the PR.** Reviewer sees migration + types + code in one place.
9. **After merge.** Someone with credentials runs `npm run db:push` to apply migrations to the live database. (We'll automate this with a GitHub Action when the team grows.)

---

## Rules

These come from [`CLAUDE.md`](../CLAUDE.md):

- **Never edit the production database manually.** Every schema change is a migration file in a PR. The dashboard SQL editor is for read-only debugging only.
- **Migrations are append-only.** Don't edit a migration that's already been merged; write a new one that fixes the previous one. (Past migrations are part of the replayable history and rewriting them breaks everyone else's local DB on the next reset.)
- **Every user-typed column gets a CHECK constraint** that mirrors the bounds in `apps/mobile/src/utils/sanitize.ts`. The schemas there are the first line of defence; the Postgres constraints are the last.
- **Every new table starts with RLS enabled.** No exceptions. Then write the explicit policies that allow what you actually want.
- **Regenerate types in the same PR as the migration.** A PR with a migration but no `database.types.ts` update is incomplete.

---

## Reconciling with the existing prod DB

The first migration (`20260425120000_init.sql`) is a faithful copy of the SQL block in [`docs/SUPABASE_SETUP.md`](./SUPABASE_SETUP.md), with the same idempotency guards added (`IF NOT EXISTS`, `DROP POLICY IF EXISTS`). It's safe to apply against a Supabase project that was already initialized via the legacy SQL — every statement is a no-op when the object already exists, except for the new sanitization CHECK constraints which will be added.

If you've made schema changes through the dashboard that aren't yet in migrations/, run `npm run db:pull` once to capture them as a new migration before continuing.

---

## Troubleshooting

<details>
<summary><strong>"Cannot connect to the Docker daemon"</strong></summary>

Start Docker Desktop. The Supabase CLI requires Docker for `db:start` and `db:reset`.

</details>

<details>
<summary><strong>"Migration version 20260425120000 is already applied"</strong></summary>

Local state is out of sync with the migrations folder. Run `npm run db:reset` to wipe and replay.

</details>

<details>
<summary><strong>"`db:types` produces an empty file"</strong></summary>

You haven't linked the project. Run `npx supabase login` and `npx supabase link --project-ref hpnpcwndxyhpazgkmxdy`.

</details>

<details>
<summary><strong>"`db:push` says it applied a migration but the dashboard still shows the old schema"</strong></summary>

Refresh the Supabase dashboard. Schema changes are reflected immediately in the API but the dashboard sometimes caches.

</details>
