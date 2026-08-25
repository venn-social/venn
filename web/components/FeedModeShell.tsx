"use client";

import { useStoredPreference } from "@/lib/browserState";

export type FeedMode = "list" | "plane";

const STORAGE_KEY = "venn:feed-mode";

interface FeedModeShellProps {
  /** The ordinary vertical feed, server-rendered. */
  children: React.ReactNode;
  /** The pannable plane, rendered only while it is the chosen mode. */
  plane: React.ReactNode;
}

/**
 * Chooses between the two ways of reading the feed, and remembers which.
 *
 * The plane is an option rather than a replacement. A column is better when
 * you want to catch up in order and read captions; the plane is better when
 * you want to browse by eye. Neither is a strict improvement on the other,
 * so the switch stays visible and the column stays the default.
 *
 * The preference is read after mount rather than during render: it lives in
 * localStorage, which the server cannot see, and rendering the remembered
 * mode straight away would mismatch the HTML that was sent.
 */
const MODES = ["list", "plane"] as const;

export function FeedModeShell({ children, plane }: FeedModeShellProps) {
  const [mode, choose] = useStoredPreference<FeedMode>(STORAGE_KEY, MODES, "list");

  return (
    <>
      <div
        role="group"
        aria-label="Feed layout"
        className="mx-auto flex max-w-lg items-center gap-2 px-4 pt-4"
      >
        <Choice label="List" active={mode === "list"} onClick={() => choose("list")} />
        <Choice label="Everywhere" active={mode === "plane"} onClick={() => choose("plane")} />
      </div>

      {mode === "plane" ? plane : children}
    </>
  );
}

function Choice({
  label,
  active,
  onClick
}: {
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      aria-pressed={active}
      onClick={onClick}
      className={
        active
          ? "rounded-pill bg-(--color-accent) px-3 py-1.5 text-sm font-semibold text-(--color-on-accent)"
          : "rounded-pill border border-(--color-separator) px-3 py-1.5 text-sm text-(--color-text-primary)"
      }
    >
      {label}
    </button>
  );
}
