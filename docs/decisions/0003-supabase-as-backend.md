# 0003 — Use Supabase for backend (Postgres + Auth + Storage + Realtime)

- **Status:** Proposed
- **Date:** 2026-05-08
- **Deciders:** Charles Salomon

## Context

venn needs: a relational database (users, profiles, posts, items, follows, overlap stats), authentication (email magic link to start, Sign in with Apple later), file storage (avatars, eventually media attachments), and a realtime channel (live overlap updates, follow notifications down the line). The team is one non-technical founder + Claude as tech lead, with a December 2026 TestFlight target.

Three realistic shapes for that backend: (a) a managed BaaS like Supabase or Firebase that bundles all four; (b) a custom Postgres + auth service we run ourselves on Fly / Railway / a single VM; (c) a serverless stack stitched together (Cloudflare D1 / Workers, Auth0, R2). The team can't afford to operate infrastructure or own auth security. Anything that requires us to hand-roll JWT minting, password resets, RLS-equivalent policy enforcement, or storage CDN behaviour is off the table for at least the first 12 months.

The codebase already runs against Supabase (URL + anon key in `.env`, `supabase-swift` SDK, RLS-enforced schema in `supabase/migrations/`). This ADR is **retroactive** — it documents a choice that's already wired in — but the alternatives section captures what we'd revisit if Supabase ever became the wrong shape.

## Decision

Use **Supabase** as the backend for the entire MVP and beyond, until a concrete capability we need ships in a competitor and not in Supabase.

Specifically:

- **Postgres** as the only datastore. RLS is the security model — every table has an explicit `enable row level security` + the matching `select / insert / update / delete` policies. No data is reachable without going through RLS.
- **Auth:** Supabase Auth. Magic link first; Sign in with Apple once Apple Developer enrollment lands. No custom JWT issuance, no parallel auth system.
- **Storage:** Supabase Storage for avatars and media. Public buckets for everything that's already public-by-default per the product vision; signed URLs only when we need to expire a link.
- **Realtime:** Supabase Realtime via the Postgres logical-replication channel. Used for live overlap recompute and notification fan-out when those features land.
- **Edge Functions** (Deno) for any server-side logic that can't live in a Postgres function or RLS policy — rate-limit-then-RPC, third-party webhooks, scheduled jobs.
- **Migrations** are the only way schema changes ship. Every migration is a SQL file in `supabase/migrations/`, applied via `npm run db:push` (linked remote) or `npm run db:reset` (local). Never edit the prod DB through the dashboard.

Client wrapper: every Supabase call goes through a feature service (`AuthService`, `ProfileService`, `FeedService`, …). Views and view-models never touch `client.from(...)` directly. This is enforced socially today; ADR 0005 (service-protocol-with-fake) makes it testable.

## Consequences

- **Easier:** auth flows ship in days, not weeks. RLS lets us put security policies next to the data they protect, in version control. Realtime is one subscribe call. We have a hosted dashboard for running ad-hoc queries during incidents. Logs, metrics, and a status page are all someone else's problem.
- **Harder:** any non-Postgres workload (vector search, time-series at scale, queue / job worker) requires a second service. Supabase pricing scales with rows + storage + egress, not engineering complexity, so a viral hit could surprise us with a bill.
- **Committed to:** Postgres (irreversibly — the schema, RLS policies, RPC functions, and migration history are all Postgres-flavoured). Supabase the company (reversible in 1–2 weeks if we need to lift-and-shift to a self-hosted Supabase or RDS + supertokens — Postgres is portable, the auth migration is the painful part).
- **Lost:** any chance of Firebase's offline-first SQLite mirroring, Realtime Database's free real-time presence, or Cloud Functions' "deploy a function from the dashboard" simplicity.
- **Risk we accept:** Supabase the company is well-funded but not yet profitable as of 2026. If they pivot or shut down, the open-source self-hostable Supabase stack exists; the migration is real but bounded.

## Alternatives considered

- **Firebase + Cloud Functions.** Schema is NoSQL (Firestore); RLS-equivalent (security rules) is custom Firebase DSL, not SQL. Postgres queries we'd write in 5 minutes become multi-document fan-outs. Auth and storage are fine, but Postgres + RLS in one product is too much value to give up. Pricing is opaque at scale.
- **Custom Postgres + supertokens (or Auth.js) on Fly / Railway.** Full control. Also full responsibility — we own backups, point-in-time recovery, security patching, JWT key rotation, the auth UI, password reset flows, email deliverability. The team doesn't have the bandwidth.
- **Cloudflare D1 + Workers + R2 + Auth0.** D1 is SQLite-on-the-edge; it has hard size limits and no Postgres ergonomics (no `unique`, no triggers, no JSONB, weaker query planner). Auth0 is solid but adds a vendor for a problem Supabase already solves.
- **Convex.** Tight integration with TypeScript, document model, Realtime built in. Wrong shape — we're not on TypeScript, the team would have to learn its custom query language, and the lock-in is total (Convex isn't open-source-self-hostable).
- **AWS (RDS + Cognito + S3 + AppSync).** Most flexible, most operational burden. Cognito is famously painful to integrate. AppSync's GraphQL adds a layer we don't need. Cost-attractive only at scale we won't have for years.
