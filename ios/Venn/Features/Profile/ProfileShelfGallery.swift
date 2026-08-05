import SwiftUI

/// Three-column cover grid for one profile shelf, with the shelf's
/// empty-state copy. Shared by the signed-in `ProfileView` and the
/// read-only `PublicProfileView`.
///
/// Tapping a cover opens that title's detail screen, the same as on web.
/// Both hosts must therefore register `.navigationDestination(for:
/// Media.self)` — the grid pushes a value, not a view, so it holds no
/// opinion about what the destination looks like.
struct ProfileShelfGallery: View {
    let items: [LibraryItem]
    let emptyMessage: LocalizedStringKey

    var body: some View {
        if items.isEmpty {
            Text(emptyMessage)
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Theme.Spacing.md)
        } else {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Spacing.sm), count: 3),
                spacing: Theme.Spacing.sm
            ) {
                ForEach(items) { item in
                    NavigationLink(value: item.media) {
                        cover(for: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func cover(for item: LibraryItem) -> some View {
        MediaCoverTile(
            title: item.media.title,
            kind: item.media.kind,
            coverURL: item.media.coverURL,
            height: 150,
            cornerRadius: Theme.Radius.md
        )
    }
}
