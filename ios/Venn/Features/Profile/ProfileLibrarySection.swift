import SwiftUI

struct ProfileLibrarySection: View {
    let categories: [ProfileLibraryCategory]

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
                    secondaryActionTitle: category.secondaryActionTitle
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
    var primaryActionTitle = "Watchlist"
    var secondaryActionTitle = "Data Room"
}

extension ProfileLibraryCategory {
    static let prototype: [ProfileLibraryCategory] = [
        .init(id: "movies", icon: "film", title: "Movies", subtitle: "42 watched · 12 watchlist"),
        .init(id: "music", icon: "music.note", title: "Music", subtitle: "51 listened · 9 saved"),
        .init(id: "books", icon: "book.closed", title: "Books", subtitle: "18 read · 7 reading list"),
        .init(id: "restaurants", icon: "fork.knife", title: "Restaurants", subtitle: "17 tried · 6 bucket list"),
    ]

    static let empty: [ProfileLibraryCategory] = [
        .init(id: "movies", icon: "film", title: "Movies", subtitle: "Watchlist and watched history"),
        .init(id: "music", icon: "music.note", title: "Music", subtitle: "Saved albums and listening history"),
        .init(id: "books", icon: "book.closed", title: "Books", subtitle: "Reading list and finished books"),
        .init(id: "restaurants", icon: "fork.knife", title: "Restaurants", subtitle: "Bucket list and tried spots"),
    ]
}

#Preview {
    ProfileLibrarySection(categories: ProfileLibraryCategory.prototype)
        .padding(Theme.Spacing.lg)
}
