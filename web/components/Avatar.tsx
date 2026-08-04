interface AvatarProps {
  /** Display name or username — only the first character is used in the fallback. */
  name: string;
  avatarUrl: string | null;
  /** Rendered size in px. 72 matches the size both profile headers use. */
  size?: number;
}

/**
 * Profile image with an initial-in-a-circle fallback, mirroring iOS's
 * AvatarBadge. Plain <img> rather than next/image: avatars and cover art
 * come from four external hosts, and Vercel bills per image transformation
 * (see the Phase 3 spec).
 */
export function Avatar({ name, avatarUrl, size = 72 }: AvatarProps) {
  const initial = name.trim().charAt(0).toUpperCase() || "?";

  return (
    <div
      className="flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-(--color-graphite) font-semibold text-(--color-on-accent)"
      style={{ width: size, height: size, fontSize: Math.round(size / 3) }}
    >
      {avatarUrl ? (
        // eslint-disable-next-line @next/next/no-img-element -- see the component doc comment
        <img
          src={avatarUrl}
          alt=""
          width={size}
          height={size}
          loading="lazy"
          className="h-full w-full object-cover"
        />
      ) : (
        initial
      )}
    </div>
  );
}
