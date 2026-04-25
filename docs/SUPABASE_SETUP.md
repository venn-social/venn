# Setting up the Supabase backend (one-time)

You only do this once for the whole team. The output is a `SUPABASE_URL` and `SUPABASE_ANON_KEY` that everyone pastes into their `.env`.

## 1. Create the project

1. Go to [supabase.com](https://supabase.com) and sign in with GitHub.
2. New project → Name: `venn` → Pick a strong database password (save it in 1Password). Pick a region close to most users.
3. Wait ~2 minutes for provisioning.

## 2. Find your keys

Project settings → API → copy:

- **Project URL** → this is `EXPO_PUBLIC_SUPABASE_URL`.
- **anon / public** key → this is `EXPO_PUBLIC_SUPABASE_ANON_KEY`. Safe to ship to clients.
- **service_role** key → server-side only. **Never** put this in the mobile app.

## 3. Share the keys with your team securely

- Use a password manager (1Password shared vault is ideal).
- **Do NOT** paste them in Slack, email, or any file inside the repo.
- The anon key is technically "safe" to expose, but keep it out of public channels anyway.

## 4. Apply the schema (via migrations)

The schema lives in [`supabase/migrations/`](../supabase/migrations/) and is applied through the Supabase CLI rather than pasted into the dashboard. The full workflow (linking the project, applying migrations, generating TypeScript types) is in [`docs/DATABASE.md`](./DATABASE.md). The short version:

```bash
npx supabase login
npx supabase link --project-ref hpnpcwndxyhpazgkmxdy
npm run db:push    # applies all pending migrations to the linked remote
npm run db:types   # regenerates packages/shared/src/database.types.ts
```

The first migration ([`supabase/migrations/20260425120000_init.sql`](../supabase/migrations/20260425120000_init.sql)) creates the `profiles` and `posts` tables, sets up Row-Level Security, and adds CHECK constraints that mirror the sanitization bounds in `apps/mobile/src/utils/sanitize.ts`. It's idempotent — safe to apply against a project that was already initialized through the dashboard.

**Going forward**, never paste SQL into the Supabase dashboard's SQL editor for production changes. Every schema change is a migration file in a PR — see [`docs/DATABASE.md`](./DATABASE.md).

## 5. Test it

Back in the mobile app:

```bash
cd apps/mobile
cp .env.example .env
# paste the URL and anon key into .env
npm run mobile
```

Open the app in Expo Go, go to Profile → Sign in → Create account. If it succeeds and you see yourself in Supabase → Authentication → Users, the wiring is correct.

## Next steps (not today)

- Add a `storage` bucket for post media. Supabase → Storage → New bucket → `post-media`.
- Add realtime subscriptions for the feed.
- Add indexes and RLS policies for comments, likes, follows when you implement those.
