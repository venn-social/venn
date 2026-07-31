/**
 * Ports PairGeometry from ios/Venn/Components/VennOverlap.swift — same
 * two-lobe geometry, same constants. Lobe area tracks collection size
 * (radius ∝ √count); the more the two share, the closer the centers sit.
 */
export const VENN_DIAGRAM_HEIGHT = 180;
export const MAX_RADIUS = 78;
export const MIN_RADIUS = 38;

export interface PairGeometry {
  viewerRadius: number;
  otherRadius: number;
  halfDistance: number;
}

function radiusFor(count: number, maxCount: number): number {
  const ratio = Math.sqrt(Math.max(count, 0) / maxCount);
  return MIN_RADIUS + (MAX_RADIUS - MIN_RADIUS) * ratio;
}

export function pairGeometry(viewer: number, other: number, shared: number): PairGeometry {
  const maxCount = Math.max(viewer, other, 1);
  const viewerRadius = radiusFor(viewer, maxCount);
  const otherRadius = radiusFor(other, maxCount);

  const union = Math.max(viewer + other - shared, 1);
  const overlap = Math.min(Math.max(shared / union, 0), 1);
  const maxDistance = viewerRadius + otherRadius;
  const minDistance = Math.max(viewerRadius, otherRadius) * 0.65;
  const halfDistance = (maxDistance - (maxDistance - minDistance) * overlap) / 2;

  return { viewerRadius, otherRadius, halfDistance };
}
