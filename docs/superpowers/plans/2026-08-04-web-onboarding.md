# Web Onboarding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the web app a username-claim + optional-photo onboarding flow, so any signed-in user without a `profiles` row can actually create one, matching iOS's existing onboarding.

**Architecture:** `app/onboarding/page.tsx` is a Server Component (mirrors `/profile`, `/requests`) that gates on auth + an existing profile, then renders `<OnboardingFlow>` — a Client Component owning a two-step state machine, delegating to `<OnboardingUsernameStep>` and `<OnboardingPhotoStep>`. A new check in `lib/supabase/proxy.ts` centrally redirects any signed-in, profile-less visitor to `/onboarding` from anywhere in the app — the web equivalent of iOS's `OnboardingGate`.

**Tech Stack:** Next.js 16 (App Router, TypeScript), `@supabase/supabase-js`, Tailwind v4, Vitest, React Testing Library.

## Global Constraints

- Node 24 (`.nvmrc`) — run `nvm use` in `web/` before any command in this plan.
- Copy/wording mirrors the iOS source file referenced in each task exactly, per CLAUDE.md rule 17 — `ios/Venn/Features/Onboarding/OnboardingView.swift`, `OnboardingPhotoView.swift`, `ios/Venn/Utils/Sanitize.swift`, `ios/Venn/Utils/AvatarImage.swift`, `ios/Venn/Features/Profile/ProfileService.swift`'s `uploadAvatar`.
- Design tokens: use the existing `--color-*` CSS vars in `app/globals.css` and Tailwind's native numeric spacing scale — **never** add a named `--spacing-*` key (breaks `max-w-*`/`h-*` of the same name, see the comment in `globals.css`).
- No backend/migration changes — the `profiles` table, its CHECK constraints (format + reserved usernames from #133), and the `avatars` Storage bucket + RLS policies all already exist and work for the web client as-is.
- Every new Vitest test file lives under its module's `__tests__/` folder (`lib/__tests__/`, `components/__tests__/`), matching the existing layout.
- The `lib/onboarding.ts` → `lib/supabase/proxy.ts` dependency (Task 4 imports Task 2's `hasProfile`) means Task 2 must land before Task 4.

---

### Task 1: `lib/sanitize.ts` — username + display-name validation

**Files:**

- Create: `web/lib/sanitize.ts`
- Test: `web/lib/__tests__/sanitize.test.ts`

**Interfaces:**

- Consumes: nothing (pure functions).
- Produces: `type SanitizeReason = "empty" | "tooShort" | "tooLong" | "invalidCharacters"`; `type SanitizeResult = { valid: true; value: string } | { valid: false; reason: SanitizeReason }`; `sanitizeHandle(input: string): SanitizeResult`; `sanitizeDisplayName(input: string): SanitizeResult`; `normalise(input: string): string`.

Ports `Sanitize.handle`/`Sanitize.displayName`/`Sanitize.normalise` from `ios/Venn/Utils/Sanitize.swift` (lines 37-45, 47-52, 118-137, 151-170) exactly: same length bounds, same allowed-character set, same control/zero-width/bidi-override character stripping, same whitespace collapsing.

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/sanitize.test.ts`:

```ts
import { describe, expect, it } from "vitest";
import { normalise, sanitizeDisplayName, sanitizeHandle } from "@/lib/sanitize";

describe("sanitizeHandle", () => {
  it("accepts a valid lowercase handle", () => {
    expect(sanitizeHandle("ada")).toEqual({ valid: true, value: "ada" });
  });

  it("lowercases and trims before validating", () => {
    expect(sanitizeHandle("  Ada_Lovelace  ")).toEqual({ valid: true, value: "ada_lovelace" });
  });

  it("rejects a handle under 3 characters", () => {
    expect(sanitizeHandle("ab")).toEqual({ valid: false, reason: "tooShort" });
  });

  it("rejects a handle over 24 characters", () => {
    expect(sanitizeHandle("a".repeat(25))).toEqual({ valid: false, reason: "tooLong" });
  });

  it("rejects characters outside [a-z0-9_-]", () => {
    expect(sanitizeHandle("ada lovelace")).toEqual({ valid: false, reason: "invalidCharacters" });
  });

  it("accepts underscores and hyphens", () => {
    expect(sanitizeHandle("ada_love-lace")).toEqual({ valid: true, value: "ada_love-lace" });
  });
});

describe("sanitizeDisplayName", () => {
  it("accepts a normal name", () => {
    expect(sanitizeDisplayName("Ada Lovelace")).toEqual({ valid: true, value: "Ada Lovelace" });
  });

  it("rejects an empty (or whitespace-only) name", () => {
    expect(sanitizeDisplayName("   ")).toEqual({ valid: false, reason: "empty" });
  });

  it("rejects a name over 40 characters", () => {
    expect(sanitizeDisplayName("a".repeat(41))).toEqual({ valid: false, reason: "tooLong" });
  });

  it("collapses runs of spaces into one", () => {
    expect(sanitizeDisplayName("Ada    Lovelace")).toEqual({ valid: true, value: "Ada Lovelace" });
  });
});

describe("normalise", () => {
  it("strips C0 control characters", () => {
    expect(normalise("a\u0000b")).toBe("ab");
  });

  it("strips zero-width and bidi-override characters", () => {
    expect(normalise("a\u200Bb\u202Ec")).toBe("abc");
  });

  it("collapses runs of spaces into one", () => {
    expect(normalise("a    b")).toBe("a b");
  });

  it("caps runs of 3+ blank lines at 2", () => {
    expect(normalise("a\n\n\n\nb")).toBe("a\n\nb");
  });

  it("trims leading and trailing whitespace", () => {
    expect(normalise("  a b  ")).toBe("a b");
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- sanitize`
Expected: FAIL — `Cannot find module '@/lib/sanitize'`

- [ ] **Step 3: Write the implementation**

Create `web/lib/sanitize.ts`:

```ts
/**
 * Ports Sanitize.handle / Sanitize.displayName / Sanitize.normalise from
 * ios/Venn/Utils/Sanitize.swift — same bounds, same allowed characters,
 * same control/zero-width/bidi-override stripping. Per CLAUDE.md rule 7,
 * this is the first line of defense; the profiles_username_format and
 * profiles_display_name_length CHECK constraints in supabase/migrations/
 * are the last.
 */

export type SanitizeReason = "empty" | "tooShort" | "tooLong" | "invalidCharacters";

export type SanitizeResult =
  | { valid: true; value: string }
  | { valid: false; reason: SanitizeReason };

const HANDLE_PATTERN = /^[a-z0-9_-]+$/;

/** Lowercased, 3-24 chars, [a-z0-9_-] only. Mirrors profiles_username_format. */
export function sanitizeHandle(input: string): SanitizeResult {
  const trimmed = input.trim().toLowerCase();
  if (trimmed.length < 3) return { valid: false, reason: "tooShort" };
  if (trimmed.length > 24) return { valid: false, reason: "tooLong" };
  if (!HANDLE_PATTERN.test(trimmed)) return { valid: false, reason: "invalidCharacters" };
  return { valid: true, value: trimmed };
}

function isProblematic(codePoint: number): boolean {
  // C0 controls, except tab (0x09) + newline (0x0A).
  if (codePoint <= 0x1f && codePoint !== 0x09 && codePoint !== 0x0a) return true;
  // DEL + C1 controls.
  if (codePoint >= 0x7f && codePoint <= 0x9f) return true;
  // Zero-width / direction marks.
  if (codePoint >= 0x200b && codePoint <= 0x200f) return true;
  // Bidi embedding / override.
  if (codePoint >= 0x202a && codePoint <= 0x202e) return true;
  // Byte order mark / zero-width no-break space.
  if (codePoint === 0xfeff) return true;
  return false;
}

/**
 * NFC-normalizes, strips control/zero-width/bidi-override characters,
 * collapses runs of spaces/tabs to one, caps runs of 3+ blank lines at
 * 2, and trims edges. Idempotent.
 */
export function normalise(input: string): string {
  const nfc = input.normalize("NFC");
  let stripped = "";
  for (const char of nfc) {
    const codePoint = char.codePointAt(0);
    if (codePoint === undefined || !isProblematic(codePoint)) stripped += char;
  }
  const collapsedSpaces = stripped.replace(/[ \t]+/g, " ");
  const collapsedBlankLines = collapsedSpaces.replace(/\n{3,}/g, "\n\n");
  return collapsedBlankLines.trim();
}

/** 1-40 chars after normalise, empty is invalid. Mirrors profiles_display_name_length. */
export function sanitizeDisplayName(input: string): SanitizeResult {
  const normalised = normalise(input);
  if (normalised.length === 0) return { valid: false, reason: "empty" };
  if (normalised.length > 40) return { valid: false, reason: "tooLong" };
  return { valid: true, value: normalised };
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd web && npm run test -- sanitize`
Expected: PASS — all 15 tests green.

- [ ] **Step 5: Commit**

```bash
cd web
git add lib/sanitize.ts lib/__tests__/sanitize.test.ts
git commit -m "feat(web): add username/display-name sanitizers, ported from Sanitize.swift"
```

---

### Task 2: `lib/onboarding.ts` — profile check, availability, creation, avatar upload

**Files:**

- Create: `web/lib/onboarding.ts`
- Test: `web/lib/__tests__/onboarding.test.ts`

**Interfaces:**

- Consumes: nothing new (takes a `SupabaseClient` as a parameter, same pattern as `lib/profile.ts`/`lib/follow.ts`).
- Produces: `class UsernameTakenError extends Error`; `hasProfile(client, userId): Promise<boolean>`; `isUsernameAvailable(client, username): Promise<boolean>`; `createProfile(client, userId, username, displayName): Promise<void>`; `uploadAvatar(client, userId, blob): Promise<string>`.

Ports `OnboardingService`'s `hasProfile`/`isUsernameAvailable`/`createProfile` and `ProfileService.uploadAvatar` (`ios/Venn/Features/Onboarding/OnboardingService.swift`, `ios/Venn/Features/Profile/ProfileService.swift:93-120`).

- [ ] **Step 1: Write the failing tests**

Create `web/lib/__tests__/onboarding.test.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { createProfile, isUsernameAvailable, UsernameTakenError } from "@/lib/onboarding";

function makeClientStub(insertError: { code: string } | null = null) {
  const client = {
    from: vi.fn(() => ({
      select: vi.fn(() => ({
        eq: vi.fn(() => ({
          maybeSingle: vi.fn(async () => ({ data: null, error: null }))
        }))
      })),
      insert: vi.fn(async () => ({ error: insertError }))
    }))
  };
  return client as unknown as SupabaseClient;
}

describe("isUsernameAvailable", () => {
  it("returns false for a reserved username without querying", async () => {
    const client = makeClientStub();
    const available = await isUsernameAvailable(client, "profile");
    expect(available).toBe(false);
    expect(client.from).not.toHaveBeenCalled();
  });

  it("returns true when no row matches", async () => {
    const client = makeClientStub();
    const available = await isUsernameAvailable(client, "ada");
    expect(available).toBe(true);
  });
});

describe("createProfile", () => {
  it("throws UsernameTakenError on a unique-violation (23505)", async () => {
    const client = makeClientStub({ code: "23505" });
    await expect(createProfile(client, "user-1", "ada", null)).rejects.toThrow(UsernameTakenError);
  });

  it("throws UsernameTakenError on a check-violation (23514 — reserved word)", async () => {
    const client = makeClientStub({ code: "23514" });
    await expect(createProfile(client, "user-1", "profile", null)).rejects.toThrow(
      UsernameTakenError
    );
  });

  it("resolves when the insert succeeds", async () => {
    const client = makeClientStub();
    await expect(createProfile(client, "user-1", "ada", null)).resolves.toBeUndefined();
  });

  it("rethrows an unrelated error as-is", async () => {
    const client = makeClientStub({ code: "500" });
    await expect(createProfile(client, "user-1", "ada", null)).rejects.not.toThrow(
      UsernameTakenError
    );
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- onboarding`
Expected: FAIL — `Cannot find module '@/lib/onboarding'`

- [ ] **Step 3: Write the implementation**

Create `web/lib/onboarding.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * The four static routes under web/app/ (see #133's
 * profiles_username_not_reserved migration) — checked client-side too so
 * the live availability indicator doesn't show "available" for a name
 * that the DB constraint would reject at submit.
 */
const RESERVED_USERNAMES = new Set(["auth", "login", "profile", "requests"]);

/** Thrown by createProfile when the username is taken or reserved. */
export class UsernameTakenError extends Error {
  constructor(username: string) {
    super(`Username "${username}" is not available`);
    this.name = "UsernameTakenError";
  }
}

/** Mirrors OnboardingGate's hasProfile check. */
export async function hasProfile(client: SupabaseClient, userId: string): Promise<boolean> {
  const { data, error } = await client.from("profiles").select("id").eq("id", userId).maybeSingle();
  if (error) throw error;
  return data !== null;
}

/**
 * Advisory only — same as OnboardingService.isUsernameAvailable. The DB's
 * unique and reserved-word constraints are the real authority at insert
 * time; this just powers the live ✓/✗ indicator.
 */
export async function isUsernameAvailable(
  client: SupabaseClient,
  username: string
): Promise<boolean> {
  if (RESERVED_USERNAMES.has(username)) return false;
  const { data, error } = await client
    .from("profiles")
    .select("id")
    .eq("username", username)
    .maybeSingle();
  if (error) throw error;
  return data === null;
}

/**
 * Mirrors OnboardingService.createProfile. A unique-violation (23505,
 * plain "taken") or check-violation (23514 — the reserved-word
 * constraint; format is validated client-side first so this realistically
 * only fires for reserved words) both map to UsernameTakenError — not
 * worth distinguishing which constraint fired.
 */
export async function createProfile(
  client: SupabaseClient,
  userId: string,
  username: string,
  displayName: string | null
): Promise<void> {
  const { error } = await client
    .from("profiles")
    .insert({ id: userId, username, display_name: displayName });
  if (error) {
    if (error.code === "23505" || error.code === "23514") {
      throw new UsernameTakenError(username);
    }
    throw error;
  }
}

/**
 * Mirrors ProfileService.uploadAvatar — same bucket ("avatars"), same
 * folder-scoped path convention, same cache-busting query param (the
 * path is stable across re-uploads, so a browser would otherwise keep
 * serving a stale cached image).
 */
export async function uploadAvatar(
  client: SupabaseClient,
  userId: string,
  blob: Blob
): Promise<string> {
  const path = `${userId.toLowerCase()}/avatar.jpg`;
  const { error: uploadError } = await client.storage.from("avatars").upload(path, blob, {
    cacheControl: "3600",
    contentType: "image/jpeg",
    upsert: true
  });
  if (uploadError) throw uploadError;

  const { data } = client.storage.from("avatars").getPublicUrl(path);
  const url = `${data.publicUrl}?v=${Date.now()}`;

  const { error: updateError } = await client
    .from("profiles")
    .update({ avatar_url: url })
    .eq("id", userId);
  if (updateError) throw updateError;

  return url;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd web && npm run test -- onboarding`
Expected: PASS — all 6 tests green.

- [ ] **Step 5: Commit**

```bash
cd web
git add lib/onboarding.ts lib/__tests__/onboarding.test.ts
git commit -m "feat(web): add onboarding data layer, ported from OnboardingService.swift"
```

---

### Task 3: `lib/avatarImage.ts` — client-side downscale + JPEG encode

**Files:**

- Create: `web/lib/avatarImage.ts`

**Interfaces:**

- Consumes: nothing new.
- Produces: `resizeToJPEG(file: File, maxDimension?: number, quality?: number): Promise<Blob>`.

Ports `AvatarImage.jpegData` (`ios/Venn/Utils/AvatarImage.swift`) using the Canvas API — same numbers (512px max dimension, 0.8 quality) for visual consistency across platforms, even though the encoders differ. Not unit-tested (see the spec's Testing section: jsdom has no real Canvas 2D implementation, same category as the existing untested thin-SDK-wrapper functions like `lib/supabase/client.ts`) — verified instead by the manual check in Task 7.

- [ ] **Step 1: Write the implementation**

Create `web/lib/avatarImage.ts`:

```ts
/**
 * Prepares a picked photo for avatar upload: downscale to a sane pixel
 * budget and JPEG-encode. Ports ios/Venn/Utils/AvatarImage.swift's exact
 * numbers (512px max dimension, 0.8 quality) — 512px covers the largest
 * render size with margin; photos straight off a camera/phone are far
 * bigger than any avatar actually needs.
 */
export async function resizeToJPEG(file: File, maxDimension = 512, quality = 0.8): Promise<Blob> {
  const bitmap = await createImageBitmap(file);
  const largest = Math.max(bitmap.width, bitmap.height);
  const scale = largest > maxDimension ? maxDimension / largest : 1;
  const targetWidth = Math.floor(bitmap.width * scale);
  const targetHeight = Math.floor(bitmap.height * scale);

  const canvas = document.createElement("canvas");
  canvas.width = targetWidth;
  canvas.height = targetHeight;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Canvas 2D context unavailable");
  ctx.drawImage(bitmap, 0, 0, targetWidth, targetHeight);
  bitmap.close();

  return new Promise<Blob>((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("Failed to encode JPEG"))),
      "image/jpeg",
      quality
    );
  });
}
```

- [ ] **Step 2: Verify it builds**

Run: `cd web && npx tsc --noEmit`
Expected: clean, no errors.

- [ ] **Step 3: Commit**

```bash
cd web
git add lib/avatarImage.ts
git commit -m "feat(web): add client-side avatar resize/encode, ported from AvatarImage.swift"
```

---

### Task 4: `lib/supabase/proxy.ts` — gate profile-less users to `/onboarding`

**Files:**

- Modify: `web/lib/supabase/proxy.ts`

**Interfaces:**

- Consumes: `hasProfile` from `@/lib/onboarding` (Task 2).
- Produces: `updateSession(request: NextRequest)` — unchanged signature, new redirect behavior.

Extends the existing session-refresh middleware to also redirect a signed-in, profile-less visitor to `/onboarding` — the centralized equivalent of iOS's `OnboardingGate`, which sits in front of every signed-in screen. Runs on every request the root `proxy.ts`'s matcher covers, so there's no route-specific opt-in and no way to bypass it by deep-linking directly to `/[username]` or `/requests`.

**Tradeoff, deliberate (see the spec):** unlike iOS's gate (checked once per app launch), this adds one indexed primary-key `profiles` lookup per matched request for every signed-in user — not just profile-less ones. Negligible at this project's current scale; revisit only if it shows up as real latency under real traffic.

- [ ] **Step 1: Read the current file**

The current `web/lib/supabase/proxy.ts`:

```ts
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

/**
 * Refreshes the Supabase session cookie on every request. Required
 * whenever `setAll` can't run from a Server Component (see server.ts) —
 * without this, sessions silently expire mid-visit. Called from the root
 * `proxy.ts` (Next.js 16 renamed `middleware.ts` to `proxy.ts`).
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        }
      }
    }
  );

  // Touches the session so expired tokens refresh — the return value
  // itself isn't used here since route-level redirects (see app/profile)
  // handle the signed-out case.
  await supabase.auth.getUser();

  return response;
}
```

- [ ] **Step 2: Replace it with the extended version**

Replace the full contents of `web/lib/supabase/proxy.ts` with:

```ts
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { hasProfile } from "@/lib/onboarding";

/**
 * Paths a signed-in user is never redirected away from by the onboarding
 * check below — /onboarding itself (it IS the destination), /login and
 * /auth/callback (auth is still in flight, no user to check yet in
 * practice, but excluded defensively).
 */
const ONBOARDING_EXEMPT_PATHS = ["/onboarding", "/login", "/auth/callback"];

/**
 * Refreshes the Supabase session cookie on every request, and gates a
 * signed-in-but-profile-less user to /onboarding — the centralized
 * equivalent of iOS's OnboardingGate. See
 * docs/superpowers/specs/2026-08-04-web-onboarding-design.md.
 *
 * Called from the root `proxy.ts` (Next.js 16 renamed `middleware.ts` to
 * `proxy.ts`), which runs on every request its matcher covers — so this
 * can't be bypassed by deep-linking directly to /[username] or /requests.
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() {
          return request.cookies.getAll();
        },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value));
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options)
          );
        }
      }
    }
  );

  const {
    data: { user }
  } = await supabase.auth.getUser();

  const isExempt = ONBOARDING_EXEMPT_PATHS.some((path) =>
    request.nextUrl.pathname.startsWith(path)
  );

  if (user && !isExempt) {
    const complete = await hasProfile(supabase, user.id);
    if (!complete) {
      return NextResponse.redirect(new URL("/onboarding", request.url));
    }
  }

  return response;
}
```

- [ ] **Step 3: Verify it builds**

Run: `cd web && npx tsc --noEmit`
Expected: clean, no errors.

- [ ] **Step 4: Commit**

```bash
cd web
git add lib/supabase/proxy.ts
git commit -m "feat(web): gate profile-less users to /onboarding from the session middleware"
```

---

### Task 5: `components/OnboardingUsernameStep.tsx` — step 1

**Files:**

- Create: `web/components/OnboardingUsernameStep.tsx`
- Test: `web/components/__tests__/OnboardingUsernameStep.test.tsx`

**Interfaces:**

- Consumes: `sanitizeHandle`, `sanitizeDisplayName` from `@/lib/sanitize` (Task 1); `createProfile`, `isUsernameAvailable`, `UsernameTakenError` from `@/lib/onboarding` (Task 2); `createClient` from `@/lib/supabase/client`.
- Produces: `OnboardingUsernameStep(props: { userId: string; onComplete: () => void }): JSX.Element` (named export, Client Component).

Ports `OnboardingView`/`OnboardingViewModel` (`ios/Venn/Features/Onboarding/OnboardingView.swift`, `OnboardingViewModel.swift`) — `@`-prefixed username field with a 350ms-debounced live availability check (spinner → ✓/✗ + inline hint), optional display-name field, "Create profile" submit.

- [ ] **Step 1: Write the failing tests**

Create `web/components/__tests__/OnboardingUsernameStep.test.tsx`:

```tsx
import { fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { OnboardingUsernameStep } from "@/components/OnboardingUsernameStep";

vi.mock("@/lib/supabase/client", () => ({
  createClient: () => ({})
}));

const { isUsernameAvailable, createProfile } = vi.hoisted(() => ({
  isUsernameAvailable: vi.fn(),
  createProfile: vi.fn()
}));

vi.mock("@/lib/onboarding", async () => {
  const actual = await vi.importActual<typeof import("@/lib/onboarding")>("@/lib/onboarding");
  return {
    ...actual,
    isUsernameAvailable,
    createProfile
  };
});

describe("OnboardingUsernameStep", () => {
  beforeEach(() => {
    isUsernameAvailable.mockReset();
    createProfile.mockReset();
    vi.useFakeTimers();
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it("shows an available hint after the debounce when the handle is free", async () => {
    isUsernameAvailable.mockResolvedValue(true);
    render(<OnboardingUsernameStep userId="user-1" onComplete={() => {}} />);

    fireEvent.change(screen.getByPlaceholderText("username"), { target: { value: "ada" } });
    await vi.advanceTimersByTimeAsync(350);

    expect(await screen.findByText("@ada is available")).toBeDefined();
  });

  it("shows a taken hint after the debounce when the handle is in use", async () => {
    isUsernameAvailable.mockResolvedValue(false);
    render(<OnboardingUsernameStep userId="user-1" onComplete={() => {}} />);

    fireEvent.change(screen.getByPlaceholderText("username"), { target: { value: "ada" } });
    await vi.advanceTimersByTimeAsync(350);

    expect(await screen.findByText("@ada is taken — try another")).toBeDefined();
  });

  it("shows an inline error for an invalid handle without a network call", () => {
    render(<OnboardingUsernameStep userId="user-1" onComplete={() => {}} />);

    fireEvent.change(screen.getByPlaceholderText("username"), { target: { value: "a" } });

    expect(screen.getByText("Usernames need at least 3 characters.")).toBeDefined();
    expect(isUsernameAvailable).not.toHaveBeenCalled();
  });

  it("calls onComplete after a successful submit", async () => {
    createProfile.mockResolvedValue(undefined);
    const onComplete = vi.fn();
    render(<OnboardingUsernameStep userId="user-1" onComplete={onComplete} />);

    fireEvent.change(screen.getByPlaceholderText("username"), { target: { value: "ada" } });
    fireEvent.click(screen.getByRole("button", { name: "Create profile" }));

    await vi.waitFor(() => expect(onComplete).toHaveBeenCalled());
    expect(createProfile).toHaveBeenCalledWith({}, "user-1", "ada", null);
  });

  it("shows an inline error and does not call onComplete when the username is taken at submit", async () => {
    const { UsernameTakenError } =
      await vi.importActual<typeof import("@/lib/onboarding")>("@/lib/onboarding");
    createProfile.mockRejectedValue(new UsernameTakenError("ada"));
    const onComplete = vi.fn();
    render(<OnboardingUsernameStep userId="user-1" onComplete={onComplete} />);

    fireEvent.change(screen.getByPlaceholderText("username"), { target: { value: "ada" } });
    fireEvent.click(screen.getByRole("button", { name: "Create profile" }));

    expect(await screen.findByText("That username is taken — try another.")).toBeDefined();
    expect(onComplete).not.toHaveBeenCalled();
  });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd web && npm run test -- OnboardingUsernameStep`
Expected: FAIL — `Cannot find module '@/components/OnboardingUsernameStep'`

- [ ] **Step 3: Write the implementation**

Create `web/components/OnboardingUsernameStep.tsx`:

```tsx
"use client";

import { useEffect, useRef, useState } from "react";
import { createProfile, isUsernameAvailable, UsernameTakenError } from "@/lib/onboarding";
import { sanitizeDisplayName, sanitizeHandle, type SanitizeReason } from "@/lib/sanitize";
import { createClient } from "@/lib/supabase/client";

interface OnboardingUsernameStepProps {
  userId: string;
  onComplete: () => void;
}

type Availability =
  | { status: "idle" }
  | { status: "checking" }
  | { status: "available"; handle: string }
  | { status: "taken"; handle: string }
  | { status: "invalid"; message: string };

const AVAILABILITY_DEBOUNCE_MS = 350;

function messageForReason(reason: SanitizeReason): string {
  switch (reason) {
    case "tooShort":
      return "Usernames need at least 3 characters.";
    case "tooLong":
      return "Usernames max out at 24 characters.";
    case "invalidCharacters":
      return "Only lowercase letters, numbers, _ and - are allowed.";
    case "empty":
      return "Usernames need at least 3 characters.";
  }
}

export function OnboardingUsernameStep({ userId, onComplete }: OnboardingUsernameStepProps) {
  const [username, setUsername] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [availability, setAvailability] = useState<Availability>({ status: "idle" });
  const [submitError, setSubmitError] = useState("");
  const debounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    if (debounceRef.current) clearTimeout(debounceRef.current);

    const raw = username.trim();
    if (raw.length === 0) {
      setAvailability({ status: "idle" });
      return;
    }

    const result = sanitizeHandle(raw);
    if (!result.valid) {
      setAvailability({ status: "invalid", message: messageForReason(result.reason) });
      return;
    }

    setAvailability({ status: "checking" });
    const handle = result.value;
    debounceRef.current = setTimeout(async () => {
      try {
        const supabase = createClient();
        const free = await isUsernameAvailable(supabase, handle);
        setAvailability(free ? { status: "available", handle } : { status: "taken", handle });
      } catch {
        setAvailability({ status: "idle" });
      }
    }, AVAILABILITY_DEBOUNCE_MS);

    return () => {
      if (debounceRef.current) clearTimeout(debounceRef.current);
    };
  }, [username]);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setSubmitError("");

    const handleResult = sanitizeHandle(username);
    if (!handleResult.valid) {
      setSubmitError(messageForReason(handleResult.reason));
      return;
    }

    let name: string | null = null;
    if (displayName.trim().length > 0) {
      const nameResult = sanitizeDisplayName(displayName);
      if (!nameResult.valid) {
        setSubmitError("Display names max out at 40 characters.");
        return;
      }
      name = nameResult.value;
    }

    setSubmitting(true);
    try {
      const supabase = createClient();
      await createProfile(supabase, userId, handleResult.value, name);
      onComplete();
    } catch (error) {
      if (error instanceof UsernameTakenError) {
        setAvailability({ status: "taken", handle: handleResult.value });
        setSubmitError("That username is taken — try another.");
      } else {
        setSubmitError("Something went wrong. Please try again.");
      }
    } finally {
      setSubmitting(false);
    }
  }

  const canSubmit = !submitting && username.trim().length > 0;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <p className="text-xs font-semibold text-(--color-text-secondary)">Step 1 of 2</p>
        <h1 className="text-xl font-semibold text-(--color-text-primary)">Claim your username</h1>
        <p className="text-(--color-text-secondary)">
          It&apos;s how people find you and your Venn. Lowercase letters, numbers, _ and - only.
        </p>
      </div>

      <form onSubmit={handleSubmit} className="flex flex-col gap-3">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-1 rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2">
            <span className="text-(--color-text-secondary)">@</span>
            <input
              type="text"
              value={username}
              onChange={(event) => setUsername(event.target.value)}
              placeholder="username"
              autoComplete="username"
              autoCapitalize="off"
              autoCorrect="off"
              className="flex-1 bg-transparent text-(--color-text-primary) outline-none"
            />
            <AvailabilityIndicator availability={availability} />
          </div>
          <AvailabilityHint availability={availability} />
        </div>

        <input
          type="text"
          value={displayName}
          onChange={(event) => setDisplayName(event.target.value)}
          placeholder="Display name (optional)"
          autoComplete="name"
          className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
        />

        {submitError && <p className="text-sm text-red-500">{submitError}</p>}

        <button
          type="submit"
          disabled={!canSubmit}
          className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
        >
          {submitting ? "Creating…" : "Create profile"}
        </button>
      </form>
    </div>
  );
}

function AvailabilityIndicator({ availability }: { availability: Availability }) {
  switch (availability.status) {
    case "checking":
      return <span className="text-(--color-text-secondary)">…</span>;
    case "available":
      return <span className="text-green-600">✓</span>;
    case "taken":
    case "invalid":
      return <span className="text-red-500">✕</span>;
    default:
      return null;
  }
}

function AvailabilityHint({ availability }: { availability: Availability }) {
  switch (availability.status) {
    case "available":
      return <p className="text-sm text-green-600">@{availability.handle} is available</p>;
    case "taken":
      return <p className="text-sm text-red-500">@{availability.handle} is taken — try another</p>;
    case "invalid":
      return <p className="text-sm text-red-500">{availability.message}</p>;
    default:
      return null;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd web && npm run test -- OnboardingUsernameStep`
Expected: PASS — all 5 tests green.

- [ ] **Step 5: Commit**

```bash
cd web
git add components/OnboardingUsernameStep.tsx components/__tests__/OnboardingUsernameStep.test.tsx
git commit -m "feat(web): add onboarding username step, ported from OnboardingView.swift"
```

---

### Task 6: `components/OnboardingPhotoStep.tsx` — step 2 (skippable)

**Files:**

- Create: `web/components/OnboardingPhotoStep.tsx`

**Interfaces:**

- Consumes: `resizeToJPEG` from `@/lib/avatarImage` (Task 3); `uploadAvatar` from `@/lib/onboarding` (Task 2); `createClient` from `@/lib/supabase/client`.
- Produces: `OnboardingPhotoStep(props: { userId: string; onComplete: () => void }): JSX.Element` (named export, Client Component). `onComplete` fires on a successful upload OR on skip — a photo never blocks completion, matching iOS.

Ports `OnboardingPhotoView`/`OnboardingPhotoViewModel` (`ios/Venn/Features/Onboarding/OnboardingPhotoView.swift`, `OnboardingPhotoViewModel.swift`) — circular file-picker preview, "Continue" (disabled until a file's picked)/"Skip for now", inline failure message.

- [ ] **Step 1: Write the component**

Create `web/components/OnboardingPhotoStep.tsx`:

```tsx
"use client";

import { useRef, useState } from "react";
import { resizeToJPEG } from "@/lib/avatarImage";
import { uploadAvatar } from "@/lib/onboarding";
import { createClient } from "@/lib/supabase/client";

interface OnboardingPhotoStepProps {
  userId: string;
  onComplete: () => void;
}

export function OnboardingPhotoStep({ userId, onComplete }: OnboardingPhotoStepProps) {
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [pickedBlob, setPickedBlob] = useState<Blob | null>(null);
  const [uploading, setUploading] = useState(false);
  const [failed, setFailed] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);

  async function handleFileChange(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setFailed(false);
    const jpeg = await resizeToJPEG(file);
    setPickedBlob(jpeg);
    setPreviewUrl(URL.createObjectURL(jpeg));
  }

  async function handleContinue() {
    if (!pickedBlob) return;
    setFailed(false);
    setUploading(true);
    try {
      const supabase = createClient();
      await uploadAvatar(supabase, userId, pickedBlob);
      onComplete();
    } catch {
      setFailed(true);
    } finally {
      setUploading(false);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <p className="text-xs font-semibold text-(--color-text-secondary)">Step 2 of 2</p>
        <h1 className="text-xl font-semibold text-(--color-text-primary)">
          Add a face to the name
        </h1>
        <p className="text-(--color-text-secondary)">
          Your photo shows up next to everything you log. You can always change it later.
        </p>
      </div>

      <div className="flex justify-center">
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          aria-label="Choose a photo"
          className="flex h-[140px] w-[140px] items-center justify-center overflow-hidden rounded-full bg-(--color-surface-strong)"
        >
          {previewUrl ? (
            // eslint-disable-next-line @next/next/no-img-element -- local object URL, not a remote asset
            <img src={previewUrl} alt="" className="h-full w-full object-cover" />
          ) : (
            <span className="text-(--color-accent)">Choose photo</span>
          )}
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handleFileChange}
          className="hidden"
        />
      </div>

      {failed && (
        <p className="text-sm text-red-500">
          Couldn&apos;t upload that photo. Try again — or skip and add one later.
        </p>
      )}

      <button
        type="button"
        onClick={handleContinue}
        disabled={!pickedBlob || uploading}
        className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
      >
        {uploading ? "Uploading…" : "Continue"}
      </button>

      <button
        type="button"
        onClick={onComplete}
        className="text-sm font-semibold text-(--color-text-secondary)"
      >
        Skip for now
      </button>
    </div>
  );
}
```

- [ ] **Step 2: Verify it builds**

Run: `cd web && npx tsc --noEmit`
Expected: clean, no errors.

- [ ] **Step 3: Commit**

```bash
cd web
git add components/OnboardingPhotoStep.tsx
git commit -m "feat(web): add onboarding photo step, ported from OnboardingPhotoView.swift"
```

---

### Task 7: `components/OnboardingFlow.tsx` + `app/onboarding/page.tsx` — wire it together

**Files:**

- Create: `web/components/OnboardingFlow.tsx`
- Create: `web/app/onboarding/page.tsx`

**Interfaces:**

- Consumes: `OnboardingUsernameStep` (Task 5), `OnboardingPhotoStep` (Task 6); `hasProfile` from `@/lib/onboarding` (Task 2); `createClient` (server) from `@/lib/supabase/server`.
- Produces: the `/onboarding` route; `OnboardingFlow(props: { userId: string }): JSX.Element` (named export, Client Component).

`app/onboarding/page.tsx` is a Server Component (mirrors `/profile`, `/requests`): redirects to `/login` if signed out, redirects to `/profile` if a profile already exists (so revisiting `/onboarding` after completing it doesn't re-trigger it), otherwise renders `<OnboardingFlow>`. `OnboardingFlow` owns the two-step client state machine — this split exists because the auth/profile gate needs server-side data before rendering anything, but the step-switching itself needs client state, and a Server Component can't hold that.

- [ ] **Step 1: Write the flow component**

Create `web/components/OnboardingFlow.tsx`:

```tsx
"use client";

import { useState } from "react";
import { OnboardingPhotoStep } from "@/components/OnboardingPhotoStep";
import { OnboardingUsernameStep } from "@/components/OnboardingUsernameStep";

interface OnboardingFlowProps {
  userId: string;
}

export function OnboardingFlow({ userId }: OnboardingFlowProps) {
  const [step, setStep] = useState<"username" | "photo">("username");

  if (step === "username") {
    return <OnboardingUsernameStep userId={userId} onComplete={() => setStep("photo")} />;
  }

  return (
    <OnboardingPhotoStep
      userId={userId}
      onComplete={() => {
        window.location.href = "/profile";
      }}
    />
  );
}
```

- [ ] **Step 2: Write the page**

Create `web/app/onboarding/page.tsx`:

```tsx
import { redirect } from "next/navigation";
import { OnboardingFlow } from "@/components/OnboardingFlow";
import { hasProfile } from "@/lib/onboarding";
import { createClient } from "@/lib/supabase/server";

export default async function OnboardingPage() {
  const supabase = await createClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect("/login");
  }

  const complete = await hasProfile(supabase, user.id);
  if (complete) {
    redirect("/profile");
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-sm flex-col justify-center px-4 py-8">
      <OnboardingFlow userId={user.id} />
    </main>
  );
}
```

- [ ] **Step 3: Verify it builds**

Run: `cd web && npm run build`
Expected: build succeeds; the route table includes `ƒ /onboarding`.

- [ ] **Step 4: Run the full test suite**

Run: `cd web && npm run test`
Expected: PASS — the existing 24 tests plus this plan's 26 new ones (15 in `sanitize.test.ts`, 6 in `onboarding.test.ts`, 5 in `OnboardingUsernameStep.test.tsx`), 50 total.

- [ ] **Step 5: Manual check**

Run: `cd web && npm run dev`. Sign in as a user with no `profiles` row (or manually delete your own row in Supabase Studio first). Confirm:

- Visiting `/profile` (or any authenticated route) redirects to `/onboarding`.
- The username step's live ✓/✗ indicator works, submitting creates the profile and advances to the photo step.
- The photo step's picker preview renders, "Skip for now" and a real upload both land on `/profile` with the profile now visible.
- Revisiting `/onboarding` directly afterward redirects to `/profile` (not back into the flow).

- [ ] **Step 6: Commit**

```bash
cd web
git add components/OnboardingFlow.tsx app/onboarding/page.tsx
git commit -m "feat(web): wire up the onboarding flow, ported from OnboardingGate.swift"
```

---

## Self-Review Notes

**Spec coverage:** Username step (Task 5), photo step (Task 6), the centralized gate (Task 4), the data layer (Task 2), validation (Task 1), image processing (Task 3), and the page/flow wiring (Task 7) cover every section of the spec. The two "advisory reserved-word check" and "23505 or 23514" refinements caught during the spec's own self-review are both reflected in Task 2's implementation and tests.

**Type consistency:** `SanitizeResult`/`SanitizeReason` (Task 1) flow unchanged into `OnboardingUsernameStep` (Task 5). `UsernameTakenError` (Task 2) is thrown by `createProfile` and caught by name in `OnboardingUsernameStep`'s submit handler — same class identity, no re-declaration. `resizeToJPEG`'s `Blob` return (Task 3) flows unchanged into `uploadAvatar`'s `blob` parameter (Task 2) via `OnboardingPhotoStep` (Task 6).

**Scope:** No backend changes anywhere in this plan — every task is `web/` only, confirmed against the spec's "no backend changes" constraint. The `OnboardingFlow` split (not in the original spec's file list, which described a 3-file split) is a decomposition refinement made during planning, not a scope change — the spec's described behavior (two-step client flow behind a server-side gate) is unchanged, just split across one more file for the reasons in Task 7's description.
