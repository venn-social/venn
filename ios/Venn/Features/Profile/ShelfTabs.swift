import SwiftUI

/// Collection / Watchlist text tabs above a profile's cover gallery.
/// Shared by the signed-in `ProfileView` and the read-only
/// `PublicProfileView`.
struct ShelfTabs: View {
    @Binding var selection: ProfileShelf

    var body: some View {
        HStack(spacing: Theme.Spacing.xl) {
            ForEach(ProfileShelf.allCases) { shelf in
                let isSelected = shelf == selection
                Button {
                    selection = shelf
                } label: {
                    Text(shelf.title)
                        .font(Theme.Font.headline)
                        .foregroundStyle(isSelected ? Theme.Color.textPrimary : Theme.Color.textSecondary)
                }
            }
            Spacer()
        }
    }
}

#Preview {
    @Previewable @State var shelf: ProfileShelf = .collection
    return ShelfTabs(selection: $shelf)
        .padding(Theme.Spacing.lg)
}
