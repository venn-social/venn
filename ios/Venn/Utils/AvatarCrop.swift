import CoreGraphics

/// The geometry behind adjusting an avatar: where the picture sits inside
/// the round window, and which part of it survives.
///
/// Mirrors web's `lib/avatarCrop.ts` function for function (CLAUDE.md rule
/// 17), and is kept apart from the view for the same reason it is there —
/// this is the half that can be wrong without looking wrong. An off-by-one
/// in the clamp shows up as a sliver of background at one edge, easy to
/// miss by eye and trivial to assert.
///
/// The model: the window is a square of `viewport` points. `coverScale` is
/// the factor at which the picture exactly covers it, so zoom 1 is "no
/// empty space" and larger zooms crop further in. The offset is the
/// picture's top-left corner relative to the window's, always negative or
/// zero.
enum AvatarCrop {
    struct View: Equatable, Sendable {
        /// Natural pixel size of the picture.
        var width: CGFloat
        var height: CGFloat
        /// Side of the square window, in the same units as the offset.
        var viewport: CGFloat
        /// 1 is "just covers"; larger crops in.
        var zoom: CGFloat
    }

    /// The factor at which the picture exactly covers the window.
    static func coverScale(width: CGFloat, height: CGFloat, viewport: CGFloat) -> CGFloat {
        let smallest = min(width, height)
        return smallest > 0 ? viewport / smallest : 1
    }

    /// The picture's drawn size at the current zoom.
    static func drawnSize(_ view: View) -> CGSize {
        let scale = coverScale(width: view.width, height: view.height, viewport: view.viewport)
            * view.zoom
        return CGSize(width: view.width * scale, height: view.height * scale)
    }

    /// The offset, pulled back to a position where the picture still covers
    /// the window. Dragging past the edge is the one thing that would leave
    /// a gap, and the fix people expect is the picture stopping, not the
    /// gap appearing.
    static func clampOffset(_ view: View, _ offset: CGPoint) -> CGPoint {
        let drawn = drawnSize(view)
        let minX = min(0, view.viewport - drawn.width)
        let minY = min(0, view.viewport - drawn.height)
        return CGPoint(
            x: min(0, max(minX, offset.x)),
            y: min(0, max(minY, offset.y))
        )
    }

    /// Where to draw the picture on an output canvas of `output` points
    /// square, so the result matches what the window was showing.
    static func outputRect(_ view: View, offset: CGPoint, output: CGFloat) -> CGRect {
        let factor = output / view.viewport
        let drawn = drawnSize(view)
        let clamped = clampOffset(view, offset)
        return CGRect(
            x: clamped.x * factor,
            y: clamped.y * factor,
            width: drawn.width * factor,
            height: drawn.height * factor
        )
    }

    /// The offset that keeps the same point of the picture centred when the
    /// zoom changes. Without this, zooming walks the picture towards a
    /// corner and you have to drag it back every time.
    static func offsetAfterZoom(_ view: View, offset: CGPoint, nextZoom: CGFloat) -> CGPoint {
        let ratio = nextZoom / view.zoom
        let centre = view.viewport / 2
        var next = view
        next.zoom = nextZoom
        return clampOffset(next, CGPoint(
            x: centre - (centre - offset.x) * ratio,
            y: centre - (centre - offset.y) * ratio
        ))
    }
}
