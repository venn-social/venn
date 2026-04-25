/**
 * sanitize.ts — input sanitization + Zod schemas for anything users type.
 *
 * Rule: every piece of user-typed input MUST go through a schema here before
 * it touches the database, the UI, or another user's screen. Don't write
 * one-off validation in screens or services — extend this file instead.
 *
 * What you get:
 *   - normalizeText: strips zero-width chars, control chars, and collapses
 *     whitespace. Use it as the base of any free-text validation.
 *   - Schemas (Username, Bio, Caption, SearchQuery, Url) ready to plug into
 *     react-hook-form's `zodResolver` or to validate manually with `.parse`.
 *
 * Server-side note: Postgres CHECK constraints (and RLS policies) are the
 * ultimate defence. Treat these client schemas as the first line, not the
 * last.
 */
import { z } from 'zod';

// Built once at module load. We construct the regexes from codepoint arrays
// rather than embedding the actual characters as regex literals, both to keep
// the source ASCII-clean (ESLint's no-irregular-whitespace would flag the
// literal forms) and to make the intent obvious to readers.

// Zero-width and bidirectional-override codepoints. Common in display-spoofing
// attacks (fake usernames, hidden invisibles in captions).
const SPOOFING_CODEPOINTS = [
  0x200b,
  0x200c,
  0x200d,
  0x200e,
  0x200f, // zero-width + LTR/RTL marks
  0x202a,
  0x202b,
  0x202c,
  0x202d,
  0x202e, // bidi embedding / override
  0xfeff, // BOM / zero-width no-break space
];
const ZERO_WIDTH = new RegExp(
  `[${SPOOFING_CODEPOINTS.map((cp) => String.fromCharCode(cp)).join('')}]`,
  'g',
);

// C0 (0x00-0x1F) and C1 (0x7F-0x9F) control chars, except keep TAB (0x09) and
// LF (0x0A) — TAB will be collapsed to space below; LF preserves caption
// wrapping.
const CONTROL_CODEPOINTS: number[] = [];
for (let cp = 0x00; cp <= 0x1f; cp += 1) {
  if (cp !== 0x09 && cp !== 0x0a) CONTROL_CODEPOINTS.push(cp);
}
for (let cp = 0x7f; cp <= 0x9f; cp += 1) CONTROL_CODEPOINTS.push(cp);
const CONTROL_CHARS = new RegExp(
  `[${CONTROL_CODEPOINTS.map((cp) => String.fromCharCode(cp)).join('')}]`,
  'g',
);

/**
 * Strip dangerous-looking unicode and collapse whitespace. Idempotent.
 * Caps consecutive blank lines at 2 to prevent comment-bombing while still
 * allowing one paragraph break.
 */
export function normalizeText(input: string): string {
  return input
    .normalize('NFC')
    .replace(ZERO_WIDTH, '')
    .replace(CONTROL_CHARS, '')
    .replace(/[ \t]+/g, ' ')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

export const UsernameSchema = z
  .string()
  .min(3, 'username must be at least 3 characters')
  .max(24, 'username must be at most 24 characters')
  .regex(/^[a-z0-9_-]+$/i, 'username can only contain letters, numbers, underscores, and hyphens')
  .transform((v) => v.toLowerCase());

export const BioSchema = z
  .string()
  .max(160, 'bio must be 160 characters or fewer')
  .transform(normalizeText);

export const DisplayNameSchema = z
  .string()
  .min(1, 'display name is required')
  .max(40, 'display name must be 40 characters or fewer')
  .transform(normalizeText);

export const CaptionSchema = z
  .string()
  .min(1, 'caption is required')
  .max(500, 'caption must be 500 characters or fewer')
  .transform(normalizeText)
  .refine((v) => v.length > 0, 'caption cannot be only whitespace');

export const SearchQuerySchema = z
  .string()
  .max(100, 'search query must be 100 characters or fewer')
  .transform(normalizeText);

/**
 * Only https:// URLs allowed. http:// is rejected (no plaintext links to
 * external content from user-generated fields).
 */
export const UrlSchema = z
  .string()
  .url('not a valid URL')
  .refine((v) => v.startsWith('https://'), 'only https:// URLs are allowed');

export type Username = z.infer<typeof UsernameSchema>;
export type Bio = z.infer<typeof BioSchema>;
export type DisplayName = z.infer<typeof DisplayNameSchema>;
export type Caption = z.infer<typeof CaptionSchema>;
export type SearchQuery = z.infer<typeof SearchQuerySchema>;
