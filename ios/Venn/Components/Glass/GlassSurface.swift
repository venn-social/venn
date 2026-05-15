import SwiftUI

/// Reusable Liquid Glass surface styles for interactive foreground UI.
///
/// Keep raw `.glassEffect(...)` calls here so feature screens can opt into
/// the same native material behavior without copying one-off modifiers.
enum VennGlassStyle {
    case regular
    case clear
    case accent

    var glass: Glass {
        switch self {
        case .regular:
            .regular.interactive()
        case .clear:
            .clear.interactive()
        case .accent:
            .regular
                .tint(Theme.Color.accent.opacity(0.16))
                .interactive()
        }
    }
}

struct GlassSurface<Content: View, SurfaceShape: Shape>: View {
    let style: VennGlassStyle
    let shape: SurfaceShape
    let padding: EdgeInsets
    @ViewBuilder let content: () -> Content

    init(
        style: VennGlassStyle = .regular,
        in shape: SurfaceShape,
        padding: EdgeInsets = EdgeInsets(
            top: Theme.Spacing.md,
            leading: Theme.Spacing.md,
            bottom: Theme.Spacing.md,
            trailing: Theme.Spacing.md
        ),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.shape = shape
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .vennGlass(style, in: shape)
    }
}

struct VennGlassModifier<SurfaceShape: Shape>: ViewModifier {
    let style: VennGlassStyle
    let shape: SurfaceShape

    func body(content: Content) -> some View {
        content
            .glassEffect(style.glass, in: shape)
            .overlay {
                shape
                    .stroke(Theme.Color.separator.opacity(0.55), lineWidth: 0.5)
            }
    }
}

extension View {
    func vennGlass<SurfaceShape: Shape>(
        _ style: VennGlassStyle = .regular,
        in shape: SurfaceShape
    ) -> some View {
        modifier(VennGlassModifier(style: style, shape: shape))
    }
}

#Preview {
    Screen {
        VStack(spacing: Theme.Spacing.md) {
            GlassSurface(style: .regular, in: .rect(cornerRadius: Theme.Radius.md)) {
                Text("Regular glass")
                    .font(Theme.Font.headline)
            }

            GlassSurface(style: .accent, in: .capsule) {
                Text("Accent glass")
                    .font(Theme.Font.headline)
            }
        }
    }
}
