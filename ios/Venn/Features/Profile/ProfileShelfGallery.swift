import SwiftUI

/// Three-column cover grid for one profile shelf, with the shelf's
/// empty-state copy. Shared by the signed-in `ProfileView` and the
/// read-only `PublicProfileView`.
///
/// `onTap` fires when any cover is tapped — pass nil for a non-interactive
/// gallery (public profiles get tap-through with the follow system).
struct ProfileShelfGallery: View {
    let items: [LibraryItem]
    let emptyMessage: LocalizedStringKey
    var onTap: (() -> Void)?

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
                    if let onTap {
                        Button(action: onTap) {
                            cover(for: item)
                        }
                        .buttonStyle(.plain)
                    } else {
                        cover(for: item)
                    }
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
