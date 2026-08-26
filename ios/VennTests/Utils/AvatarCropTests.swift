import CoreGraphics
import Testing
@testable import Venn

/// The half of the avatar cropper that can be wrong without looking wrong:
/// an off-by-one in the clamp is a sliver of background at one edge, easy
/// to miss by eye and trivial to assert. Mirrors web's
/// `lib/__tests__/avatarCrop.test.ts` case for case (rule 17).
struct AvatarCropTests {
    /// A landscape photo, in a 260pt window.
    private let wide = AvatarCrop.View(width: 1000, height: 500, viewport: 260, zoom: 1)
    /// A portrait one.
    private let tall = AvatarCrop.View(width: 500, height: 1000, viewport: 260, zoom: 1)

    // MARK: - coverScale

    @Test("scales the short side to the window, so nothing is ever letterboxed")
    func coverScale() {
        #expect(AvatarCrop.coverScale(width: 1000, height: 500, viewport: 260) == 260.0 / 500)
        #expect(AvatarCrop.coverScale(width: 500, height: 1000, viewport: 260) == 260.0 / 500)
    }

    @Test("survives a zero-sized image instead of dividing by it")
    func zeroSized() {
        #expect(AvatarCrop.coverScale(width: 0, height: 0, viewport: 260) == 1)
    }

    // MARK: - drawnSize

    @Test("covers the window exactly at zoom 1")
    func coversAtZoomOne() {
        let drawn = AvatarCrop.drawnSize(wide)
        #expect(abs(min(drawn.width, drawn.height) - 260) < 0.001)
        #expect(drawn.width > 260)
    }

    @Test("grows with zoom")
    func growsWithZoom() {
        var zoomed = wide
        zoomed.zoom = 2
        #expect(
            abs(AvatarCrop.drawnSize(zoomed).width - AvatarCrop.drawnSize(wide).width * 2) < 0.001
        )
    }

    // MARK: - clampOffset

    @Test("never lets the picture pull away from an edge")
    func neverExposesAnEdge() {
        // The one thing that would leave a gap in the circle.
        let drawn = AvatarCrop.drawnSize(wide)
        for attempt in [CGPoint(x: 500, y: 500), CGPoint(x: -5000, y: -5000), CGPoint(x: 0, y: 40)] {
            let clamped = AvatarCrop.clampOffset(wide, attempt)
            #expect(clamped.x <= 0)
            #expect(clamped.y <= 0)
            #expect(clamped.x >= 260 - drawn.width)
            #expect(clamped.y >= 260 - drawn.height)
        }
    }

    @Test("pins the axis that exactly fits, leaving the other free")
    func pinsTheFittingAxis() {
        // A landscape photo at zoom 1 fits vertically to the point; only
        // sideways movement is meaningful.
        #expect(AvatarCrop.clampOffset(wide, CGPoint(x: -100, y: -100)) == CGPoint(x: -100, y: 0))
        #expect(AvatarCrop.clampOffset(tall, CGPoint(x: -100, y: -100)) == CGPoint(x: 0, y: -100))
    }

    // MARK: - outputRect

    @Test("reproduces what the window showed, at the output's scale")
    func reproducesTheWindow() {
        let rect = AvatarCrop.outputRect(wide, offset: CGPoint(x: -60, y: 0), output: 512)
        let factor: CGFloat = 512.0 / 260
        #expect(abs(rect.origin.x - -60 * factor) < 0.001)
        #expect(abs(rect.width - AvatarCrop.drawnSize(wide).width * factor) < 0.001)
    }

    @Test("clamps before it scales, so a bad offset cannot leak into the file")
    func clampsBeforeScaling() {
        let rect = AvatarCrop.outputRect(wide, offset: CGPoint(x: 999, y: 999), output: 512)
        #expect(rect.origin == .zero)
    }

    @Test("always covers the output canvas")
    func alwaysCoversOutput() {
        for zoom in [CGFloat(1), 1.7, 4] {
            for base in [wide, tall] {
                var view = base
                view.zoom = zoom
                let rect = AvatarCrop.outputRect(view, offset: CGPoint(x: -10, y: -10), output: 512)
                #expect(rect.width >= 512 - 0.001)
                #expect(rect.height >= 512 - 0.001)
            }
        }
    }

    // MARK: - offsetAfterZoom

    @Test("keeps the middle of the window on the same part of the picture")
    func zoomHoldsTheCentre() {
        // Otherwise zooming walks the picture into a corner and you drag it
        // back every time.
        let before = CGPoint(x: -120, y: 0)
        let centreBefore = (260 / 2 - before.x) / AvatarCrop.drawnSize(wide).width

        var zoomed = wide
        zoomed.zoom = 2
        let after = AvatarCrop.offsetAfterZoom(wide, offset: before, nextZoom: 2)
        let centreAfter = (260 / 2 - after.x) / AvatarCrop.drawnSize(zoomed).width

        #expect(abs(centreAfter - centreBefore) < 0.0001)
    }

    @Test("still refuses to expose an edge while doing it")
    func zoomStillClamps() {
        var zoomed = wide
        zoomed.zoom = 3
        let after = AvatarCrop.offsetAfterZoom(zoomed, offset: CGPoint(x: -600, y: -100), nextZoom: 1)
        #expect(after == AvatarCrop.clampOffset(wide, after))
    }
}
