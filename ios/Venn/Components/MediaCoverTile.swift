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
    /// A fixed height, or nil to take the full width and square itself.
    ///
    /// The feed passes nil: a post is the width of its artwork there, and a
    /// square is the one shape that treats a poster, a book jacket and an
    /// album sleeve alike without letterboxing any of them.
    var height: CGFloat?
    var cornerRadius: CGFloat = Theme.Radius.lg

    var body: some View {
        sized
            .clipShape(.rect(cornerRadius: cornerRadius))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(title))
    }

    @ViewBuilder private var sized: some View {
        if let height {
            tile.frame(maxWidth: .infinity).frame(height: height)
        } else {
            tile.frame(maxWidth: .infinity).aspectRatio(1, contentMode: .fit)
        }
    }

    private var tile: some View {
        ZStack {
            tint
            // Sized from the box rather than from `height`, so the glyph is
            // proportionate in the square case too, where nobody passed one.
            GeometryReader { proxy in
                Text(title.prefix(1))
                    .font(
                        .system(
                            size: min(proxy.size.width, proxy.size.height) * 0.4,
                            weight: .semibold,
                            design: .rounded
                        )
                    )
                    .foregroundStyle(Theme.Color.coverGlyph)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            if let coverURL {
                cover(url: coverURL)
            }
        }
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
                        .scaledToFill()
                        .frame(
                            width: proxy.size.width,
                            height: proxy.size.height,
                            alignment: cropAlignment
                        )
                        .clipped()
                }
                .transition(.opacity)
            }
        }
    }

    /// Which part of a portrait cover survives a square.
    ///
    /// Posters and jackets put their art above and their title along the
    /// bottom — which the feed now prints over that same bottom edge, so
    /// cropping it away is what stops a cover naming itself twice. Album
    /// sleeves are square to begin with and lose nothing either way.
    private var cropAlignment: Alignment {
        kind == .album ? .center : .top
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
    VStack(spacing: Theme.Spacing.md) {
        HStack(spacing: Theme.Spacing.md) {
            MediaCoverTile(title: "Past Lives", kind: .movie, height: 160)
            MediaCoverTile(
                title: "The Godfather",
                kind: .movie,
                coverURL: URL(string: "https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsLegHnDmni2O.jpg"),
                height: 160
            )
        }
        // The feed's shape: full width, squared, no height given.
        MediaCoverTile(
            title: "Past Lives",
            kind: .movie,
            coverURL: URL(string: "https://image.tmdb.org/t/p/w500/k3waqVXSnvCZWfJYNtdamTgTtTA.jpg"),
            height: nil
        )
    }
    .padding(Theme.Spacing.lg)
}
