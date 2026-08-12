/**
 * Sign-in helpers shared between the login page and its tests.
 *
 * Mirrors `AuthViewModel.resendCooldown` and `resendSecondsRemaining` on
 * iOS. The two are tested against the same cases, because a cooldown that
 * differs between platforms is a cooldown someone will route around by
 * switching device.
 */

/**
 * Seconds before "Resend link" unlocks.
 *
 * Matches iOS's `AuthViewModel.resendCooldown`. It exists so an impatient
 * tap-storm doesn't burn through Supabase's send limit — which on the
 * built-in mailer is roughly 3-4 an hour, low enough that a handful of
 * wasted sends locks someone out for the rest of it.
 */
export const RESEND_COOLDOWN_SECONDS = 30;

/**
 * Seconds left on the cooldown, 0 when ready.
 *
 * Rounds up, so a button reading "Resend in 1s" is never a lie that the
 * next tick immediately contradicts. Returns 0 when nothing has been sent
 * yet — there is nothing to resend, and the caller gates on that
 * separately.
 */
export function resendSecondsRemaining(
  lastSentAt: number | null,
  now: number
): number {
  if (lastSentAt === null) return 0;
  const elapsedSeconds = (now - lastSentAt) / 1000;
  return Math.max(0, Math.ceil(RESEND_COOLDOWN_SECONDS - elapsedSeconds));
}

/** True once the cooldown has elapsed and there is something to resend. */
export function canResend(lastSentAt: number | null, now: number): boolean {
  return lastSentAt !== null && resendSecondsRemaining(lastSentAt, now) === 0;
}
