import SwiftUI

struct ProfileLibrarySection: View {
    let categories: [ProfileLibraryCategory]
    /// Called when the user taps "Watchlist" on any category card.
    var onWatchlist: ((ProfileLibraryCategory) -> Void)?
    /// Called when the user taps "Data Room" (collection) on any category card.
    var onCollection: ((ProfileLibraryCategory) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Library")
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)

            ForEach(categories) { category in
                LibraryCategoryCard(
                    icon: category.icon,
                    title: category.title,
                    subtitle: category.subtitle,
                    primaryActionTitle: category.primaryActionTitle,
                    secondaryActionTitle: category.secondaryActionTitle,
                    onPrimaryAction: onWatchlist.map { handler in { handler(category) } },
                    onSecondaryAction: onCollection.map { handler in { handler(category) } }
                )
            }
        }
    }
}

struct ProfileLibraryCategory: Identifiable {
    let id: String
    let icon: String
    let title: String
    let subtitle: String
    /// Schema `MediaKind` this row counts. Nil for categories that
    /// aren't in the MVP scope yet (Restaurants, Games) — those keep
    /// rendering their empty-state copy regardless of real metrics.
    let mediaKind: MediaKind?
    var primaryActionTitle = "Watchlist"
    var secondaryActionTitle = "Data Room"
}

extension ProfileLibraryCategory {
    static let prototype: [ProfileLibraryCategory] = [
        .init(id: "movies", icon: "film", title: "Movies", subtitle: "42 watched · 12 watchlist", mediaKind: .movie),
        .init(id: "music", icon: "music.note", title: "Music", subtitle: "51 listened · 9 saved", mediaKind: .album),
        .init(id: "books", icon: "book.closed", title: "Books", subtitle: "18 read · 7 reading list", mediaKind: .book),
        .init(
            id: "restaurants",
            icon: "fork.knife",
            title: "Restaurants",
            subtitle: "17 tried · 6 bucket list",
            mediaKind: nil
        ),
    ]

    static let empty: [ProfileLibraryCategory] = [
        .init(
            id: "movies",
            icon: "film",
            title: "Movies",
            subtitle: "Watchlist and watched history",
            mediaKind: .movie
        ),
        .init(
            id: "music",
            icon: "music.note",
            title: "Music",
            subtitle: "Saved albums and listening history",
            mediaKind: .album
        ),
        .init(
            id: "books",
            icon: "book.closed",
            title: "Books",
            subtitle: "Reading list and finished books",
            mediaKind: .book
        ),
        .init(
            id: "restaurants",
            icon: "fork.knife",
            title: "Restaurants",
            subtitle: "Bucket list and tried spots",
            mediaKind: nil
        ),
    ]
}

#Preview {
    ProfileLibrarySection(categories: ProfileLibraryCategory.prototype)
        .padding(Theme.Spacing.lg)
}
