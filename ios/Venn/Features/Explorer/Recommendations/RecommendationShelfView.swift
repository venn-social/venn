import SwiftUI

/// One horizontal shelf: a heading and a row of covers.
///
/// A catalog result is not in `public.media` yet, so it has no detail
/// screen to open — tapping it opens the composer instead, which is also
/// the action someone wants after seeing something they like.
struct RecommendationShelfView: View {
    let shelf: RecommendationShelf
    let onSelectCandidate: (MediaCandidate) -> Void

    private static let coverWidth: CGFloat = 110
    private static let coverHeight: CGFloat = 165

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(shelf.title)
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.Color.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.Spacing.md) {
                    ForEach(shelf.items) { item in
                        card(for: item)
                    }
                }
            }
            .scrollClipDisabled()
        }
    }

    @ViewBuilder
    private func card(for item: ShelfItem) -> some View {
        switch item {
        case let .media(media):
            NavigationLink(value: media) {
                cover(title: media.title, kind: media.kind, coverURL: media.coverURL)
            }
            .buttonStyle(.plain)
        case let .candidate(candidate):
            Button {
                onSelectCandidate(candidate)
            } label: {
                cover(title: candidate.title, kind: candidate.kind, coverURL: candidate.coverURL)
            }
            .buttonStyle(.plain)
        }
    }

    private func cover(title: String, kind: MediaKind, coverURL: URL?) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            MediaCoverTile(
                title: title,
                kind: kind,
                coverURL: coverURL,
                height: Self.coverHeight,
                cornerRadius: Theme.Radius.md
            )
            .frame(width: Self.coverWidth)

            Text(title)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .lineLimit(2)
                .frame(width: Self.coverWidth, alignment: .leading)
        }
    }
}
