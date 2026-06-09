import SwiftUI

/// A single row in the Explorer search results list. Tapping the row
/// opens the composer sheet via the `onTap` callback.
struct ExplorerSearchResultRow: View {
    let candidate: MediaCandidate
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                kindIcon
                details
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundStyle(Theme.Color.accent)
                    .font(.body)
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.sm))
        }
        .buttonStyle(.plain)
    }

    private var kindIcon: some View {
        Image(systemName: candidate.kind.systemImage)
            .font(.title3)
            .foregroundStyle(Theme.Color.accent)
            .frame(width: 36, height: 36)
            .background(Theme.Color.accent.opacity(0.10), in: Circle())
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(candidate.title)
                .font(Theme.Font.body.weight(.medium))
                .foregroundStyle(Theme.Color.textPrimary)
                .lineLimit(1)

            HStack(spacing: 4) {
                if let creator = candidate.primaryCreator {
                    Text(creator)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(1)
                }
                if let year = candidate.year {
                    if candidate.primaryCreator != nil {
                        Text("·")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    Text(verbatim: "\(year)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }
        }
    }
}

private extension MediaKind {
    var systemImage: String {
        switch self {
        case .movie: "film"
        case .show: "tv"
        case .book: "book.closed"
        case .album: "music.note"
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        ExplorerSearchResultRow(
            candidate: MediaCandidate(
                title: "Past Lives",
                primaryCreator: "Celine Song",
                year: 2023,
                coverURL: nil,
                overview: "Two childhood sweethearts separated when Nora's family emigrates from South Korea.",
                externalID: "976573",
                externalSource: .tmdb,
                kind: .movie
            )
        ) {}
        ExplorerSearchResultRow(
            candidate: MediaCandidate(
                title: "OK Computer",
                primaryCreator: "Radiohead",
                year: 1997,
                coverURL: nil,
                overview: nil,
                externalID: "f5093c06",
                externalSource: .musicbrainz,
                kind: .album
            )
        ) {}
    }
    .padding()
}
