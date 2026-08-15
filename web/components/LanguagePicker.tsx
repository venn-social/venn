"use client";

import { useState } from "react";
import { LANGUAGES, type LanguageCode } from "@/lib/language";
import { updateLanguage } from "@/lib/profile";
import { createClient } from "@/lib/supabase/client";

interface LanguagePickerProps {
  userId: string;
  initialLanguage: LanguageCode;
}

/**
 * Which language the catalog is searched in.
 *
 * The copy is careful on purpose. This does not translate the app, and it
 * does not restate titles other people have already logged — `media` is one
 * shared row per item. Promising more than that would be the kind of setting
 * people toggle, see nothing change, and stop trusting.
 */
export function LanguagePicker({ userId, initialLanguage }: LanguagePickerProps) {
  const [language, setLanguage] = useState<LanguageCode>(initialLanguage);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");

  async function handleChange(next: LanguageCode) {
    const previous = language;
    setLanguage(next);
    setSaving(true);
    setError("");
    try {
      await updateLanguage(createClient(), userId, next);
    } catch {
      // Put the control back where it was rather than leaving it showing a
      // choice that was never saved.
      setLanguage(previous);
      setError("Couldn't save that. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="flex flex-col gap-2 rounded-lg border border-(--color-separator) p-4">
      <label htmlFor="language" className="font-medium text-(--color-text-primary)">
        Search language
      </label>
      <p className="text-sm text-(--color-text-secondary)">
        What the catalog is searched in. Titles other people have already logged stay as they
        were.
      </p>
      <select
        id="language"
        value={language}
        disabled={saving}
        onChange={(event) => void handleChange(event.target.value as LanguageCode)}
        className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) disabled:opacity-50"
      >
        {LANGUAGES.map((option) => (
          <option key={option.code} value={option.code}>
            {option.label}
          </option>
        ))}
      </select>
      {error && <p className="text-sm text-red-500">{error}</p>}
    </div>
  );
}
