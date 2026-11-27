/**
 * The "commitment" scale (§1.4): how much of yourself an item asks for,
 * comparable across media. It is the item's percentile within its own kind.
 *
 * Until a kind has MIN_SAMPLE items with a length, a fixed reference curve
 * stands in. The anchors are rough population percentiles, chosen to land
 * the spec's worked examples: a 95-minute film ≈ 0.30, a 600-page novel
 * ≈ 0.85, a 38-minute album ≈ 0.40, a six-season show ≈ 0.95.
 */

import type { MediaKind } from "@/lib/media";

export const MIN_SAMPLE = 200;

/** [length, percentile] in the kind's own unit: minutes, or pages for books. */
const REFERENCE: Record<MediaKind, [number, number][]> = {
  movie: [
    [60, 0],
    [85, 0.12],
    [95, 0.3],
    [105, 0.5],
    [120, 0.72],
    [140, 0.88],
    [180, 0.98],
    [240, 1]
  ],
  // Total runtime across every episode.
  show: [
    [60, 0],
    [300, 0.1],
    [600, 0.3],
    [1200, 0.6],
    [2000, 0.85],
    [2700, 0.95],
    [6000, 1]
  ],
  book: [
    [50, 0],
    [150, 0.1],
    [250, 0.35],
    [320, 0.55],
    [400, 0.7],
    [600, 0.85],
    [900, 0.96],
    [1500, 1]
  ],
  album: [
    [10, 0],
    [25, 0.08],
    [35, 0.3],
    [38, 0.4],
    [45, 0.6],
    [55, 0.8],
    [70, 0.93],
    [120, 1]
  ]
};

/** Piecewise-linear lookup on the reference curve, clamped to [0, 1]. */
export function referenceCommitment(kind: MediaKind, length: number): number {
  const anchors = REFERENCE[kind];
  const first = anchors[0];
  const last = anchors[anchors.length - 1];
  if (length <= first[0]) return first[1];
  if (length >= last[0]) return last[1];
  for (let i = 1; i < anchors.length; i += 1) {
    const [x1, y1] = anchors[i];
    const [x0, y0] = anchors[i - 1];
    if (length <= x1) return y0 + ((length - x0) / (x1 - x0)) * (y1 - y0);
  }
  return last[1];
}

/**
 * Mid-rank percentile of `length` among `sample`: ties count half, so an
 * item never outranks its equals and the scale is symmetric.
 */
export function empiricalCommitment(sample: number[], length: number): number {
  if (sample.length === 0) return 0.5;
  let below = 0;
  let equal = 0;
  for (const value of sample) {
    if (value < length) below += 1;
    else if (value === length) equal += 1;
  }
  return (below + equal / 2) / sample.length;
}

/** The spec's rule: empirical once the kind has enough items, the reference curve before. */
export function commitmentFor(
  kind: MediaKind,
  length: number | null,
  sample: number[]
): number | null {
  if (length === null || !(length > 0)) return null;
  const value =
    sample.length >= MIN_SAMPLE
      ? empiricalCommitment(sample, length)
      : referenceCommitment(kind, length);
  return Math.round(value * 1000) / 1000;
}
