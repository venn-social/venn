/**
 * The geometry behind adjusting an avatar: where the picture sits inside
 * the round window, and which part of it survives.
 *
 * Kept apart from the component because it is the half that can be wrong
 * without looking wrong — an off-by-one in the clamp shows up as a sliver
 * of background at one edge, which is easy to miss by eye and trivial to
 * assert.
 *
 * The model: the window is a square of `viewport` px. `coverScale` is the
 * factor at which the picture exactly covers it, so zoom 1 is "no empty
 * space" and larger zooms crop further in. The offset is the picture's
 * top-left corner relative to the window's, always negative or zero.
 */

export interface CropView {
  /** Natural pixel size of the picture. */
  width: number;
  height: number;
  /** Side of the square window, in the same units as the offset. */
  viewport: number;
  /** 1 is "just covers"; larger crops in. */
  zoom: number;
}

/** The factor at which the picture exactly covers the window. */
export function coverScale(view: Pick<CropView, "width" | "height" | "viewport">): number {
  const smallest = Math.min(view.width, view.height);
  return smallest > 0 ? view.viewport / smallest : 1;
}

/** The picture's drawn size at the current zoom. */
export function drawnSize(view: CropView): { width: number; height: number } {
  const scale = coverScale(view) * view.zoom;
  return { width: view.width * scale, height: view.height * scale };
}

/**
 * The offset, pulled back to a position where the picture still covers the
 * window. Dragging past the edge is the one thing that would leave a gap,
 * and the fix people expect is the picture stopping, not the gap appearing.
 */
export function clampOffset(
  view: CropView,
  offset: { x: number; y: number }
): { x: number; y: number } {
  const drawn = drawnSize(view);
  const minX = Math.min(0, view.viewport - drawn.width);
  const minY = Math.min(0, view.viewport - drawn.height);
  return {
    x: Math.min(0, Math.max(minX, offset.x)),
    y: Math.min(0, Math.max(minY, offset.y))
  };
}

/**
 * Where to draw the picture on an output canvas of `output` px square, so
 * the result matches what the window was showing. The window and the
 * canvas differ in size, so everything scales by the ratio between them.
 */
export function outputRect(
  view: CropView,
  offset: { x: number; y: number },
  output: number
): { x: number; y: number; width: number; height: number } {
  const factor = output / view.viewport;
  const drawn = drawnSize(view);
  const clamped = clampOffset(view, offset);
  return {
    x: clamped.x * factor,
    y: clamped.y * factor,
    width: drawn.width * factor,
    height: drawn.height * factor
  };
}

/**
 * The offset that keeps the same point of the picture centred when the
 * zoom changes. Without this, zooming walks the picture towards a corner
 * and you have to drag it back every time.
 */
export function offsetAfterZoom(
  view: CropView,
  offset: { x: number; y: number },
  nextZoom: number
): { x: number; y: number } {
  const ratio = nextZoom / view.zoom;
  const centre = view.viewport / 2;
  return clampOffset({ ...view, zoom: nextZoom }, {
    x: centre - (centre - offset.x) * ratio,
    y: centre - (centre - offset.y) * ratio
  });
}
