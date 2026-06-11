import SwiftUI

/// Small cover thumbnail for list rows (search results, library lists).
/// Shows the real cover when `coverURL` is present; falls back to the
/// kind's SF Symbol in an accent circle — the row treatment used before
/// covers existed, kept for items without art (music, user-typed entries).
struct MediaCoverThumb: View {
    let kind: MediaKind
    var coverURL: URL?

    var body: some View {
        if let coverURL {
            AsyncImage(
                url: coverURL,
                transaction: Transaction(animation: .easeIn(duration: 0.2))
            ) { phase in
                if case let .success(image) = phase {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                } else {
                    iconFallback
                }
            }
            .frame(width: 40, height: 56)
            .clipShape(.rect(cornerRadius: Theme.Radius.sm))
        } else {
            iconCircle
        }
    }

    /// Loading / failure state behind a cover that hasn't arrived yet.
    private var iconFallback: some View {
        ZStack {
            Theme.Color.surfaceStrong
            Image(systemName: kind.systemImage)
                .font(.callout)
                .foregroundStyle(Theme.Color.accent)
        }
    }

    /// The no-cover treatment: kind icon in a tinted circle.
    private var iconCircle: some View {
        Image(systemName: kind.systemImage)
            .font(.title3)
            .foregroundStyle(Theme.Color.accent)
            .frame(width: 40, height: 56)
            .background(Theme.Color.accent.opacity(0.10), in: .rect(cornerRadius: Theme.Radius.sm))
    }
}

#Preview {
    VStack(spacing: Theme.Spacing.md) {
        MediaCoverThumb(
            kind: .movie,
            coverURL: URL(string: "https://image.tmdb.org/t/p/w500/3bhkrj58Vtu7enYsLegHnDmni2O.jpg")
        )
        MediaCoverThumb(kind: .album)
    }
    .padding(Theme.Spacing.lg)
}
