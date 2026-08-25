"use client";

import { useEffect, useState } from "react";
import { setSessionFlag, useMediaQuery, useSessionFlag } from "@/lib/browserState";

/**
 * The brand intro, ported from iOS's `LaunchVideoSplashView`.
 *
 * iOS has shown this since launch and web never did, which meant the two
 * platforms introduced themselves completely differently. Same two videos,
 * same still fallback mark, same "Venn loading" label.
 *
 * Two deliberate departures from iOS, both because a browser is not an app
 * launch:
 *
 *   - **Once per session.** iOS shows this on every cold start, which is
 *     rare. A tab is opened, closed and reopened all day, and a brand intro
 *     on every one of those is an obstacle rather than an introduction.
 *   - **Capped.** iOS waits for the video to end, and `venn-launch-light`
 *     runs 7.3s. Nobody should wait that long to read a feed, so this
 *     dismisses on `ended` or at the cap, whichever comes first.
 */
const SEEN_KEY = "venn:launch-splash-seen";
/** Long enough to read as intentional, short enough not to be a toll. */
const MAX_VISIBLE_MS = 3200;
/** Reduce Motion sees a still mark, so it needs only a beat. */
const STATIC_HOLD_MS = 1200;
const FADE_MS = 420;

export function LaunchSplash() {
  const seen = useSessionFlag(SEEN_KEY);
  const reduceMotion = useMediaQuery("(prefers-reduced-motion: reduce)");
  const dark = useMediaQuery("(prefers-color-scheme: dark)");

  const [done, setDone] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const showing = !seen && !done;

  useEffect(() => {
    if (!showing) return;

    let fade = 0;
    function dismiss() {
      setSessionFlag(SEEN_KEY);
      setLeaving(true);
      fade = window.setTimeout(() => setDone(true), FADE_MS);
    }

    // The cap doubles as the safety net: if the video never loads, `ended`
    // never fires, and the page would sit behind the overlay forever. iOS
    // carries the same fallback for the same reason.
    const timer = window.setTimeout(dismiss, reduceMotion ? STATIC_HOLD_MS : MAX_VISIBLE_MS);
    window.addEventListener(ENDED_EVENT, dismiss);

    return () => {
      window.clearTimeout(timer);
      window.clearTimeout(fade);
      window.removeEventListener(ENDED_EVENT, dismiss);
    };
  }, [showing, reduceMotion]);

  if (!showing) return null;

  return (
    <div
      role="status"
      aria-label="Venn loading"
      className="fixed inset-0 z-50 flex items-center justify-center bg-(--color-background) transition-opacity duration-[420ms]"
      style={{ opacity: leaving ? 0 : 1 }}
    >
      {reduceMotion ? (
        <LaunchMark />
      ) : (
        <video
          key={dark ? "dark" : "light"}
          src={`/launch/venn-launch-${dark ? "dark" : "light"}.mp4`}
          autoPlay
          muted
          playsInline
          aria-hidden="true"
          onEnded={() => window.dispatchEvent(new Event(ENDED_EVENT))}
          // A missing or unplayable file must not hold the page hostage.
          onError={() => window.dispatchEvent(new Event(ENDED_EVENT))}
          className="h-full w-full object-cover"
        />
      )}
    </div>
  );
}

const ENDED_EVENT = "venn:splash-ended";

/**
 * The still mark, matching iOS's `StaticLaunchMark` ellipse for ellipse —
 * one wide lobe above, two tilted lobes below. Shown to Reduce Motion users
 * in place of the video.
 */
function LaunchMark() {
  return (
    <svg
      viewBox="0 0 220 220"
      className="h-[220px] w-[220px] text-(--color-text-primary)"
      aria-hidden="true"
    >
      <ellipse cx="110" cy="46" rx="66" ry="39" fill="currentColor" />
      <ellipse cx="56" cy="136" rx="39" ry="66" fill="currentColor" transform="rotate(-18 56 136)" />
      <ellipse cx="164" cy="136" rx="39" ry="66" fill="currentColor" transform="rotate(18 164 136)" />
    </svg>
  );
}
