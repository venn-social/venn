"use client";

import { ListLayoutIcon, PlaneLayoutIcon } from "@/components/Icon";
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
      {mode === "plane" ? plane : children}

      {/* Floating, bottom left, because this is a preference you set once
          and then want out of your way — not a heading the feed has to open
          with. Off to one side rather than centred keeps it clear of the
          column, which runs down the middle. Sitting over the content also
          means the plane keeps the whole viewport. */}
      <div
        role="group"
        aria-label="Feed layout"
        className="fixed bottom-5 left-5 z-20 flex items-center gap-1 rounded-pill border border-(--color-separator) bg-(--color-background)/85 p-1 shadow-lg backdrop-blur-md"
      >
        <Choice
          label="List"
          active={mode === "list"}
          onClick={() => choose("list")}
          icon={<ListLayoutIcon size={18} />}
        />
        <Choice
          label="Everywhere"
          active={mode === "plane"}
          onClick={() => choose("plane")}
          icon={<PlaneLayoutIcon size={18} />}
        />
      </div>
    </>
  );
}

function Choice({
  label,
  active,
  onClick,
  icon
}: {
  label: string;
  active: boolean;
  onClick: () => void;
  icon: React.ReactNode;
}) {
  return (
    <button
      type="button"
      aria-pressed={active}
      // The word is gone from the screen, so it has to survive here — this
      // is the only thing naming the control for a screen reader, and
      // "button, button" would be useless.
      aria-label={label}
      title={label}
      onClick={onClick}
      className={
        active
          ? "flex h-9 w-9 items-center justify-center rounded-pill bg-(--color-accent) text-(--color-on-accent)"
          : "flex h-9 w-9 items-center justify-center rounded-pill text-(--color-text-secondary) hover:text-(--color-text-primary)"
      }
    >
      {icon}
    </button>
  );
}
