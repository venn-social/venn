"use client";

import { useEffect, useRef, useState } from "react";
import {
  clampOffset,
  drawnSize,
  offsetAfterZoom,
  outputRect,
  type CropView
} from "@/lib/avatarCrop";

/** The round window you compose the picture inside, in CSS pixels. */
const VIEWPORT = 260;
/** Matches AvatarImage.swift: 512px, quality 0.8. */
const OUTPUT = 512;
const QUALITY = 0.8;
const MAX_ZOOM = 4;

interface AvatarCropperProps {
  file: File;
  onCancel: () => void;
  onConfirm: (jpeg: Blob) => void;
}

/**
 * Position and zoom a photo before it becomes an avatar.
 *
 * Picking a photo used to crop it centre-out and give you whatever that
 * happened to catch, which for most photos of a person is not their face.
 * The picture is dragged and zoomed inside a round window that shows
 * exactly what will be kept, so the preview is the result rather than an
 * approximation of it.
 *
 * The output is unchanged: 512px, JPEG at 0.8, the same numbers iOS uses.
 * Only the choice of *which* 512px is new.
 */
export function AvatarCropper({ file, onCancel, onConfirm }: AvatarCropperProps) {
  const [image, setImage] = useState<HTMLImageElement | null>(null);
  const [zoom, setZoom] = useState(1);
  const [offset, setOffset] = useState({ x: 0, y: 0 });
  const [failed, setFailed] = useState(false);
  const [working, setWorking] = useState(false);
  const drag = useRef<{ x: number; y: number; ox: number; oy: number } | null>(null);

  useEffect(() => {
    // A discarded run must not speak. React invokes effects twice in
    // development, and the first run's object URL is revoked by its own
    // cleanup — which fires `onerror` on an image nobody is waiting for.
    // Without this guard that stray failure sets the error state and the
    // cropper reports a perfectly good photo as unreadable.
    let cancelled = false;
    const url = URL.createObjectURL(file);
    const element = new Image();
    element.onload = () => {
      if (cancelled) return;
      setImage(element);
      // Start centred, which is where a centre-out crop would have been —
      // the same picture, now with somewhere to go.
      const view = { width: element.width, height: element.height, viewport: VIEWPORT, zoom: 1 };
      const drawn = drawnSize(view);
      setOffset(
        clampOffset(view, {
          x: (VIEWPORT - drawn.width) / 2,
          y: (VIEWPORT - drawn.height) / 2
        })
      );
    };
    element.onerror = () => {
      if (!cancelled) setFailed(true);
    };
    element.src = url;

    return () => {
      cancelled = true;
      URL.revokeObjectURL(url);
    };
  }, [file]);

  if (failed) {
    return (
      <div className="flex flex-col gap-3">
        <p className="text-sm text-red-500">Couldn&apos;t read that photo. Try another one.</p>
        <button
          type="button"
          onClick={onCancel}
          className="self-start font-semibold text-(--color-accent)"
        >
          Back
        </button>
      </div>
    );
  }

  if (!image) {
    return <p className="text-(--color-text-secondary)">Loading photo…</p>;
  }

  const view: CropView = { width: image.width, height: image.height, viewport: VIEWPORT, zoom };
  const drawn = drawnSize(view);

  function move(clientX: number, clientY: number) {
    const start = drag.current;
    if (!start) return;
    setOffset(
      clampOffset(view, { x: start.ox + (clientX - start.x), y: start.oy + (clientY - start.y) })
    );
  }

  function changeZoom(next: number) {
    setOffset(offsetAfterZoom(view, offset, next));
    setZoom(next);
  }

  async function confirm() {
    setWorking(true);
    try {
      const canvas = document.createElement("canvas");
      canvas.width = OUTPUT;
      canvas.height = OUTPUT;
      const ctx = canvas.getContext("2d");
      if (!ctx) throw new Error("Canvas 2D context unavailable");

      const rect = outputRect(view, offset, OUTPUT);
      ctx.drawImage(image!, rect.x, rect.y, rect.width, rect.height);

      const blob = await new Promise<Blob>((resolve, reject) => {
        canvas.toBlob(
          (result) => (result ? resolve(result) : reject(new Error("Failed to encode JPEG"))),
          "image/jpeg",
          QUALITY
        );
      });
      onConfirm(blob);
    } catch {
      setFailed(true);
    } finally {
      setWorking(false);
    }
  }

  return (
    <div className="flex flex-col items-center gap-4">
      <div
        // The window is round because the avatar is. Showing a square crop
        // and rounding it later is how you end up with a chin outside it.
        style={{ width: VIEWPORT, height: VIEWPORT }}
        className="relative touch-none overflow-hidden rounded-full bg-(--color-surface-strong)"
        onPointerDown={(event) => {
          drag.current = { x: event.clientX, y: event.clientY, ox: offset.x, oy: offset.y };
          event.currentTarget.setPointerCapture(event.pointerId);
        }}
        onPointerMove={(event) => move(event.clientX, event.clientY)}
        onPointerUp={() => (drag.current = null)}
        onPointerCancel={() => (drag.current = null)}
      >
        {/* eslint-disable-next-line @next/next/no-img-element -- a local object URL, not a remote asset */}
        <img
          src={image.src}
          alt=""
          draggable={false}
          style={{
            position: "absolute",
            left: offset.x,
            top: offset.y,
            width: drawn.width,
            height: drawn.height,
            maxWidth: "none",
            cursor: "grab"
          }}
        />
      </div>

      <label className="flex w-full max-w-[260px] items-center gap-3">
        <span className="sr-only">Zoom</span>
        <input
          type="range"
          min={1}
          max={MAX_ZOOM}
          step={0.01}
          value={zoom}
          onChange={(event) => changeZoom(Number(event.target.value))}
          className="w-full accent-(--color-accent)"
        />
      </label>

      <div className="flex items-center gap-3">
        <button
          type="button"
          disabled={working}
          onClick={() => void confirm()}
          className="rounded-pill bg-(--color-accent) px-4 py-2 font-semibold text-(--color-on-accent) disabled:opacity-50"
        >
          {working ? "Saving…" : "Use photo"}
        </button>
        <button
          type="button"
          onClick={onCancel}
          className="px-2 py-2 font-semibold text-(--color-text-secondary) hover:text-(--color-text-primary)"
        >
          Cancel
        </button>
      </div>
    </div>
  );
}
