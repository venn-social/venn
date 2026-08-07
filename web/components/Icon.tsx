/**
 * The icon set.
 *
 * Inline SVG rather than emoji or text glyphs, for three reasons that all
 * bit us: emoji render as a different picture on every platform and can't
 * be recoloured; `♥`/`♡` swap glyph *shape* between states rather than
 * just filling, and on systems that give U+2665 emoji presentation the
 * outline heart turns into a red emoji heart mid-interaction; and neither
 * can be sized against the surrounding type.
 *
 * These are the web counterparts of iOS's SF Symbols — same shapes, same
 * meanings (CLAUDE.md rule 17). Everything inherits `currentColor`, so
 * colour is the caller's business.
 */

interface IconProps {
  /** Rendered square size in px. Defaults to the size of body text. */
  size?: number;
  className?: string;
}

interface FillableIconProps extends IconProps {
  /** Solid when true, outline when false. */
  filled?: boolean;
}

/** Shared wrapper: one place for the viewBox and the a11y default. */
function Svg({
  size = 18,
  className,
  children
}: IconProps & { children: React.ReactNode }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      // Icons here are always paired with a text label or an aria-label on
      // the control, so announcing them again is noise.
      aria-hidden="true"
      focusable="false"
      className={className}
    >
      {children}
    </svg>
  );
}

/** Likes. Outline until liked, then solid — the shape never changes. */
export function HeartIcon({ filled = false, ...props }: FillableIconProps) {
  return (
    <Svg {...props}>
      <path
        d="M12 20.6 3.9 12.9a5.1 5.1 0 0 1 0-7.3 5.1 5.1 0 0 1 7.2 0l.9.9.9-.9a5.1 5.1 0 0 1 7.2 0 5.1 5.1 0 0 1 0 7.3L12 20.6Z"
        fill={filled ? "currentColor" : "none"}
        stroke="currentColor"
        strokeWidth={filled ? 0 : 1.8}
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** Comments. Mirrors iOS's `bubble.right`. */
export function CommentIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="M20.2 4H3.8A1.8 1.8 0 0 0 2 5.8v9.4A1.8 1.8 0 0 0 3.8 17H6v4l4.7-4h9.5a1.8 1.8 0 0 0 1.8-1.8V5.8A1.8 1.8 0 0 0 20.2 4Z"
        fill="none"
        stroke="currentColor"
        strokeWidth={1.8}
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** Ratings. Mirrors iOS's `star.fill`. */
export function StarIcon({ filled = true, ...props }: FillableIconProps) {
  return (
    <Svg {...props}>
      <path
        d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1-5.4-2.9-5.4 2.9 1-6.1L3.2 9.5l6.1-.9L12 3Z"
        fill={filled ? "currentColor" : "none"}
        stroke="currentColor"
        strokeWidth={filled ? 0 : 1.8}
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** "Like" in the composer. Mirrors iOS's `hand.thumbsup`. */
export function ThumbsUpIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="M7 10v10H4a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1h3Zm0 0 4.6-7.3a1 1 0 0 1 1.8.5V8h5.3a2 2 0 0 1 2 2.4l-1.4 7A2 2 0 0 1 17.3 19H7"
        fill="none"
        stroke="currentColor"
        strokeWidth={1.8}
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** "Dislike" in the composer — the same shape, turned over. */
export function ThumbsDownIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <g transform="rotate(180 12 12)">
        <path
          d="M7 10v10H4a1 1 0 0 1-1-1v-8a1 1 0 0 1 1-1h3Zm0 0 4.6-7.3a1 1 0 0 1 1.8.5V8h5.3a2 2 0 0 1 2 2.4l-1.4 7A2 2 0 0 1 17.3 19H7"
          fill="none"
          stroke="currentColor"
          strokeWidth={1.8}
          strokeLinejoin="round"
        />
      </g>
    </Svg>
  );
}

/** Accept, and the "username is free" tick. */
export function CheckIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="m4.5 12.5 5 5 10-11"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** Reject, and the "username is taken" cross. */
export function CrossIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="M6 6l12 12M18 6L6 18"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
      />
    </Svg>
  );
}

/** The compose action. */
export function PlusIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="M12 5v14M5 12h14"
        fill="none"
        stroke="currentColor"
        strokeWidth={2.2}
        strokeLinecap="round"
      />
    </Svg>
  );
}

/** Move a list item up. */
export function ChevronUpIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="m6 15 6-6 6 6"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** Move a list item down. */
export function ChevronDownIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="m6 9 6 6 6-6"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** Opens the secondary-surfaces panel. */
export function MenuIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="M4 7h16M4 12h16M4 17h16"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
      />
    </Svg>
  );
}
