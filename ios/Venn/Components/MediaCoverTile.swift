import SwiftUI

/// Cover for a media entry — the visual hero of every item (covers first,
/// always). Renders the real cover art when `coverURL` is present, fading
/// in over the tonal placeholder tile (kind color + leading initial), which
/// also serves as the loading and failure state. Music mostly has no
/// `coverURL` yet — Cover Art Archive lookup is a separate pass.
struct MediaCoverTile: View {
    let title: String
    let kind: MediaKind
    var coverURL: URL?
    var height: CGFloat
    var cornerRadius: CGFloat = Theme.Radius.lg

    var body: some View {
        ZStack {
            tint
            Text(title.prefix(1))
                .font(.system(size: height * 0.4, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Color.coverGlyph)
            if let coverURL {
                cover(url: coverURL)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
    }

    private func cover(url: URL) -> some View {
        // URLCache (memory + disk) handles re-fetches: TMDB / OpenLibrary
        // serve long-lived cache headers. Swap in Kingfisher only if scroll
        // performance ever demands it (docs/TECH_DEBT.md).
        AsyncImage(
            url: url,
            transaction: Transaction(animation: .easeIn(duration: 0.2))
        ) { phase in
            if case let .success(image) = phase {
                GeometryReader { proxy in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .transition(.opacity)
            }
        }
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
        MediaCoverTile(
            title: "The Godfather",
            kind: .movie,
            coverURL: URL(string: "https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsLegHnDmni2O.jpg"),
            height: 160
        )
    }
    .padding(Theme.Spacing.lg)
}
