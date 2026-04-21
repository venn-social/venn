/**
 * Pure utility functions for formatting values for display.
 * Every function here must be:
 *   - Pure (no side effects, no I/O).
 *   - Deterministic (same input → same output).
 *   - Fully typed.
 *   - Unit-tested (see formatters.test.ts).
 */

/**
 * Turn a timestamp into a human "5m ago", "3h ago", "2d ago" string.
 * For dates older than 7 days, returns a short date like "Mar 14".
 */
export function formatRelativeTime(iso: string, now: Date = new Date()): string {
  const then = new Date(iso);
  const diffMs = now.getTime() - then.getTime();
  const diffMinutes = Math.floor(diffMs / 60_000);
  const diffHours = Math.floor(diffMs / 3_600_000);
  const diffDays = Math.floor(diffMs / 86_400_000);

  if (diffMinutes < 1) {
    return 'just now';
  }
  if (diffMinutes < 60) {
    return `${diffMinutes}m ago`;
  }
  if (diffHours < 24) {
    return `${diffHours}h ago`;
  }
  if (diffDays < 7) {
    return `${diffDays}d ago`;
  }
  return then.toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
}

/**
 * Format a large count (like follower count) as "1.2K", "34.5K", "2.1M".
 */
export function formatCompactCount(n: number): string {
  if (n < 1_000) {
    return String(n);
  }
  if (n < 1_000_000) {
    return `${(n / 1_000).toFixed(1).replace(/\.0$/, '')}K`;
  }
  return `${(n / 1_000_000).toFixed(1).replace(/\.0$/, '')}M`;
}
