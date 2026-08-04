"use client";

import { useRouter } from "next/navigation";
import { useRef, useState } from "react";
import { Avatar } from "@/components/Avatar";
import { resizeToJPEG } from "@/lib/avatarImage";
import { uploadAvatar } from "@/lib/onboarding";
import { sanitizeBio, sanitizeDisplayName } from "@/lib/sanitize";
import { updateProfile } from "@/lib/profile";
import { createClient } from "@/lib/supabase/client";

const BIO_LIMIT = 160;

interface ProfileEditFormProps {
  userId: string;
  initialDisplayName: string;
  initialBio: string;
  initialAvatarUrl: string | null;
}

/**
 * Edit the signed-in user's photo, display name, and bio, porting
 * ProfileEditView.swift — same fields, same 160-character bio counter,
 * same "Edit profile" / "Change photo" / "Save" / "Cancel" copy.
 */
export function ProfileEditForm({
  userId,
  initialDisplayName,
  initialBio,
  initialAvatarUrl
}: ProfileEditFormProps) {
  const router = useRouter();
  const [displayName, setDisplayName] = useState(initialDisplayName);
  const [bio, setBio] = useState(initialBio);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [pickedPhoto, setPickedPhoto] = useState<Blob | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const overLimit = bio.length > BIO_LIMIT;

  async function handlePhotoChange(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setError("");

    try {
      // Decoding is where an unsupported or corrupt file gives out.
      const jpeg = await resizeToJPEG(file);
      setPickedPhoto(jpeg);
      setPreviewUrl((previous) => {
        if (previous) URL.revokeObjectURL(previous);
        return URL.createObjectURL(jpeg);
      });
    } catch {
      setPickedPhoto(null);
      setError("Couldn't read that photo. Try another one.");
    }
  }

  async function handleSubmit(event: React.FormEvent) {
    event.preventDefault();
    setError("");

    // An empty display name clears the column rather than storing "".
    let name: string | null = null;
    if (displayName.trim().length > 0) {
      const result = sanitizeDisplayName(displayName);
      if (!result.valid) {
        setError("Display names max out at 40 characters.");
        return;
      }
      name = result.value;
    }

    const bioResult = sanitizeBio(bio);
    if (!bioResult.valid) {
      setError(`Bios max out at ${BIO_LIMIT} characters.`);
      return;
    }

    setSaving(true);
    try {
      const supabase = createClient();
      // Photo first: if the upload fails the text edits aren't saved
      // either, so the user isn't left with a half-applied change and no
      // idea which half landed.
      if (pickedPhoto) {
        await uploadAvatar(supabase, userId, pickedPhoto);
      }
      await updateProfile(supabase, userId, name, bioResult.value || null);
      router.push("/profile");
      // Server Components cache the old profile until this invalidates it.
      router.refresh();
    } catch {
      setError("Couldn't save your changes. Please try again.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <form onSubmit={handleSubmit} className="flex flex-col gap-4">
      <h1 className="text-xl font-semibold text-(--color-text-primary)">Edit profile</h1>

      <div className="flex items-center gap-3">
        <Avatar name={displayName} avatarUrl={previewUrl ?? initialAvatarUrl} size={72} />
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          className="font-semibold text-(--color-accent)"
        >
          Change photo
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handlePhotoChange}
          className="hidden"
        />
      </div>

      <label className="flex flex-col gap-1">
        <span className="text-sm font-medium text-(--color-text-secondary)">Name</span>
        <input
          type="text"
          value={displayName}
          onChange={(event) => setDisplayName(event.target.value)}
          placeholder="Your name"
          autoComplete="name"
          className="rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
        />
      </label>

      <label className="flex flex-col gap-1">
        <span className="text-sm font-medium text-(--color-text-secondary)">Bio</span>
        <textarea
          value={bio}
          onChange={(event) => setBio(event.target.value)}
          placeholder="A short bio"
          rows={4}
          className="resize-none rounded-sm border border-(--color-separator) bg-(--color-surface-strong) px-3 py-2 text-(--color-text-primary) outline-none"
        />
        <span
          className={
            overLimit
              ? "self-end text-xs text-red-500"
              : "self-end text-xs text-(--color-text-secondary)"
          }
        >
          {bio.length} / {BIO_LIMIT}
        </span>
      </label>

      {error && <p className="text-sm text-red-500">{error}</p>}

      <div className="flex gap-3">
        <button
          type="submit"
          disabled={saving || overLimit}
          className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
        >
          {saving ? "Saving…" : "Save"}
        </button>
        <button
          type="button"
          onClick={() => router.push("/profile")}
          className="px-4 py-2 font-semibold text-(--color-text-secondary)"
        >
          Cancel
        </button>
      </div>
    </form>
  );
}
