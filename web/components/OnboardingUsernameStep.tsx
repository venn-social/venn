"use client";

import { useEffect, useState } from "react";
import { createProfile, isUsernameAvailable, UsernameTakenError } from "@/lib/onboarding";
import {
  sanitizeDisplayName,
  sanitizeHandle,
  type SanitizeReason,
  type SanitizeResult
} from "@/lib/sanitize";
import { createClient } from "@/lib/supabase/client";
import { CheckIcon, CrossIcon } from "@/components/Icon";

interface OnboardingUsernameStepProps {
  userId: string;
  onComplete: () => void;
}

type Availability =
  | { status: "idle" }
  | { status: "checking" }
  | { status: "available"; handle: string }
  | { status: "taken"; handle: string }
  | { status: "invalid"; message: string };

/**
 * The result of the last completed lookup, tagged with the handle it was
 * for. Tagging is what lets the displayed availability be derived during
 * render: a result whose handle no longer matches what's typed is stale,
 * which is exactly the "checking" state.
 */
type LookupResult = { handle: string; outcome: "available" | "taken" | "failed" };

const AVAILABILITY_DEBOUNCE_MS = 350;

function messageForReason(reason: SanitizeReason): string {
  switch (reason) {
    case "tooShort":
      return "Usernames need at least 3 characters.";
    case "tooLong":
      return "Usernames max out at 24 characters.";
    case "invalidCharacters":
      return "Only lowercase letters, numbers, _ and - are allowed.";
    case "empty":
      return "Usernames need at least 3 characters.";
  }
}

function deriveAvailability(
  handleResult: SanitizeResult | null,
  pendingHandle: string | null,
  lookup: LookupResult | null
): Availability {
  if (handleResult === null) return { status: "idle" };
  if (!handleResult.valid) {
    return { status: "invalid", message: messageForReason(handleResult.reason) };
  }
  // A result for a different handle is stale — we're still waiting on this one.
  if (pendingHandle === null || lookup?.handle !== pendingHandle) return { status: "checking" };
  // A failed lookup stays silent: it's advisory, and the insert is the real authority.
  if (lookup.outcome === "failed") return { status: "idle" };
  return { status: lookup.outcome, handle: pendingHandle };
}

export function OnboardingUsernameStep({ userId, onComplete }: OnboardingUsernameStepProps) {
  const [username, setUsername] = useState("");
  const [displayName, setDisplayName] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [lookup, setLookup] = useState<LookupResult | null>(null);
  const [submitError, setSubmitError] = useState("");

  // Validation is a pure function of what's typed, so it's derived here
  // rather than mirrored into state by an effect.
  const typed = username.trim();
  const handleResult = typed.length > 0 ? sanitizeHandle(typed) : null;
  const pendingHandle = handleResult?.valid ? handleResult.value : null;
  const availability = deriveAvailability(handleResult, pendingHandle, lookup);

  // The effect owns only the debounced network lookup; it writes state from
  // the timer callback, never synchronously during the effect body.
  useEffect(() => {
    if (pendingHandle === null) return;

    const timer = setTimeout(async () => {
      try {
        const free = await isUsernameAvailable(createClient(), pendingHandle);
        setLookup({ handle: pendingHandle, outcome: free ? "available" : "taken" });
      } catch {
        setLookup({ handle: pendingHandle, outcome: "failed" });
      }
    }, AVAILABILITY_DEBOUNCE_MS);

    return () => clearTimeout(timer);
  }, [pendingHandle]);

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setSubmitError("");

    const handleResult = sanitizeHandle(username);
    if (!handleResult.valid) {
      setSubmitError(messageForReason(handleResult.reason));
      return;
    }

    let name: string | null = null;
    if (displayName.trim().length > 0) {
      const nameResult = sanitizeDisplayName(displayName);
      if (!nameResult.valid) {
        setSubmitError("Display names max out at 40 characters.");
        return;
      }
      name = nameResult.value;
    }

    setSubmitting(true);
    try {
      const supabase = createClient();
      await createProfile(supabase, userId, handleResult.value, name);
      onComplete();
    } catch (error) {
      if (error instanceof UsernameTakenError) {
        setLookup({ handle: handleResult.value, outcome: "taken" });
        setSubmitError("That username is taken — try another.");
      } else {
        setSubmitError("Something went wrong. Please try again.");
      }
    } finally {
      setSubmitting(false);
    }
  }

  const canSubmit = !submitting && username.trim().length > 0;

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <p className="text-xs font-semibold text-(--color-text-secondary)">Step 1 of 2</p>
        <h1 className="text-xl font-semibold text-(--color-text-primary)">Claim your username</h1>
        <p className="text-(--color-text-secondary)">
          It&apos;s how people find you and your Venn. Lowercase letters, numbers, _ and - only.
        </p>
      </div>

      <form onSubmit={handleSubmit} className="flex flex-col gap-3">
        <div className="flex flex-col gap-1">
          <div className="flex items-center gap-1 rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2">
            <span className="text-(--color-text-secondary)">@</span>
            <input
              type="text"
              value={username}
              onChange={(event) => setUsername(event.target.value)}
              placeholder="username"
              autoComplete="username"
              autoCapitalize="off"
              autoCorrect="off"
              className="flex-1 bg-transparent text-(--color-text-primary) outline-none"
            />
            <AvailabilityIndicator availability={availability} />
          </div>
          <AvailabilityHint availability={availability} />
        </div>

        <input
          type="text"
          value={displayName}
          onChange={(event) => setDisplayName(event.target.value)}
          placeholder="Display name (optional)"
          autoComplete="name"
          className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
        />

        {submitError && <p className="text-sm text-red-500">{submitError}</p>}

        <button
          type="submit"
          disabled={!canSubmit}
          className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
        >
          {submitting ? "Creating…" : "Create profile"}
        </button>
      </form>
    </div>
  );
}

function AvailabilityIndicator({ availability }: { availability: Availability }) {
  switch (availability.status) {
    case "checking":
      return <span className="text-(--color-text-secondary)">…</span>;
    case "available":
      return <CheckIcon size={16} className="text-green-600" />;
    case "taken":
    case "invalid":
      return <CrossIcon size={16} className="text-red-500" />;
    default:
      return null;
  }
}

function AvailabilityHint({ availability }: { availability: Availability }) {
  switch (availability.status) {
    case "available":
      return <p className="text-sm text-green-600">@{availability.handle} is available</p>;
    case "taken":
      return <p className="text-sm text-red-500">@{availability.handle} is taken — try another</p>;
    case "invalid":
      return <p className="text-sm text-red-500">{availability.message}</p>;
    default:
      return null;
  }
}