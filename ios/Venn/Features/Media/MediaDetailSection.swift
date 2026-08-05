import SwiftUI

/// A titled block on the media detail screen — "About", "Cast", "Genres".
/// Extracted so the six sections share one heading treatment instead of
/// each restating the font and spacing (CLAUDE.md rule 16).
struct MediaDetailSection<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(title)
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.Color.textPrimary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A pill of secondary text — genre chips, and the provider chips under
/// "Where to watch".
struct MediaDetailChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.Font.footnote)
            .foregroundStyle(Theme.Color.textSecondary)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs)
            .background(Theme.Color.surfaceStrong, in: .capsule)
    }
}

#Preview {
    MediaDetailSection(title: "Genres") {
        HStack {
            MediaDetailChip(text: "Drama")
            MediaDetailChip(text: "Romance")
        }
    }
    .padding(Theme.Spacing.lg)
}
