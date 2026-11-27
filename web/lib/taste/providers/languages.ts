/**
 * Three-letter language codes → ISO 639-1. Open Library uses MARC (ISO
 * 639-2/B, "fre"); MusicBrainz uses ISO 639-3 ("fra"). Both spellings are
 * listed where they differ. A code not listed maps to null — a missing
 * language never counts as a mismatch (§1), so leaving a rare one out costs
 * nothing, while guessing one wrong would.
 */
const THREE_TO_TWO: Record<string, string> = {
  eng: "en",
  fre: "fr",
  fra: "fr",
  ger: "de",
  deu: "de",
  spa: "es",
  ita: "it",
  por: "pt",
  dut: "nl",
  nld: "nl",
  swe: "sv",
  nor: "no",
  nob: "nb",
  dan: "da",
  fin: "fi",
  ice: "is",
  isl: "is",
  pol: "pl",
  cze: "cs",
  ces: "cs",
  hun: "hu",
  rus: "ru",
  ukr: "uk",
  gre: "el",
  ell: "el",
  tur: "tr",
  ara: "ar",
  heb: "he",
  per: "fa",
  fas: "fa",
  hin: "hi",
  jpn: "ja",
  kor: "ko",
  chi: "zh",
  zho: "zh",
  vie: "vi",
  tha: "th",
  ind: "id",
  gle: "ga",
  wel: "cy",
  cym: "cy",
  cat: "ca",
  rum: "ro",
  ron: "ro",
  lat: "la"
};

export function languageFromThreeLetter(code: unknown): string | null {
  return typeof code === "string" ? (THREE_TO_TWO[code.toLowerCase()] ?? null) : null;
}
