# venn web app — Phase 2: public profiles + Venn overlap

## Context

Phase 1 (`docs/superpowers/specs/2026-07-30-web-app-phase1-foundation-design.md`, shipped in PR #129) delivered the web app's foundation: Next.js scaffold, magic-link auth, and a read-only "my profile" page. This spec covers Phase 2, per that document's phase roadmap: viewing _other_ users' profiles, the product's signature Venn-overlap diagram, and the full follow lifecycle (public and private accounts).

iOS shipped the equivalent of everything in this phase already — most recently PR #130 (private-account content gating + the follow-requests screen), merged today. Per CLAUDE.md rule 17 (cross-platform parity), Phase 2 brings web to parity with the _complete_ current iOS feature set for profile viewing and following, not just the public-account subset — there's a complete reference implementation for every piece of this phase already in `ios/Venn/Features/Profile/`.

## Scope

- **Public profile page**: view another user's profile — header, bio, follow button, the Venn overlap, and their collection/watchlist. Mirrors `PublicProfileView.swift`.
- **Follow lifecycle**: follow (instant for a public account, pending for a private one), unfollow, and — for the signed-in user's own private account — a requests screen to accept/reject pending requests. Mirrors `FollowService.swift` / `FollowViewModel.swift` / `FollowRequestsView.swift`.
- **Private-account gating**: a non-follower viewing a private account sees a locked placeholder instead of their shelves/overlap. Mirrors `PublicProfileView`'s `lockedContent`.
- **Venn overlap**: the taste-overlap diagram between the viewer and the profile they're looking at. Mirrors `VennOverlap.swift`'s geometry and visual design, ported to SVG.

### Explicitly out of scope for Phase 2

Feed, composer (logging/rating/saving), explorer/people search (needed to _discover_ profiles to visit — for now, profile URLs are reached by typing `/username` directly or via a link, not in-app search), Year in Review. Each is a later phase per the Phase 1 roadmap.

## Architecture

### Routing

- `app/[username]/page.tsx` — public profile, addressed by username (matches how profiles get linked/shared — `venn.app/maya`, not a UUID). Looks up the profile by username first; 404s via `notFound()` if no such user.
- `app/requests/page.tsx` — the signed-in user's pending follow requests. Redirects to `/login` if signed out.
- `/profile` (Phase 1) is unchanged — it's specifically "my own profile," never reached via `[username]`.

### Data layer

- `lib/profile.ts` (existing, from Phase 1) gains `fetchProfileByUsername`.
- `lib/follow.ts` (new): `fetchFollowStatus`, `requestFollow`, `unfollow`, `respondToRequest`, `fetchPendingRequests` — thin wrappers over the `follows` table and the `request_follow` / `respond_to_follow_request` RPCs. Same RPCs iOS calls; no backend changes in this phase.
- `lib/overlap.ts` (new): `fetchOverlap`, wrapping the existing `compute_overlap` RPC. Returns the same per-kind slices `OverlapService.swift` does.

### Gating

Computed server-side in `app/[username]/page.tsx` (a Server Component): `isLocked = profile.isPrivate && followStatus !== 'accepted'`. When locked, the page never fetches or renders the overlap/shelves data at all — stronger than iOS's client-side check (RLS is still the real access control either way; this just avoids transmitting data to the client that would immediately be discarded).

### Components

- `components/VennOverlap.tsx`: SVG port of `VennOverlap.swift`. Same geometry (`PairGeometry`'s radius ∝ √count, half-distance driven by the Jaccard-style shared ratio) ported to a plain TS function. The "lens" (intersection highlight) uses an SVG `<clipPath>` referencing the other lobe's circle — the direct SVG equivalent of SwiftUI's `.mask`, same visual result.
- `components/FollowButton.tsx`: Follow / Requested / Following states, mirroring `PublicProfileView`'s `followButton`.
- `components/LockedProfile.tsx`: the locked-placeholder state.

### Follow lifecycle UI

- Same optimism asymmetry as iOS's `FollowViewModel`: unfollow updates the button immediately (the outcome is never in doubt), but follow waits for the server's real `accepted`/`pending` result before updating, since the outcome depends on the target's privacy and the client can't predict it.
- `/requests`: list of pending requesters with accept/reject buttons, optimistic removal on click (reverts via reload on failure) — mirrors `FollowRequestsViewModel`.

## Error handling

Continues Phase 1's pattern: a shared loading/loaded/error shape per data-fetching component, Supabase errors mapped to user-facing copy at one boundary. Rate-limited responses (`request_follow`/`respond_to_follow_request` are both rate-limited server-side, same as iOS) surface as "Too many requests, try again shortly" rather than a generic error.

## Testing

- **Unit**: Vitest tests for `lib/follow.ts` and `lib/overlap.ts`'s row-mapping functions and for the overlap geometry math (radius/distance calculation), mirroring `OverlapTests.swift`'s coverage of `PairGeometry`.
- **E2E**: Playwright, covering (a) viewing a public profile and seeing the overlap render, (b) the locked-content state for a private account, (c) following a public account and unfollowing. The `request_follow`/`unfollow`/`respond_to_follow_request` network calls are mocked in tests (not hit for real) — same reasoning as Phase 1's auth E2E tests: an automated test suite writing real follow edges into the shared Supabase project is not something we want running on every CI push.

## Open questions (not blocking Phase 2)

- Discovering profiles to visit (people search) is Phase 2's one real gap — until explorer/people-search ships in a later phase, reaching a public profile on web means already knowing the username. Acceptable for this phase; flagged so it doesn't get forgotten.
