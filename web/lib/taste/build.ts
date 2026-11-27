/**
 * Turns one extracted record into the rows the extraction script writes.
 * Pure, so the whole pipeline short of the network and the database is
 * covered by unit tests.
 */

import { commitmentFor } from "@/lib/taste/commitment";
import {
  EXTRACTOR_VERSION,
  decadeOf,
  type ExtractedFeatures,
  type MediaFeaturesRow
} from "@/lib/taste/record";
import { taxonomyVector, type TaxonomyMapping } from "@/lib/taste/taxonomy";

export interface BuiltRows {
  features: MediaFeaturesRow;
  /** Node slug → propagated, normalised weight. Resolved to node ids at write time. */
  taxonomy: { node: string; weight: number }[];
}

/** Below this, a weight is rounding noise and not worth a row. */
const MIN_NODE_WEIGHT = 0.01;

export function buildRows(
  mediaId: string,
  extracted: ExtractedFeatures,
  mappings: Map<string, TaxonomyMapping[]>,
  lengthSample: number[]
): BuiltRows {
  const vector = taxonomyVector(extracted.terms, extracted.kind, mappings);
  return {
    features: {
      media_id: mediaId,
      year: extracted.year,
      decade: decadeOf(extracted.year),
      length_raw: extracted.lengthRaw,
      commitment: commitmentFor(extracted.kind, extracted.lengthRaw, lengthSample),
      language: extracted.language,
      countries: extracted.countries,
      sound_tags: extracted.soundTags,
      extractor_version: EXTRACTOR_VERSION
    },
    taxonomy: [...vector]
      .filter(([, weight]) => weight >= MIN_NODE_WEIGHT)
      .map(([node, weight]) => ({ node, weight: Math.round(weight * 10000) / 10000 }))
      .sort((a, b) => b.weight - a.weight)
  };
}
