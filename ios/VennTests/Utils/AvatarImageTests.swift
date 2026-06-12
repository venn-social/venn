import Testing
import UIKit
@testable import Venn

/// Tests the avatar downscale + encode helper with generated images —
/// no fixtures, no network.
struct AvatarImageTests {
    @Test
    func oversizedImageIsDownscaledToMaxDimension() throws {
        let big = makeImage(width: 2000, height: 1000)
        let data = try #require(AvatarImage.jpegData(from: big, maxDimension: 512))
        let result = try #require(UIImage(data: data))

        // Landscape: width is the long edge and lands on the cap.
        #expect(Int(result.size.width * result.scale) == 512)
        #expect(Int(result.size.height * result.scale) == 256)
    }

    @Test
    func smallImageIsEncodedWithoutUpscaling() throws {
        let small = makeImage(width: 100, height: 100)
        let data = try #require(AvatarImage.jpegData(from: small, maxDimension: 512))
        let result = try #require(UIImage(data: data))

        #expect(Int(result.size.width * result.scale) == 100)
    }

    @Test
    func encodedDataIsJPEG() throws {
        let data = try #require(AvatarImage.jpegData(from: makeImage(width: 600, height: 600)))
        // JPEG magic bytes.
        #expect(data.prefix(2) == Data([0xFF, 0xD8]))
    }

    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(
            size: CGSize(width: width, height: height),
            format: format
        ).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }
}
