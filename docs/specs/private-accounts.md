# Private accounts — design spec

**Status:** approved 2026-06-26 (Charles). Backend migration first (this spec + PR), Swift client + UI follow.

## Goal

Add an Instagram-style **private account** option. Public-by-default stays; a user can flip their profile to private, after which their consumption content is visible only to **approved followers**, and following them becomes a **request** they approve.

## What's gated (decided)

When a viewer is **not** an accepted follower of a private account, they see the account's **identity** (name, @handle, avatar, bio, follower/following **counts**) and a "This account is private — follow to see" notice, but **not**: posts (feed + profile), Collection/Watchlist shelves, the Venn overlap, or follower/following **lists**.

Public accounts are unchanged — everything stays world-readable.

## Data model

- `profiles.is_private boolean not null default false`.
- `follows.status text not null default 'accepted'`, `CHECK (status in ('pending','accepted'))`. Existing rows grandfather to `accepted`.

## Access control (RLS + RPCs — never client-trusted)

- **`posts` SELECT** → visible if `author = viewer` **OR** author is public **OR** viewer is an `accepted` follower. This one policy gates the feed _and_ the profile shelves (both derive from `posts`). `compute_overlap` is `SECURITY INVOKER`, so it inherits this gating automatically — no separate change.
- **`follows` SELECT** → your own edges, or edges where both ends are public and `accepted`, or (your own as follower/followee). Hides private-account edges and all `pending` edges from third parties.
- **`profiles` SELECT** stays `true` (identity visible).
- **Follows are written only via RPCs** — `follows_insert_own` is dropped so a client can't self-insert an `accepted` edge and bypass privacy.

### RPCs (all rate-limited via `rl_check`, matching `compute_overlap`)

- `request_follow(target) -> status`: inserts `accepted` if target public, `pending` if private. `SECURITY DEFINER`, enforces `follower = auth.uid()`, no self-follow.
- `respond_to_follow_request(requester, accept)`: only the followee (`auth.uid()`) may accept (→`accepted`) or reject (delete the pending row).
- `follow_counts(target) -> (followers, following)`: `accepted`-only counts, `SECURITY DEFINER` so header counts survive the tightened `follows` SELECT.

## Standard behaviors

- Public→private: existing followers keep access (grandfathered). Private→public: pending requests auto-accept (handled in the toggle service call / a future RPC; for now flipping public means new follows are instant and pending ones can be bulk-accepted).
- Following public = instant; private = "Requested" until approved. Cancel request = unfollow (delete).
- Private accounts still appear in search (identity visible).
- **No notifications** (no system yet) — incoming requests live on a screen the user opens. Known MVP limitation.

## Client (follow-up PRs, after schema regen)

- `UserProfile.isPrivate`; `FollowService` switches to the RPCs; follow state gains `.requested`.
- Settings sheet with a "Private account" toggle.
- `PublicProfileView`: "Requested" button state; locked content state when private + not accepted.
- Incoming-requests screen (approve/reject).

## Verification (blocked this session — no container runtime)

The migration is **unverified** — there's no Docker/OrbStack to run `npm run db:reset`. Before merge + `db:push`, it must be applied locally and the RLS exercised:

- A non-follower **cannot** read a private user's `posts`; an accepted follower **can**; the owner always can.
- `request_follow` yields `pending` for private targets, `accepted` for public.
- `respond_to_follow_request` works only for the followee; `follow_counts` returns accepted-only counts.
- Public accounts behave exactly as before (no regression to the feed).

Then `make codegen` regenerates `SupabaseSchema.swift`, and the Swift client lands.
