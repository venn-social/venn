import UIKit

/// Prepares a picked photo for avatar upload: downscale to a sane pixel
/// budget and JPEG-encode. Pure function of its inputs — unit-tested.
enum AvatarImage {
    /// 512px covers the largest render (72pt header avatar @3x = 216px)
    /// with margin; photos straight off the camera are ~12MP and would be
    /// a silly upload for a circle 36pt wide.
    static func jpegData(
        from image: UIImage,
        maxDimension: CGFloat = 512,
        quality: CGFloat = 0.8
    ) -> Data? {
        let pixelSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        let largest = max(pixelSize.width, pixelSize.height)
        guard largest > maxDimension else {
            return image.jpegData(compressionQuality: quality)
        }
        let factor = maxDimension / largest
        let target = CGSize(
            width: (pixelSize.width * factor).rounded(.down),
            height: (pixelSize.height * factor).rounded(.down)
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
