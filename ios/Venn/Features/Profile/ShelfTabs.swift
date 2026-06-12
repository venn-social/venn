import SwiftUI

/// Collection / Watchlist text tabs above a profile's cover gallery.
/// Each tab takes half the available width with its title centered, so
/// the pair spans the whole screen. Shared by the signed-in `ProfileView`
/// and the read-only `PublicProfileView`.
struct ShelfTabs: View {
    @Binding var selection: ProfileShelf

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ProfileShelf.allCases) { shelf in
                let isSelected = shelf == selection
                Button {
                    selection = shelf
                } label: {
                    Text(shelf.title)
                        .font(Theme.Font.headline)
                        .foregroundStyle(isSelected ? Theme.Color.textPrimary : Theme.Color.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Theme.Spacing.xs)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    @Previewable @State var shelf: ProfileShelf = .collection
    return ShelfTabs(selection: $shelf)
        .padding(Theme.Spacing.lg)
}
