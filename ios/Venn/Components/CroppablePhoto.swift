import UIKit

/// A picked photo on its way to the cropper.
///
/// `sheet(item:)` needs something `Identifiable`, and `UIImage` is not —
/// wrapping it is cheaper than tracking a separate "is the cropper up"
/// flag beside the image and keeping the two in step.
struct CroppablePhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}
