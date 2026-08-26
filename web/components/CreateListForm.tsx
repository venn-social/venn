"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { createList } from "@/lib/lists";
import { normalise } from "@/lib/sanitize";
import { createClient } from "@/lib/supabase/client";
import { FIELD_CLASS } from "@/lib/formField";

const TITLE_LIMIT = 60;
const DESCRIPTION_LIMIT = 500;

/** Mirrors lists_title_length / lists_description_length. */
export function CreateListForm({ userId }: { userId: string }) {
  const router = useRouter();
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [isPublic, setIsPublic] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError("");

    const cleanTitle = normalise(title);
    if (cleanTitle.length === 0) {
      setError("Give the list a name.");
      return;
    }
    if (cleanTitle.length > TITLE_LIMIT) {
      setError(`Names max out at ${TITLE_LIMIT} characters.`);
      return;
    }

    const cleanDescription = normalise(description);
    if (cleanDescription.length > DESCRIPTION_LIMIT) {
      setError(`Descriptions max out at ${DESCRIPTION_LIMIT} characters.`);
      return;
    }

    setSubmitting(true);
    try {
      const id = await createList(
        createClient(),
        userId,
        cleanTitle,
        cleanDescription || null,
        isPublic
      );
      router.push(`/lists/${id}`);
      router.refresh();
    } catch (submitError) {
      setError(
        (submitError as { code?: string } | null)?.code === "P0429"
          ? "You're creating lists very fast — give it a moment."
          : "Couldn't create that list. Please try again."
      );
    } finally {
      setSubmitting(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-3">
      <input
        type="text"
        value={title}
        onChange={(event) => setTitle(event.target.value)}
        placeholder="List name"
        className={FIELD_CLASS}
      />
      <textarea
        value={description}
        onChange={(event) => setDescription(event.target.value)}
        placeholder="What's this list about? (optional)"
        rows={2}
        className={`${FIELD_CLASS} resize-none`}
      />

      <label className="flex items-center gap-2 text-sm text-(--color-text-secondary)">
        <input
          type="checkbox"
          checked={isPublic}
          onChange={(event) => setIsPublic(event.target.checked)}
          className="h-4 w-4 accent-(--color-accent)"
        />
        {/* Per-list, deliberately independent of the account privacy flag —
            a public account may still want a private list. */}
        Anyone can see this list
      </label>

      {error && <p className="text-sm text-red-500">{error}</p>}

      <button
        type="submit"
        disabled={submitting || title.trim().length === 0}
        className="self-start rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
      >
        {submitting ? "Creating…" : "Create list"}
      </button>
    </form>
  );
}
