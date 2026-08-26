"use client";

import { useRef, useState } from "react";
import { AvatarCropper } from "@/components/AvatarCropper";
import { uploadAvatar } from "@/lib/onboarding";
import { createClient } from "@/lib/supabase/client";

interface OnboardingPhotoStepProps {
  userId: string;
  onComplete: () => void;
}

export function OnboardingPhotoStep({ userId, onComplete }: OnboardingPhotoStepProps) {
  const [previewUrl, setPreviewUrl] = useState<string | null>(null);
  const [pickedBlob, setPickedBlob] = useState<Blob | null>(null);
  const [uploading, setUploading] = useState(false);
  const [failed, setFailed] = useState(false);
  const fileInputRef = useRef<HTMLInputElement>(null);
  /** The photo being positioned, if any. */
  const [cropping, setCropping] = useState<File | null>(null);

  function handleFileChange(event: React.ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0];
    if (!file) return;
    setFailed(false);
    // Same cropper the edit screen uses. Choosing a photo is one act, and
    // it should not go differently depending on which door you came in.
    setCropping(file);
    event.target.value = "";
  }

  function handleCropped(jpeg: Blob) {
    setCropping(null);
    setPickedBlob(jpeg);
    setPreviewUrl((previous) => {
      if (previous) URL.revokeObjectURL(previous);
      return URL.createObjectURL(jpeg);
    });
  }

  async function handleContinue() {
    if (!pickedBlob) return;
    setFailed(false);
    setUploading(true);
    try {
      const supabase = createClient();
      await uploadAvatar(supabase, userId, pickedBlob);
      onComplete();
    } catch {
      setFailed(true);
    } finally {
      setUploading(false);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-col gap-1">
        <p className="text-xs font-semibold text-(--color-text-secondary)">Step 2 of 2</p>
        <h1 className="text-xl font-semibold text-(--color-text-primary)">
          Add a face to the name
        </h1>
        <p className="text-(--color-text-secondary)">
          Your photo shows up next to everything you log. You can always change it later.
        </p>
      </div>

      {cropping && (
        <AvatarCropper
          file={cropping}
          onCancel={() => setCropping(null)}
          onConfirm={handleCropped}
        />
      )}

      <div className={cropping ? "hidden" : "flex justify-center"}>
        <button
          type="button"
          onClick={() => fileInputRef.current?.click()}
          aria-label="Choose a photo"
          className="flex h-[140px] w-[140px] items-center justify-center overflow-hidden rounded-full bg-(--color-surface-strong)"
        >
          {previewUrl ? (
            // eslint-disable-next-line @next/next/no-img-element -- local object URL, not a remote asset
            <img src={previewUrl} alt="" className="h-full w-full object-cover" />
          ) : (
            <span className="text-(--color-accent)">Choose photo</span>
          )}
        </button>
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          onChange={handleFileChange}
          className="hidden"
        />
      </div>

      {failed && (
        <p className="text-sm text-red-500">
          Couldn&apos;t upload that photo. Try again — or skip and add one later.
        </p>
      )}

      <button
        type="button"
        onClick={handleContinue}
        disabled={!pickedBlob || uploading}
        className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
      >
        {uploading ? "Uploading…" : "Continue"}
      </button>

      <button
        type="button"
        onClick={onComplete}
        className="text-sm font-semibold text-(--color-text-secondary)"
      >
        Skip for now
      </button>
    </div>
  );
}
