/**
 * Choosing which form of an author's name to show.
 *
 * Open Library stores a Japanese author as 村上春樹 and a Russian one in
 * Cyrillic, because that is the name on the book. The app is in English, so
 * a shelf reading "2001 · 村上春樹" shows a name most of its readers cannot
 * read, search for, or say out loud.
 *
 * The author record carries a Latin form in `personal_name`, written
 * surname-first — "Murakami, Haruki". That is authoritative, unlike the
 * nineteen entries in `alternate_names`, which mix transliterations,
 * ALL-CAPS variants, other scripts, and in one case a research society.
 * Guessing from that list is how you end up showing "Kharuki Murakami".
 *
 * Mirrors ios/Venn/Utils/AuthorName.swift case for case.
 */

/**
 * True when every letter is Latin, so diacritics survive.
 *
 * Süskind and Céline must pass — the point is script, not ASCII. Latin
 * Unicode runs to Latin Extended-B and IPA at U+02AF; anything beyond is
 * Greek, Cyrillic, Hebrew, Arabic, CJK and the rest.
 */
export function isLatinScript(value: string): boolean {
  for (const character of value) {
    const code = character.codePointAt(0);
    if (code === undefined) continue;
    // \p{Alphabetic} keeps punctuation, spaces and digits out of the test.
    if (!/\p{Alphabetic}/u.test(character)) continue;
    if (code > 0x02af) return false;
  }
  return true;
}

/**
 * "Murakami, Haruki" → "Haruki Murakami".
 *
 * Only the single-comma case is flipped. "Smith, John, Jr." and other shapes
 * are left alone rather than reordered into something wrong.
 */
export function flippingSurnameFirst(value: string): string {
  const parts = value.split(",");
  if (parts.length !== 2) return value.trim();

  const surname = parts[0].trim();
  const given = parts[1].trim();
  if (!surname || !given) return value.trim();
  return `${given} ${surname}`;
}

/**
 * The name to display, preferring the reader's script.
 *
 * Keeps `name` whenever it is already Latin — most authors are, and their
 * `personal_name` is often a worse, surname-first duplicate. Falls back to
 * `name` when there is no Latin alternative, because a name in the wrong
 * script beats no name at all.
 */
export function preferredAuthorName(
  name: string | null | undefined,
  personalName: string | null | undefined
): string | null {
  if (!name) return personalName ? flippingSurnameFirst(personalName) : null;
  if (isLatinScript(name)) return name;
  if (!personalName) return name;

  const flipped = flippingSurnameFirst(personalName);
  return isLatinScript(flipped) ? flipped : name;
}
