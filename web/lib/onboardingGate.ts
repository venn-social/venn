/**
 * The onboarding gate's cheap path.
 *
 * The gate answers "does this signed-in user have a profile row yet?" — a
 * question that flips from no to yes exactly once per account and never
 * flips back. Asking Postgres on every request is a round-trip on the hot
 * path of every page load, so once the answer is yes we remember it in a
 * cookie and stop asking.
 *
 * The cookie stores the **user id**, not a boolean: without that, signing
 * out and signing in as someone else on the same browser would carry the
 * previous person's "complete" answer over.
 *
 * It is deliberately unsigned. Forging it buys nothing — it only skips the
 * redirect to /onboarding, and every page then fails to find a profile row
 * while RLS keeps refusing to return anyone's data. It is a UX hint, not an
 * authorization boundary, and signing it would be ceremony that protects
 * nothing.
 */
export const PROFILE_COOKIE = "venn_profile_complete";

/** A year: the answer never changes back, so there's nothing to expire for. */
export const PROFILE_COOKIE_MAX_AGE = 60 * 60 * 24 * 365;

/**
 * Paths a signed-in user is never redirected away from — /onboarding
 * itself (it IS the destination), plus /login and /auth/callback, where
 * auth is still in flight.
 */
const EXEMPT_PATHS = ["/onboarding", "/login", "/auth/callback"];

export function isExemptPath(pathname: string): boolean {
  return EXEMPT_PATHS.some((path) => pathname.startsWith(path));
}

/**
 * True when the cookie already vouches for *this* user, so the profile
 * lookup can be skipped entirely.
 */
export function hasCompletionCookie(
  cookieValue: string | undefined,
  userId: string
): boolean {
  return cookieValue !== undefined && cookieValue === userId;
}
