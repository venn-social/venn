/**
 * rateLimit.ts — sliding-window rate limiter for client-side calls.
 *
 * IMPORTANT: this is a UX guard, NOT a security boundary. Real rate limiting
 * MUST live server-side (Postgres functions, Supabase Edge Functions, or a
 * gateway). Anything that runs in JavaScript on the user's device can be
 * bypassed by a determined attacker.
 *
 * Use this for:
 *   - Stopping users from accidentally double-tapping a "post" button.
 *   - Limiting expensive search queries to avoid hammering the backend.
 *   - Telegraphing rate limits to users with a friendly error before they hit
 *     a server-side 429.
 *
 * Don't use this for:
 *   - Preventing abuse (e.g., spam, scraping). Use Supabase RLS + a server-
 *     side limiter (CREATE FUNCTION + a counter table).
 *   - Auth flows — Supabase Auth has its own rate limits.
 *
 * Pair with server-side enforcement.
 */

export class RateLimitError extends Error {
  public readonly retryAfterMs: number;

  constructor(retryAfterMs: number) {
    super(`Rate limit hit. Try again in ${Math.ceil(retryAfterMs / 1000)}s.`);
    this.name = 'RateLimitError';
    this.retryAfterMs = retryAfterMs;
  }
}

export interface RateLimiter {
  /** Records a call. Throws RateLimitError if the window is full. */
  check: () => void;
  /** True if the next `check()` would succeed. Doesn't record a call. */
  isAllowed: () => boolean;
  /** Reset the window (e.g., after a successful retry). */
  reset: () => void;
}

/**
 * Build a sliding-window rate limiter.
 *
 *   const limiter = createRateLimiter({ maxCalls: 5, windowMs: 60_000 });
 *   try { limiter.check(); await postSomething(); }
 *   catch (e) { if (e instanceof RateLimitError) showToast(e.message); }
 */
export function createRateLimiter(options: {
  readonly maxCalls: number;
  readonly windowMs: number;
}): RateLimiter {
  const { maxCalls, windowMs } = options;
  if (maxCalls < 1) {
    throw new Error('maxCalls must be at least 1');
  }
  if (windowMs < 1) {
    throw new Error('windowMs must be at least 1');
  }

  let timestamps: number[] = [];

  function evict(now: number): void {
    const cutoff = now - windowMs;
    while (timestamps.length > 0 && timestamps[0] !== undefined && timestamps[0] < cutoff) {
      timestamps.shift();
    }
  }

  return {
    check(): void {
      const now = Date.now();
      evict(now);
      if (timestamps.length >= maxCalls) {
        const oldest = timestamps[0] ?? now;
        throw new RateLimitError(oldest + windowMs - now);
      }
      timestamps.push(now);
    },

    isAllowed(): boolean {
      const now = Date.now();
      evict(now);
      return timestamps.length < maxCalls;
    },

    reset(): void {
      timestamps = [];
    },
  };
}
