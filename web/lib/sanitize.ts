/**
 * Ports Sanitize.handle / Sanitize.displayName / Sanitize.normalise from
 * ios/Venn/Utils/Sanitize.swift — same bounds, same allowed characters,
 * same control/zero-width/bidi-override stripping. Per CLAUDE.md rule 7,
 * this is the first line of defense; the profiles_username_format and
 * profiles_display_name_length CHECK constraints in supabase/migrations/
 * are the last.
 */

export type SanitizeReason = "empty" | "tooShort" | "tooLong" | "invalidCharacters";

export type SanitizeResult =
  | { valid: true; value: string }
  | { valid: false; reason: SanitizeReason };

const HANDLE_PATTERN = /^[a-z0-9_-]+$/;

/** Lowercased, 3-24 chars, [a-z0-9_-] only. Mirrors profiles_username_format. */
export function sanitizeHandle(input: string): SanitizeResult {
  const trimmed = input.trim().toLowerCase();
  if (trimmed.length < 3) return { valid: false, reason: "tooShort" };
  if (trimmed.length > 24) return { valid: false, reason: "tooLong" };
  if (!HANDLE_PATTERN.test(trimmed)) return { valid: false, reason: "invalidCharacters" };
  return { valid: true, value: trimmed };
}

function isProblematic(codePoint: number): boolean {
  // C0 controls, except tab (0x09) + newline (0x0A).
  if (codePoint <= 0x1f && codePoint !== 0x09 && codePoint !== 0x0a) return true;
  // DEL + C1 controls.
  if (codePoint >= 0x7f && codePoint <= 0x9f) return true;
  // Zero-width / direction marks.
  if (codePoint >= 0x200b && codePoint <= 0x200f) return true;
  // Bidi embedding / override.
  if (codePoint >= 0x202a && codePoint <= 0x202e) return true;
  // Byte order mark / zero-width no-break space.
  if (codePoint === 0xfeff) return true;
  return false;
}

/**
 * NFC-normalizes, strips control/zero-width/bidi-override characters,
 * collapses runs of spaces/tabs to one, caps runs of 3+ blank lines at
 * 2, and trims edges. Idempotent.
 */
export function normalise(input: string): string {
  const nfc = input.normalize("NFC");
  let stripped = "";
  for (const char of nfc) {
    const codePoint = char.codePointAt(0);
    if (codePoint === undefined || !isProblematic(codePoint)) stripped += char;
  }
  const collapsedSpaces = stripped.replace(/[ \t]+/g, " ");
  const collapsedBlankLines = collapsedSpaces.replace(/\n{3,}/g, "\n\n");
  return collapsedBlankLines.trim();
}

/**
 * Bio. Optional (empty is allowed and means "no bio"), max 160 chars after
 * normalise. Mirrors Sanitize.bio and the profiles_bio_length constraint.
 */
export function sanitizeBio(input: string): SanitizeResult {
  const normalised = normalise(input);
  if (normalised.length > 160) return { valid: false, reason: "tooLong" };
  return { valid: true, value: normalised };
}

/**
 * Post caption. Required, 1-500 chars after normalise. Mirrors
 * Sanitize.caption and the posts_caption_length constraint.
 */
export function sanitizeCaption(input: string): SanitizeResult {
  const normalised = normalise(input);
  if (normalised.length === 0) return { valid: false, reason: "empty" };
  if (normalised.length > 500) return { valid: false, reason: "tooLong" };
  return { valid: true, value: normalised };
}

/**
 * Search query. Optional (empty is valid — an empty box isn't an error),
 * max 100 chars after normalise. Mirrors Sanitize.searchQuery.
 */
export function sanitizeSearchQuery(input: string): SanitizeResult {
  const normalised = normalise(input);
  if (normalised.length > 100) return { valid: false, reason: "tooLong" };
  return { valid: true, value: normalised };
}

/** 1-40 chars after normalise, empty is invalid. Mirrors profiles_display_name_length. */
export function sanitizeDisplayName(input: string): SanitizeResult {
  const normalised = normalise(input);
  if (normalised.length === 0) return { valid: false, reason: "empty" };
  if (normalised.length > 40) return { valid: false, reason: "tooLong" };
  return { valid: true, value: normalised };
}