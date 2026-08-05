# Deploying the web app

The iOS app ships through TestFlight (see [`RELEASE.md`](./RELEASE.md)). This doc covers the web app in [`web/`](../web).

As of 2026-08-05 the web app **has never been deployed** — there is no URL. The Phase 1 spec planned Vercel's free tier and it was never set up. This is the runbook for doing it the first time.

## Before you start

You need: a Vercel account, admin rights on the `venn-social/venn` GitHub repo, and access to the Supabase dashboard for the shared project.

The whole thing is about 20 minutes, and roughly half of it is step 4 — which is the step that will silently break sign-in if you skip it.

## 1. Create the Vercel project

Import `venn-social/venn` from the Vercel dashboard, then change one setting that is **not** the default:

- **Root Directory: `web`**

Without it Vercel builds from the repo root, finds the tooling `package.json` (prettier, commitlint), and fails or deploys nothing useful. Everything else — framework preset, build command, output directory — Vercel infers correctly from Next.js.

## 2. Set the environment variables

Three, for every environment (Production, Preview, Development):

| Variable                        | Value                | Notes                                                                             |
| ------------------------------- | -------------------- | --------------------------------------------------------------------------------- |
| `NEXT_PUBLIC_SUPABASE_URL`      | same as iOS's `.env` | Public by design — it ships in the client bundle.                                 |
| `NEXT_PUBLIC_SUPABASE_ANON_KEY` | same as iOS's `.env` | Also public by design; RLS is what protects the data, not this key.               |
| `TMDB_API_KEY`                  | same as iOS's `.env` | **Server-only. Never add the `NEXT_PUBLIC_` prefix**, or it leaks to the browser. |

The first two are already in `web/.env.local`; all three are in the repo-root `.env`.

**Why `TMDB_API_KEY` has no prefix:** Next.js inlines any `NEXT_PUBLIC_*` variable into the JavaScript bundle it sends to browsers. Only `app/api/catalog/search/route.ts` reads this key, and it runs on the server. Prefixing it would hand your TMDB quota to anyone who opens devtools. iOS ships its copy inside the app binary, which the team accepted because a binary is effectively public — web has a real server and doesn't need that trade.

Without `TMDB_API_KEY`, movie and show search returns a clear error message; books and albums keep working, since OpenLibrary and MusicBrainz need no key.

## 3. Deploy

Push to `main` deploys production; every PR gets a preview URL. Nothing else to configure.

## 4. Add the deployed origin to Supabase — do not skip this

**Supabase Auth only redirects magic links to allow-listed origins.** Until the Vercel URL is on that list, clicking a sign-in link on the deployed site fails, and it fails in a way that looks like the app is broken rather than misconfigured.

In the Supabase dashboard, under **Authentication → URL Configuration**:

- **Site URL**: the production URL, e.g. `https://venn.vercel.app`
- **Redirect URLs**: add both the production URL and the preview wildcard, e.g. `https://venn-*.vercel.app/**`

This is the same problem that made local development painful enough to build the numeric-code fallback on `/login` (tech-debt row 14). That fallback works on the deployed site too, so if a magic link misbehaves the code path is the workaround.

## 5. Check it end to end

Sign in on the deployed URL, then:

- Log something from the composer — this exercises the TMDB key, the media upsert, and the post insert.
- Find someone under Explorer → People and follow them.
- Confirm the feed and your profile shelves show what you logged.

If sign-in fails, revisit step 4 before anything else.

## Known gaps

- **No custom domain.** `*.vercel.app` for now; pointing a real domain at it is DNS work, not a code change.
- **No CI gate on the deployment.** Vercel builds independently of GitHub Actions, so a deploy can succeed while `Web CI` fails. Watch both.
- **The E2E suite can't sign in** (tech-debt row 13), so no automated check exercises the deployed site's authenticated surface. Step 5 is manual for now.
