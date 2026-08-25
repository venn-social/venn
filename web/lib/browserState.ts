"use client";

import { useSyncExternalStore } from "react";

/**
 * Reading browser-only facts without lying to the server.
 *
 * `localStorage`, `sessionStorage` and `matchMedia` do not exist while the
 * HTML is being rendered, and React 19 rejects the obvious workaround —
 * mirroring them into state from an effect (`react-hooks/set-state-in-effect`).
 * `useSyncExternalStore` is the primitive built for exactly this: it renders
 * the server's answer first, then swaps to the browser's without a hydration
 * mismatch.
 */

/** No store to subscribe to — the value is read once and never changes. */
function subscribeNever(): () => void {
  return () => {};
}

/** True when this tab has already seen `key`. Always false on the server. */
export function useSessionFlag(key: string): boolean {
  return useSyncExternalStore(
    subscribeNever,
    () => {
      try {
        return sessionStorage.getItem(key) === "1";
      } catch {
        // Private browsing, blocked storage. "Not seen" is the safe answer
        // for anything this guards — it costs a repeat, not correctness.
        return false;
      }
    },
    () => false
  );
}

export function setSessionFlag(key: string): void {
  try {
    sessionStorage.setItem(key, "1");
  } catch {
    // Not remembering costs one repeat and nothing else.
  }
}

/** A media query, live. Returns `false` on the server. */
export function useMediaQuery(query: string): boolean {
  return useSyncExternalStore(
    (onChange) => {
      const list = window.matchMedia(query);
      list.addEventListener("change", onChange);
      return () => list.removeEventListener("change", onChange);
    },
    () => window.matchMedia(query).matches,
    () => false
  );
}

/** Broadcast so every subscriber in the tab re-reads, not just the writer. */
const PREFERENCE_EVENT = "venn:preference";

/**
 * A remembered preference, one of a fixed set of values.
 *
 * Returns `fallback` on the server and until the browser's value is read,
 * so the first paint is always the default rather than a flicker of
 * something else.
 */
export function useStoredPreference<T extends string>(
  key: string,
  allowed: readonly T[],
  fallback: T
): [T, (next: T) => void] {
  const value = useSyncExternalStore(
    (onChange) => {
      window.addEventListener(PREFERENCE_EVENT, onChange);
      // Another tab changing it counts too.
      window.addEventListener("storage", onChange);
      return () => {
        window.removeEventListener(PREFERENCE_EVENT, onChange);
        window.removeEventListener("storage", onChange);
      };
    },
    () => {
      try {
        const stored = localStorage.getItem(key);
        return (allowed as readonly string[]).includes(stored ?? "") ? (stored as T) : fallback;
      } catch {
        return fallback;
      }
    },
    () => fallback
  );

  function set(next: T) {
    try {
      localStorage.setItem(key, next);
    } catch {
      // The choice still applies for this visit; it just will not persist.
    }
    window.dispatchEvent(new Event(PREFERENCE_EVENT));
  }

  return [value, set];
}
