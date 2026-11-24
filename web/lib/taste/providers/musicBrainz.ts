/**
 * MusicBrainz → feature record. Takes two responses (see fetchFeatures.ts):
 *
 *   1. the release group, `inc=artist-credits+genres+tags`
 *   2. its representative release, `inc=recordings` — the earliest official
 *      one, which is the album as first put out. Lengths, country and
 *      language only exist per release.
 */

import { yearFrom } from "@/lib/catalog/types";
import type { ExtractedPerson } from "@/lib/taste/people";
import { languageFromThreeLetter } from "@/lib/taste/providers/languages";
import {
  countryCodes,
  plausibleYear,
  type ExtractedFeatures,
  type SoundTag
} from "@/lib/taste/record";
import { normalizeTerm, type CatalogTerm } from "@/lib/taste/taxonomy";

interface MBNamed {
  name?: string;
  count?: number;
}

interface MBReleaseGroup {
  "first-release-date"?: string;
  "artist-credit"?: { artist?: { id?: string; name?: string } }[];
  genres?: MBNamed[];
  tags?: MBNamed[];
}

interface MBRelease {
  country?: string;
  "text-representation"?: { language?: string };
  media?: { tracks?: { length?: number | null }[] }[];
}

/**
 * Tags that describe the sound (§1.6), by the vocabulary entry they become.
 * MusicBrainz tags are free text, so only these exact (normalised) spellings
 * count; everything else is left to the taxonomy.
 */
const SOUND: Record<string, SoundTag> = {
  guitar: "guitar",
  "acoustic-guitar": "guitar",
  "electric-guitar": "guitar",
  synth: "synth",
  synthesizer: "synth",
  synthesizers: "synth",
  strings: "strings",
  "string-quartet": "strings",
  orchestral: "strings",
  piano: "piano",
  brass: "brass",
  horns: "brass",
  "a-cappella": "voice-led",
  vocal: "voice-led",
  vocals: "voice-led",
  calm: "energy_low",
  mellow: "energy_low",
  chill: "energy_low",
  relaxing: "energy_low",
  quiet: "energy_low",
  energetic: "energy_high",
  "high-energy": "energy_high",
  aggressive: "energy_high"
};

/** A tag needs at least this many votes to count: one person's tag is an opinion. */
const MIN_TAG_VOTES = 2;

function voted(entries: MBNamed[] | undefined, minimum: number): string[] {
  return (entries ?? [])
    .filter((entry): entry is MBNamed & { name: string } => Boolean(entry.name))
    .filter((entry) => (entry.count ?? 0) >= minimum)
    .map((entry) => entry.name);
}

function peopleOf(group: MBReleaseGroup): ExtractedPerson[] {
  const seen = new Set<string>();
  const people: ExtractedPerson[] = [];
  for (const credit of group["artist-credit"] ?? []) {
    const id = credit.artist?.id;
    const name = credit.artist?.name;
    if (!id || !name || seen.has(id)) continue;
    seen.add(id);
    people.push({ name, role: "primary_artist", billing: null, ids: { musicbrainz: id } });
  }
  return people;
}

/** Total length in minutes, only when every track has one — a partial sum would understate it. */
function lengthOf(release: MBRelease | null): number | null {
  const tracks = (release?.media ?? []).flatMap((medium) => medium.tracks ?? []);
  if (tracks.length === 0) return null;
  let total = 0;
  for (const track of tracks) {
    if (typeof track.length !== "number" || track.length <= 0) return null;
    total += track.length;
  }
  return Math.round((total / 60000) * 10) / 10;
}

export function musicBrainzFeatures(groupJson: unknown, releaseJson: unknown): ExtractedFeatures {
  const group = (groupJson ?? {}) as MBReleaseGroup;
  const release = (releaseJson ?? null) as MBRelease | null;
  const genres = voted(group.genres, 1);
  const tags = voted(group.tags, MIN_TAG_VOTES);

  const terms: CatalogTerm[] = [
    ...genres.map((key): CatalogTerm => ({ source: "musicbrainz_genre", key })),
    ...tags.map((key): CatalogTerm => ({ source: "musicbrainz_tag", key }))
  ];
  const soundTags = [
    ...new Set(
      [...genres, ...tags]
        .map((name) => SOUND[normalizeTerm(name)])
        .filter((tag): tag is SoundTag => tag !== undefined)
    )
  ];

  return {
    kind: "album",
    year: plausibleYear(yearFrom(group["first-release-date"])),
    lengthRaw: lengthOf(release),
    language: languageFromThreeLetter(release?.["text-representation"]?.language),
    countries: countryCodes([release?.country]),
    soundTags,
    people: peopleOf(group),
    terms
  };
}
