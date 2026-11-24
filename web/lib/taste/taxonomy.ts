/**
 * The cross-media taxonomy: one tree of nodes that mean the same thing in
 * every medium, and the rules that map each catalog's vocabulary onto it.
 *
 * Spec: docs/superpowers/specs/2026-11-17-taste-engine-design.md §1.3.
 *
 * This file is the seed. The extraction script upserts it into
 * `taxonomy_nodes` / `taxonomy_mappings`, and from then on the database is
 * what extraction reads — so a mapping someone adds by hand in the table is
 * honoured without a deploy.
 *
 * What is deliberately NOT here: the curated ~200 TMDB keywords and ~300 Open
 * Library subjects the spec describes. Those need a human pass (open question
 * 4). Until then the only keyword/subject/genre mappings are exact name
 * matches against node names plus a short list of spelling variants — which
 * is not guessing, and is the same rule for every catalog.
 */

import type { MediaKind } from "@/lib/media";

export type MappingSource =
  "tmdb_genre" | "tmdb_keyword" | "openlibrary_subject" | "musicbrainz_genre" | "musicbrainz_tag";

export interface TaxonomyNode {
  slug: string;
  /** Null for a family (top-level) node. */
  parent: string | null;
  family: string;
  /** Null = every kind. */
  kindScope: MediaKind[] | null;
}

export interface TaxonomyMapping {
  source: MappingSource;
  sourceKey: string;
  node: string;
  weight: number;
}

/** A term as a catalog reported it, before mapping. */
export interface CatalogTerm {
  source: MappingSource;
  key: string;
}

const ALBUM_ONLY: MediaKind[] = ["album"];

/** The spec's 18 families and their children, in its order. */
const FAMILIES: { family: string; children: string[]; kindScope: MediaKind[] | null }[] = [
  {
    family: "crime",
    children: ["noir", "heist", "detective", "gangster", "legal"],
    kindScope: null
  },
  {
    family: "thriller",
    children: ["psychological", "political", "conspiracy", "survival"],
    kindScope: null
  },
  {
    family: "horror",
    children: ["supernatural", "folk-horror", "body-horror", "gothic", "slasher"],
    kindScope: null
  },
  {
    family: "speculative",
    children: ["science-fiction", "cyberpunk", "dystopia", "space", "time-travel"],
    kindScope: null
  },
  {
    family: "fantasy",
    children: ["high-fantasy", "fairy-tale", "magical-realism", "mythic"],
    kindScope: null
  },
  {
    family: "drama",
    children: ["family", "coming-of-age", "character-study", "melodrama"],
    kindScope: null
  },
  {
    family: "romance",
    children: ["romantic-comedy", "tragic-romance", "queer-romance"],
    kindScope: null
  },
  {
    family: "comedy",
    children: ["satire", "absurdist", "dark-comedy", "slapstick"],
    kindScope: null
  },
  {
    family: "war-history",
    children: ["war", "period", "biography", "historical-epic"],
    kindScope: null
  },
  {
    family: "adventure",
    children: ["quest", "western", "swashbuckler", "exploration"],
    kindScope: null
  },
  {
    family: "documentary-nonfiction",
    children: ["memoir", "essay", "true-crime", "science", "politics"],
    kindScope: null
  },
  { family: "family-children", children: ["animation", "picture-book", "kids"], kindScope: null },
  {
    family: "music-performance",
    children: ["musical", "concert", "music-biography"],
    kindScope: null
  },
  {
    family: "literary-art",
    children: ["experimental", "minimalist", "surreal", "arthouse"],
    kindScope: null
  },
  { family: "rock", children: ["punk", "post-punk", "indie", "shoegaze"], kindScope: ALBUM_ONLY },
  {
    family: "electronic",
    children: ["ambient", "techno", "house", "synth-pop"],
    kindScope: ALBUM_ONLY
  },
  {
    family: "soul-hiphop",
    children: ["hip-hop", "r-and-b", "soul", "funk", "jazz"],
    kindScope: ALBUM_ONLY
  },
  {
    family: "folk-classical",
    children: ["folk", "singer-songwriter", "classical", "country"],
    kindScope: ALBUM_ONLY
  }
];

export const TAXONOMY_NODES: TaxonomyNode[] = FAMILIES.flatMap(
  ({ family, children, kindScope }) => [
    { slug: family, parent: null, family, kindScope },
    ...children.map((slug) => ({ slug, parent: family, family, kindScope }))
  ]
);

/** The client copy key for a node. Clients own the words (rule 17). */
export function labelKey(slug: string): string {
  return `taxonomy.${slug.replace(/-/g, "_")}`;
}

/**
 * Every TMDB movie and TV genre id, all 27. Two map to nothing on purpose:
 * "TV Movie" and "Talk" are formats, not anything a film and a novel could
 * share. They are listed so the table is visibly complete.
 */
export const TMDB_GENRES: Record<string, { name: string; nodes: [string, number][] }> = {
  "28": {
    name: "Action",
    nodes: [
      ["adventure", 0.6],
      ["thriller", 0.4]
    ]
  },
  "12": { name: "Adventure", nodes: [["adventure", 1]] },
  "16": { name: "Animation", nodes: [["animation", 1]] },
  "35": { name: "Comedy", nodes: [["comedy", 1]] },
  "80": { name: "Crime", nodes: [["crime", 1]] },
  "99": { name: "Documentary", nodes: [["documentary-nonfiction", 1]] },
  "18": { name: "Drama", nodes: [["drama", 1]] },
  "10751": { name: "Family", nodes: [["family-children", 1]] },
  "14": { name: "Fantasy", nodes: [["fantasy", 1]] },
  "36": { name: "History", nodes: [["period", 1]] },
  "27": { name: "Horror", nodes: [["horror", 1]] },
  "10402": { name: "Music", nodes: [["music-performance", 1]] },
  "9648": { name: "Mystery", nodes: [["detective", 1]] },
  "10749": { name: "Romance", nodes: [["romance", 1]] },
  "878": { name: "Science Fiction", nodes: [["science-fiction", 1]] },
  "10770": { name: "TV Movie", nodes: [] },
  "53": { name: "Thriller", nodes: [["thriller", 1]] },
  "10752": { name: "War", nodes: [["war", 1]] },
  "37": { name: "Western", nodes: [["western", 1]] },
  "10759": { name: "Action & Adventure", nodes: [["adventure", 1]] },
  "10762": { name: "Kids", nodes: [["kids", 1]] },
  "10763": { name: "News", nodes: [["politics", 1]] },
  "10764": { name: "Reality", nodes: [["documentary-nonfiction", 0.5]] },
  "10765": {
    name: "Sci-Fi & Fantasy",
    nodes: [
      ["speculative", 0.5],
      ["fantasy", 0.5]
    ]
  },
  "10766": { name: "Soap", nodes: [["melodrama", 1]] },
  "10767": { name: "Talk", nodes: [] },
  "10768": {
    name: "War & Politics",
    nodes: [
      ["war-history", 0.5],
      ["political", 0.5]
    ]
  }
};

/**
 * Spelling variants that mean exactly a node — not judgement calls. A term
 * reaching here has already been through normalizeTerm.
 */
const VARIANTS: Record<string, string> = {
  "film-noir": "noir",
  "neo-noir": "noir",
  "sci-fi": "science-fiction",
  "science-fiction-fiction": "science-fiction",
  "detective-and-mystery-stories": "detective",
  mystery: "detective",
  "rhythm-and-blues": "r-and-b",
  rnb: "r-and-b",
  "hip-hop-music": "hip-hop",
  hiphop: "hip-hop",
  synthpop: "synth-pop",
  postpunk: "post-punk",
  "fairy-tales": "fairy-tale",
  biographies: "biography",
  memoirs: "memoir",
  essays: "essay",
  musicals: "musical",
  westerns: "western"
};

/** "Film Noir" → "film-noir"; "R&B" → "r-and-b". Same rule for every catalog. */
export function normalizeTerm(term: string): string {
  return term
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[̀-ͯ]/g, "")
    .replace(/&/g, " and ")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

const NAME_SOURCES: MappingSource[] = [
  "tmdb_keyword",
  "openlibrary_subject",
  "musicbrainz_genre",
  "musicbrainz_tag"
];

/** The seed mapping rows: TMDB genre ids, plus node names and variants for every other source. */
export function seedMappings(): TaxonomyMapping[] {
  const rows: TaxonomyMapping[] = [];
  for (const [id, genre] of Object.entries(TMDB_GENRES)) {
    for (const [node, weight] of genre.nodes) {
      rows.push({ source: "tmdb_genre", sourceKey: id, node, weight });
    }
  }
  const names: [string, string][] = [
    ...TAXONOMY_NODES.map((node): [string, string] => [node.slug, node.slug]),
    ...Object.entries(VARIANTS)
  ];
  for (const source of NAME_SOURCES) {
    for (const [key, node] of names) rows.push({ source, sourceKey: key, node, weight: 1 });
  }
  return rows;
}

/** Index mappings for lookup. Name-based sources are keyed by their normalised form. */
export function indexMappings(rows: TaxonomyMapping[]): Map<string, TaxonomyMapping[]> {
  const index = new Map<string, TaxonomyMapping[]>();
  for (const row of rows) {
    const key = `${row.source}|${row.source === "tmdb_genre" ? row.sourceKey : normalizeTerm(row.sourceKey)}`;
    const list = index.get(key) ?? [];
    if (!list.some((existing) => existing.node === row.node)) list.push(row);
    index.set(key, list);
  }
  return index;
}

/**
 * An item's taxonomy vector (§1.3): the sum of its mapped node weights, each
 * node passing half its weight to its parent, L2-normalised. Nodes outside
 * the item's kind scope are dropped before anything is summed, so a novel
 * never picks up "shoegaze" from a stray tag.
 */
export function taxonomyVector(
  terms: CatalogTerm[],
  kind: MediaKind,
  mappings: Map<string, TaxonomyMapping[]>,
  nodes: TaxonomyNode[] = TAXONOMY_NODES
): Map<string, number> {
  const bySlug = new Map(nodes.map((node) => [node.slug, node]));
  const inScope = (slug: string) => {
    const node = bySlug.get(slug);
    return node !== undefined && (node.kindScope === null || node.kindScope.includes(kind));
  };

  const raw = new Map<string, number>();
  const add = (slug: string, weight: number) => raw.set(slug, (raw.get(slug) ?? 0) + weight);

  // A term reported twice (a genre that is also a tag) counts once.
  const seen = new Set<string>();
  for (const term of terms) {
    const key = term.source === "tmdb_genre" ? term.key : normalizeTerm(term.key);
    const lookup = `${term.source}|${key}`;
    if (seen.has(lookup)) continue;
    seen.add(lookup);
    for (const mapping of mappings.get(lookup) ?? []) {
      if (!inScope(mapping.node)) continue;
      add(mapping.node, mapping.weight);
      const parent = bySlug.get(mapping.node)?.parent;
      if (parent && inScope(parent)) add(parent, mapping.weight * 0.5);
    }
  }

  const norm = Math.sqrt([...raw.values()].reduce((sum, w) => sum + w * w, 0));
  if (norm === 0) return new Map();
  return new Map([...raw].map(([slug, weight]) => [slug, weight / norm]));
}
