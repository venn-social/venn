"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { updatePrivacy } from "@/lib/profile";
import { createClient } from "@/lib/supabase/client";

interface PrivacyToggleProps {
  userId: string;
  initialIsPrivate: boolean;
}

/**
 * The private-account switch, porting SettingsView.swift's privacy row —
 * same label and same explanatory copy.
 *
 * Optimistic: the switch moves immediately and reverts if the write fails.
 * Unlike following someone, the outcome here isn't in doubt — it's the
 * user's own row, and RLS already guarantees they may change it.
 */
export function PrivacyToggle({ userId, initialIsPrivate }: PrivacyToggleProps) {
  const router = useRouter();
  const [isPrivate, setIsPrivate] = useState(initialIsPrivate);
  const [saving, setSaving] = useState(false);
  const [failed, setFailed] = useState(false);

  async function handleChange(next: boolean) {
    setIsPrivate(next);
    setSaving(true);
    setFailed(false);

    try {
      await updatePrivacy(createClient(), userId, next);
      router.refresh();
    } catch {
      setIsPrivate(!next);
      setFailed(true);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="flex flex-col gap-2 py-3">
      <label className="flex items-start gap-3">
        <input
          type="checkbox"
          checked={isPrivate}
          disabled={saving}
          onChange={(event) => void handleChange(event.target.checked)}
          // Rounded to match everything around it. A native checkbox is
          // a hard square by default, which was the last corner left on
          // this screen.
          className="mt-1 h-4 w-4 shrink-0 rounded-sm accent-(--color-accent)"
        />
        <span className="flex flex-col gap-0.5">
          <span className="font-medium text-(--color-text-primary)">Private account</span>
          <span className="text-xs text-(--color-text-secondary)">
            Only approved followers see your posts, shelves, and Venn overlap. Your name, handle,
            and follower counts stay visible to everyone.
          </span>
        </span>
      </label>

      {failed && (
        <p className="text-sm text-red-500">Couldn&apos;t change that setting. Please try again.</p>
      )}
    </div>
  );
}
