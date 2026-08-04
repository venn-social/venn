/**
 * Prepares a picked photo for avatar upload: downscale to a sane pixel
 * budget and JPEG-encode. Ports ios/Venn/Utils/AvatarImage.swift's exact
 * numbers (512px max dimension, 0.8 quality) — 512px covers the largest
 * render size with margin; photos straight off a camera/phone are far
 * bigger than any avatar actually needs.
 */
export async function resizeToJPEG(
  file: File,
  maxDimension = 512,
  quality = 0.8
): Promise<Blob> {
  const bitmap = await createImageBitmap(file);
  const largest = Math.max(bitmap.width, bitmap.height);
  const scale = largest > maxDimension ? maxDimension / largest : 1;
  const targetWidth = Math.floor(bitmap.width * scale);
  const targetHeight = Math.floor(bitmap.height * scale);

  const canvas = document.createElement("canvas");
  canvas.width = targetWidth;
  canvas.height = targetHeight;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Canvas 2D context unavailable");
  ctx.drawImage(bitmap, 0, 0, targetWidth, targetHeight);
  bitmap.close();

  return new Promise<Blob>((resolve, reject) => {
    canvas.toBlob(
      (blob) => (blob ? resolve(blob) : reject(new Error("Failed to encode JPEG"))),
      "image/jpeg",
      quality
    );
  });
}