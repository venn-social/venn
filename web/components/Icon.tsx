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
function Svg({ size = 18, className, children }: IconProps & { children: React.ReactNode }) {
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
      {/* A plain heart, drawn plump. Wide round lobes, sides that curve
          the whole way down rather than running straight, and a tip that
          is the meeting of two curves instead of a corner. */}
      <path
        d="M12 20.6c-.5 0-.9-.2-1.3-.5C7.3 17.3 2.6 13.4 2.6 9.2 2.6 6.3 4.9 4 7.8 4c1.7 0 3.3.8 4.2 2.1C12.9 4.8 14.5 4 16.2 4c2.9 0 5.2 2.3 5.2 5.2 0 4.2-4.7 8.1-8.1 10.9-.4.3-.8.5-1.3.5Z"
        fill={filled ? "currentColor" : "none"}
        stroke="currentColor"
        strokeWidth={filled ? 0 : 1.8}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

export function CommentIcon({ filled = false, ...props }: FillableIconProps) {
  return (
    <Svg {...props}>
      {/* A plain speech bubble, drawn round: an oval body rather than a
          rounded rectangle, and a tail that grows out of the curve instead
          of being a triangle stuck to it. */}
      <path
        d="M12 4.4c-4.8 0-8.6 3.2-8.6 7.2 0 2.2 1.2 4.2 3 5.5-.1 1.4-.6 2.7-1.6 3.7 1.9-.2 3.6-.9 4.9-2 .7.1 1.5.2 2.3.2 4.8 0 8.6-3.2 8.6-7.4 0-4-3.8-7.2-8.6-7.2Z"
        fill={filled ? "currentColor" : "none"}
        stroke="currentColor"
        strokeWidth={filled ? 0 : 1.8}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

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

/** Scroll a horizontal row back. */
export function ChevronLeftIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="m15 6-6 6 6 6"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** Scroll a horizontal row on. */
export function ChevronRightIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="m9 6 6 6-6 6"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** The feed as a single column. */
export function ListLayoutIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <rect x="4" y="5" width="16" height="4" rx="1.5" fill="currentColor" />
      <rect x="4" y="11" width="16" height="4" rx="1.5" fill="currentColor" opacity="0.55" />
      <rect x="4" y="17" width="16" height="3" rx="1.5" fill="currentColor" opacity="0.3" />
    </Svg>
  );
}

/** The feed as a plane that carries on in every direction. */
export function PlaneLayoutIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <rect x="3" y="4" width="7" height="9" rx="1.5" fill="currentColor" />
      <rect x="13" y="7" width="7" height="9" rx="1.5" fill="currentColor" opacity="0.7" />
      <rect x="3" y="16" width="7" height="5" rx="1.5" fill="currentColor" opacity="0.45" />
      <rect x="13" y="19" width="7" height="2" rx="1" fill="currentColor" opacity="0.25" />
    </Svg>
  );
}

/** Edit — shown over your own avatar. */
export function PencilIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="M4 20h4L19 9a2.8 2.8 0 0 0-4-4L4 16v4Z"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** Saved for later. */
export function BookmarkIcon({ filled = false, ...props }: FillableIconProps) {
  return (
    <Svg {...props}>
      <path
        d="M6 4h12v16l-6-4-6 4V4Z"
        fill={filled ? "currentColor" : "none"}
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** Settings. Sliders rather than a cog — a cog at 19px reads as a sun. */
export function GearIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="M4 7h16M4 12h16M4 17h16"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
      />
      <circle cx="9" cy="7" r="2" fill="currentColor" />
      <circle cx="15" cy="12" r="2" fill="currentColor" />
      <circle cx="8" cy="17" r="2" fill="currentColor" />
    </Svg>
  );
}

/** Lists. */
export function ListIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="M8 6h12M8 12h12M8 18h12M4 6h.01M4 12h.01M4 18h.01"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
      />
    </Svg>
  );
}

/** Activity. */
export function BellIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="M18 8a6 6 0 1 0-12 0c0 7-3 8-3 8h18s-3-1-3-8M13.7 21a2 2 0 0 1-3.4 0"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </Svg>
  );
}

/** Last 12 Months. */
export function ChartIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <path
        d="M4 20V10m5 10V4m5 16v-7m5 7V8"
        fill="none"
        stroke="currentColor"
        strokeWidth={2}
        strokeLinecap="round"
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

/** Overflow control on artwork. */
export function MoreIcon(props: IconProps) {
  return (
    <Svg {...props}>
      <circle cx={5} cy={12} r={1.75} fill="currentColor" />
      <circle cx={12} cy={12} r={1.75} fill="currentColor" />
      <circle cx={19} cy={12} r={1.75} fill="currentColor" />
    </Svg>
  );
}
