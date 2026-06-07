import SwiftUI

/// Cover for a media entry. Until real cover art is available (the external
/// catalog integrations aren't wired yet), this renders a tonal placeholder
/// tile keyed to the media kind, with the entry's leading initial. When
/// cover URLs land, add an `AsyncImage` path here and fall back to the tile
/// only when the URL is missing — every call site gets it for free.
struct MediaCoverTile: View {
    let title: String
    let kind: MediaKind
    var height: CGFloat
    var cornerRadius: CGFloat = Theme.Radius.lg

    var body: some View {
        ZStack {
            tint
            Text(title.prefix(1))
                .font(.system(size: height * 0.4, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Color.coverGlyph)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(.rect(cornerRadius: cornerRadius))
    }

    private var tint: SwiftUI.Color {
        switch kind {
        case .movie: Theme.Color.coverMovie
        case .show: Theme.Color.coverShow
        case .book: Theme.Color.coverBook
        case .album: Theme.Color.coverAlbum
        }
    }
}

#Preview {
    HStack(spacing: Theme.Spacing.md) {
        MediaCoverTile(title: "Past Lives", kind: .movie, height: 160)
        MediaCoverTile(title: "Blonde", kind: .album, height: 160)
    }
    .padding(Theme.Spacing.lg)
}
