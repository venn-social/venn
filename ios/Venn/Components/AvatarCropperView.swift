import SwiftUI
import UIKit

/// Position and zoom a photo before it becomes an avatar. Mirrors web's
/// `AvatarCropper.tsx` in behaviour and copy (CLAUDE.md rule 17).
///
/// Picking a photo used to crop it centre-out and give you whatever that
/// happened to catch, which for most photos of a person is not their face.
/// The picture is dragged and zoomed inside a round window showing exactly
/// what will be kept, so the preview is the result rather than an
/// approximation of it.
///
/// The output is unchanged — 512px, JPEG at 0.8, the numbers `AvatarImage`
/// has always used. Only the choice of *which* 512px is new.
struct AvatarCropperView: View {
    /// The window you compose inside, in points.
    private static let viewport: CGFloat = 260
    private static let output: CGFloat = 512
    private static let quality: CGFloat = 0.8
    private static let maxZoom: CGFloat = 4

    let image: UIImage
    var onCancel: () -> Void
    var onConfirm: (Data) -> Void

    @State private var zoom: CGFloat = 1
    @State private var offset: CGPoint = .zero
    /// Where the offset was when the current drag began.
    @State private var dragOrigin: CGPoint?
    @State private var failed = false

    private var view: AvatarCrop.View {
        AvatarCrop.View(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale,
            viewport: Self.viewport,
            zoom: zoom
        )
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            window

            Slider(value: $zoom, in: 1...Self.maxZoom) { editing in
                // Re-centre as the zoom lands, so the middle of the window
                // keeps showing the same part of the picture.
                if !editing {
                    offset = AvatarCrop.clampOffset(view, offset)
                }
            }
            .onChange(of: zoom) { previous, next in
                var before = view
                before.zoom = previous
                offset = AvatarCrop.offsetAfterZoom(before, offset: offset, nextZoom: next)
            }
            .frame(maxWidth: Self.viewport)
            .accessibilityLabel("Zoom")

            if failed {
                Text("Couldn't use that photo. Try another one.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: Theme.Spacing.md) {
                Button("Use photo") { confirm() }
                    .font(Theme.Font.callout.weight(.semibold))
                    .foregroundStyle(Theme.Color.onAccent)
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Color.accent, in: .capsule)

                Button("Cancel", action: onCancel)
                    .font(Theme.Font.callout.weight(.semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .task { centreOnFirstShow() }
        .accessibilityIdentifier("avatar_cropper")
    }

    /// The round window. Round because the avatar is — showing a square
    /// crop and rounding it later is how a chin ends up outside it.
    private var window: some View {
        let drawn = AvatarCrop.drawnSize(view)

        return Color.clear
            .frame(width: Self.viewport, height: Self.viewport)
            .overlay(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: drawn.width, height: drawn.height)
                    .offset(x: offset.x, y: offset.y)
            }
            .background(Theme.Color.surfaceStrong)
            .clipShape(.circle)
            .contentShape(.circle)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let origin = dragOrigin ?? offset
                        if dragOrigin == nil {
                            dragOrigin = offset
                        }
                        offset = AvatarCrop.clampOffset(view, CGPoint(
                            x: origin.x + value.translation.width,
                            y: origin.y + value.translation.height
                        ))
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
    }

    /// Start centred, which is where a centre-out crop would have been —
    /// the same picture, now with somewhere to go.
    private func centreOnFirstShow() {
        guard offset == .zero else { return }
        let drawn = AvatarCrop.drawnSize(view)
        offset = AvatarCrop.clampOffset(view, CGPoint(
            x: (Self.viewport - drawn.width) / 2,
            y: (Self.viewport - drawn.height) / 2
        ))
    }

    private func confirm() {
        let rect = AvatarCrop.outputRect(view, offset: offset, output: Self.output)
        let size = CGSize(width: Self.output, height: Self.output)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let cropped = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: rect)
        }

        guard let data = cropped.jpegData(compressionQuality: Self.quality) else {
            failed = true
            return
        }
        onConfirm(data)
    }
}

#Preview {
    AvatarCropperView(
        image: UIGraphicsImageRenderer(size: CGSize(width: 400, height: 200)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 200))
        },
        onCancel: {},
        onConfirm: { _ in }
    )
    .padding(Theme.Spacing.lg)
}
