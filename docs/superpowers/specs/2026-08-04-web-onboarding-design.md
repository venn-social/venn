# venn web app — onboarding (username claim + photo)

## Context

Web has no onboarding flow. A user can sign in (magic-link or the numeric-code fallback from #134) and get a real Supabase session, but every screen that renders profile data (`/profile`, `/[username]`, `/requests`) assumes a `public.profiles` row already exists for `auth.uid()`. That row is never created automatically — there's no database trigger on `auth.users` insert — it's only ever created by iOS's onboarding flow (`OnboardingService.createProfile`, a direct insert after a client-side username check). Any signed-in web user without a pre-existing profile (created earlier via iOS) hits a dead end: `/profile` renders "Couldn't load your profile" with no way forward.

This was a known, deliberately-deferred gap — the Phase 1 web spec flagged "whether web needs its own onboarding (username claim) flow... to be resolved when web functionality expands enough that web-first signup is realistic" as an open question. It became a real, blocking problem when the project owner tried signing into web with an account that had no profile row.

iOS's reference implementation (`ios/Venn/Features/Onboarding/`) is the source of truth for behavior and copy, per CLAUDE.md rule 17: `OnboardingGate.swift` (routes signed-in-but-profile-less users to onboarding before the rest of the app), `OnboardingView.swift` + `OnboardingViewModel.swift` (step 1: username), `OnboardingPhotoView.swift` + `OnboardingPhotoViewModel.swift` (step 2: photo, skippable).

## Scope

- **Username-claim step** (required): the only thing that unblocks profile creation. Live availability check, optional display name, submit creates the `profiles` row.
- **Photo step** (skippable): picks an image, downscales/compresses it client-side, uploads to the existing `avatars` Storage bucket, writes the public URL onto the profile.
- **A gate** that gets every signed-in, profile-less web user to `/onboarding` regardless of which URL they land on first, and keeps profile-having users out of `/onboarding` if they navigate there directly.

No backend changes: the `profiles` table, its CHECK constraints (format + reserved usernames, the latter added in #133), and the `avatars` Storage bucket + folder-scoped RLS policies all already exist and already work for any Supabase client, web included.

### Explicitly out of scope

Editing an existing avatar/profile after onboarding (that's a separate "edit profile" surface, not built on web yet, iOS's `ProfileEditView`/`SettingsView` equivalent). Re-running onboarding after the fact. Any change to the reserved-username list or DB constraints.

## Architecture

### Routing

- `app/onboarding/page.tsx` — the two-step flow, `"use client"` (matches `/login`'s pattern: a single small multi-state page, not a Server Component). Redirects to `/login` if signed out (same pattern as every other authenticated page), and to `/profile` if a profile already exists (so revisiting `/onboarding` after completing it, or being sent a stale link, doesn't re-trigger it).
- `lib/supabase/proxy.ts`'s `updateSession` gains a profile check: after `supabase.auth.getUser()`, if a user exists and the request path isn't `/onboarding`, `/login`, or `/auth/callback`, check `hasProfile`. If false, redirect to `/onboarding`. This is the centralized equivalent of `OnboardingGate` — every authenticated route goes through the proxy already (per the existing matcher), so there's no route-specific opt-in needed and no way to bypass it by deep-linking directly to `/[username]` or `/requests`.
- **Tradeoff, noted deliberately**: unlike iOS's gate (checked once per app launch), this runs a `profiles` lookup on every matched request for every signed-in user, forever — not just profile-less ones. It's a single indexed primary-key lookup (cheap, low-single-digit ms), and at this project's current scale that cost is negligible against the correctness/simplicity win of one un-bypassable check point. Revisit (e.g. caching "has profile" in a cookie or JWT claim after the first success) only if this shows up as real latency once there's real traffic — not worth the added invalidation complexity now.

### Data layer (`lib/onboarding.ts`, new)

- `hasProfile(client, userId): Promise<boolean>` — `select('id').eq('id', userId).maybeSingle()`, true if a row comes back.
- `isUsernameAvailable(client, username): Promise<boolean>` — advisory only, same as iOS: `select('id').eq('username', username).maybeSingle()`, true if nothing comes back — **and** false immediately (no query) if `username` is one of the four reserved names from #133's `profiles_username_not_reserved` constraint (`auth`, `login`, `profile`, `requests`), so the live ✓/✗ indicator doesn't show "available" for a name that would fail at submit. The DB constraints (uniqueness and reserved-word) are still the real authority at insert time; this is UX-only, same relationship the format check already has to `profiles_username_format`.
- `createProfile(client, userId, username, displayName): Promise<void>` — inserts `{ id: userId, username, display_name: displayName ?? null }`. Maps a unique-violation (Postgres code `23505`, plain "taken") **or** a check-violation (`23514` — the reserved-word constraint; format is already validated client-side so this realistically only fires for reserved words) to the same `UsernameTakenError`, mirroring iOS's `UsernameTakenError` catch branch. Both read as "that username isn't available" to the user — not worth distinguishing by parsing which specific constraint fired.
- `uploadAvatar(client, userId, blob): Promise<string>` — uploads to `avatars/{userId}/avatar.jpg` (upsert, `contentType: "image/jpeg"`), reads the public URL, appends a cache-busting `?v=<timestamp>` query param (matches `ProfileService.uploadAvatar` exactly — the path is stable across re-uploads so a browser would otherwise keep serving a cached image), then `update({ avatar_url: url }).eq('id', userId)`. Returns the final URL.

### Validation (`lib/sanitize.ts`, new)

Ports `Sanitize.handle`/`Sanitize.displayName`'s exact rules: username 3-24 chars, lowercase letters/digits/`_`/`-` only (trimmed + lowercased before checking); display name 1-40 chars after trimming, empty string treated as "no display name" rather than invalid. Pure functions, directly unit-testable — mirrors `SanitizeTests.swift`'s coverage.

### Image processing (`lib/avatarImage.ts`, new)

`resizeToJPEG(file: File, maxDimension = 512, quality = 0.8): Promise<Blob>` — draws the picked image onto an offscreen `<canvas>`, downscales so the longer edge is at most `maxDimension` (skips resizing if already smaller, matching `AvatarImage.jpegData`'s `guard largest > maxDimension` early-out), exports as JPEG at `quality`. Same numbers as iOS for visual consistency across platforms, even though the encoders differ.

### Components

- `app/onboarding/page.tsx` — owns the two-step state machine (`"username" | "photo"`), renders the corresponding step component, matches `/[username]`'s `max-w-lg` / `mx-auto` shell.
- `components/OnboardingUsernameStep.tsx` — the `@`-prefixed username field with debounced (350ms) live availability (spinner while checking, ✓/✗ + inline hint after), optional display-name field, "Create profile" button. Copy matches `OnboardingView` verbatim ("Step 1 of 2", "Claim your username", "It's how people find you and your Venn...", the exact validation error strings).
- `components/OnboardingPhotoStep.tsx` — circular file-picker preview (`<input type="file" accept="image/*">` styled as a 140px circle, camera icon placeholder when empty), "Continue" (disabled until a file's picked) / "Skip for now", inline failure message ("Couldn't upload that photo. Try again — or skip and add one later."). Copy matches `OnboardingPhotoView` verbatim ("Step 2 of 2", "Add a face to the name", "Your photo shows up next to everything you log...").

## Error handling

Username step: the debounced availability check silently falls back to idle on a network failure (matches iOS — the submit path is what surfaces real errors, not the live check). Submit-time errors: username taken (from the DB constraint, surfaced inline near the field), offline/unknown (generic inline message below the fields) — same taxonomy as `OnboardingViewModel.ErrorReason`, minus the iOS-only cases that don't apply here.

Photo step: an upload failure sets an inline error and returns to the picking state — the user can retry or skip, exactly like iOS. A photo should never block reaching `/profile`.

## Testing

- **Unit (Vitest)**: `lib/sanitize.ts` (handle/displayName validation matrix, mirroring `SanitizeTests.swift`), `lib/onboarding.ts`'s pure/mappable bits (unique-violation → `UsernameTakenError` mapping). `lib/avatarImage.ts`'s canvas-based resize isn't meaningfully unit-testable under jsdom (no real Canvas 2D implementation) — left unverified by unit tests, same category as the existing untested thin-SDK-wrapper functions (`lib/supabase/client.ts`).
- **Component (Vitest + RTL)**: `OnboardingUsernameStep.test.tsx` — the debounced availability state machine (idle → checking → available/taken), mocking `isUsernameAvailable`/`createProfile`, same mocking pattern as `FollowButton.test.tsx`.
- **E2E (Playwright)**: no authenticated-session fixture exists in this project (documented gap, `docs/TECH_DEBT.md` row 13) and onboarding is entirely behind auth, so there's nothing meaningfully E2E-testable without one. No new Playwright spec this phase — logged as part of the same existing tech-debt row rather than a new one.

## Open questions (not blocking)

- Whether to eventually also gate `/login`'s post-auth redirect target (currently always `/profile`, per `auth/callback/route.ts`) directly to `/onboarding` when a profile's missing, instead of round-tripping through `/profile` → proxy redirect. The proxy-level gate makes this unnecessary for correctness (it catches it either way), but skipping the round-trip would be a minor latency/flash-of-wrong-page improvement. Not worth the extra complexity now.
