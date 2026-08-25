"use client";

import { useEffect, useState } from "react";
import { setSessionFlag, useMediaQuery, useSessionFlag } from "@/lib/browserState";

/**
 * The brand mark, held for a beat while the app comes up.
 *
 * There was a launch video here, the same one iOS played. It did not look
 * good and has been dropped from both platforms; what is left is the still
 * mark that used to be the Reduce Motion fallback, which is all this ever
 * needed to be.
 *
 * Still once per session rather than every load, which is the one place a
 * browser differs from an app launch: a tab is opened and reopened all day,
 * and a splash on every one of those is an obstacle.
 */
const SEEN_KEY = "venn:launch-splash-seen";
const HOLD_MS = 900;
const FADE_MS = 420;

export function LaunchSplash() {
  const seen = useSessionFlag(SEEN_KEY);
  const reduceMotion = useMediaQuery("(prefers-reduced-motion: reduce)");

  const [done, setDone] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const showing = !seen && !done;

  useEffect(() => {
    if (!showing) return;

    let fade = 0;
    const timer = window.setTimeout(() => {
      setSessionFlag(SEEN_KEY);
      setLeaving(true);
      fade = window.setTimeout(() => setDone(true), FADE_MS);
    }, HOLD_MS);

    return () => {
      window.clearTimeout(timer);
      window.clearTimeout(fade);
    };
  }, [showing]);

  if (!showing) return null;

  return (
    <div
      role="status"
      aria-label="Venn loading"
      className="fixed inset-0 z-50 flex items-center justify-center bg-(--color-background)"
      style={{
        opacity: leaving ? 0 : 1,
        // Reduce Motion gets the mark without the fade, not a longer wait.
        transition: reduceMotion ? undefined : `opacity ${FADE_MS}ms`
      }}
    >
      <LaunchMark />
    </div>
  );
}

/**
 * Matches iOS's `StaticLaunchMark` ellipse for ellipse — one wide lobe
 * above, two tilted lobes below.
 */
function LaunchMark() {
  return (
    <svg
      viewBox="0 0 220 220"
      className="h-[180px] w-[180px] text-(--color-text-primary)"
      aria-hidden="true"
    >
      <ellipse cx="110" cy="46" rx="66" ry="39" fill="currentColor" />
      <ellipse
        cx="56"
        cy="136"
        rx="39"
        ry="66"
        fill="currentColor"
        transform="rotate(-18 56 136)"
      />
      <ellipse
        cx="164"
        cy="136"
        rx="39"
        ry="66"
        fill="currentColor"
        transform="rotate(18 164 136)"
      />
    </svg>
  );
}
