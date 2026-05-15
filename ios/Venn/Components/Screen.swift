import SwiftUI

/// Page-level container every top-level view should wrap with. Applies the
/// venn background, full-screen frame, and a default content padding so
/// individual screens don't repeat the boilerplate.
///
/// Pass `padding: .zero` for edge-to-edge content (e.g. a `List` or full-
/// bleed scroll view) and add inner padding inside the content closure
/// instead.
///
/// Usage:
///     Screen {
///         VStack { … }
///     }
struct Screen<Content: View>: View {
    let padding: EdgeInsets
    @ViewBuilder let content: () -> Content

    init(
        padding: EdgeInsets = EdgeInsets(
            top: Theme.Spacing.lg,
            leading: Theme.Spacing.lg,
            bottom: Theme.Spacing.lg,
            trailing: Theme.Spacing.lg
        ),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("default padding") {
    Screen {
        VStack(spacing: Theme.Spacing.md) {
            Text("Screen preview")
                .font(Theme.Font.title)
            Text("Wrapped content sits inside the default padding.")
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }
}

#Preview("zero padding") {
    Screen(padding: .init()) {
        Color.red.opacity(0.1)
            .overlay(Text("edge-to-edge").font(Theme.Font.headline))
    }
}
