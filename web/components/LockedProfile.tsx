interface LockedProfileProps {
  username: string;
}

/**
 * Mirrors PublicProfileView's lockedContent — shown instead of the
 * overlap section and shelves when the account is private and the
 * viewer isn't an accepted follower yet.
 */
export function LockedProfile({ username }: LockedProfileProps) {
  return (
    <div className="flex flex-col items-center gap-2 py-12 text-center">
      <svg
        width="32"
        height="32"
        viewBox="0 0 24 24"
        fill="none"
        stroke="var(--color-text-secondary)"
        strokeWidth={1.5}
        aria-hidden
      >
        <rect x="5" y="11" width="14" height="10" rx="2" />
        <path d="M8 11V7a4 4 0 0 1 8 0v4" />
      </svg>
      <h2 className="text-lg font-semibold text-(--color-text-primary)">This account is private</h2>
      <p className="max-w-xs text-(--color-text-secondary)">
        Follow @{username} to see their posts and your taste overlap.
      </p>
    </div>
  );
}
