"use client";

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { Composer } from "@/components/Composer";
import { CrossIcon } from "@/components/Icon";
import type { MediaCandidate } from "@/lib/catalog/types";

interface ComposerLauncherProps {
  userId: string;
  /** Rendered inside the trigger — an icon in the nav, a label on a page. */
  children: React.ReactNode;
  className?: string;
  /** The trigger's accessible name, when its content is only an icon. */
  label?: string;
  /** Opening for a title that is already decided, from its own page. */
  initialPicked?: MediaCandidate | null;
}

/**
 * Opens the composer over whatever you were looking at.
 *
 * Logging used to be a page you were sent to and then had to come back
 * from, which loses your place and turns a small act into a trip. It is a
 * detour by nature — you are always in the middle of something else when
 * you decide to log — so it belongs on top of that something else.
 *
 * `/composer` still exists as a route. It is a real address worth being
 * able to link to and land on directly, and it is where this falls back to
 * without JavaScript.
 */
export function ComposerLauncher({
  userId,
  children,
  className,
  label,
  initialPicked = null
}: ComposerLauncherProps) {
  const [open, setOpen] = useState(false);

  // Escape closes it, and the page behind must not scroll while it is up.
  useEffect(() => {
    if (!open) return;

    function onKey(event: KeyboardEvent) {
      if (event.key === "Escape") setOpen(false);
    }
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    window.addEventListener("keydown", onKey);

    return () => {
      document.body.style.overflow = previous;
      window.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <>
      <button type="button" aria-label={label} className={className} onClick={() => setOpen(true)}>
        {children}
      </button>

      {open &&
        // Rendered into <body>, not where the trigger sits. The nav is
        // `sticky` with a z-index, which makes it a stacking context — a
        // sheet opened from the plus button was sealed inside it, unable
        // to rise above anything outside no matter how large its own
        // z-index. That is invisible until something overlaps it.
        createPortal(
          <div
            role="dialog"
            aria-modal="true"
            aria-label="Log something"
            className="fixed inset-0 z-[60] flex items-start justify-center overflow-y-auto bg-black/40 p-4 backdrop-blur-sm sm:p-8"
            // A click on the backdrop dismisses; one inside the sheet must
            // not, or picking a title would close the thing you picked it in.
            onClick={(event) => {
              if (event.target === event.currentTarget) setOpen(false);
            }}
          >
            <div className="w-full max-w-lg rounded-2xl bg-(--color-background) px-4 pb-6 shadow-2xl">
              {/* Just a way out. The tabs and the field below say what this
                  is, so a heading would only be a line of chrome repeating
                  them. The dialog keeps its name for screen readers. */}
              <div className="flex justify-end pt-3">
                <button
                  type="button"
                  onClick={() => setOpen(false)}
                  aria-label="Close"
                  className="-mr-1 rounded-pill p-1.5 text-(--color-text-secondary) hover:text-(--color-text-primary)"
                >
                  <CrossIcon size={18} />
                </button>
              </div>

              <Composer
                userId={userId}
                initialPicked={initialPicked}
                onDone={() => setOpen(false)}
              />
            </div>
          </div>,
          document.body
        )}
    </>
  );
}
