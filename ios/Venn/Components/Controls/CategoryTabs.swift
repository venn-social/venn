import SwiftUI

/// Underline tabs: the label, and a rule under the one you are on.
///
/// Mirrors web's `CategoryChips` (CLAUDE.md rule 17), which in turn matches
/// the Collection / Watchlist control on the profile. All three pick which
/// slice you are looking at, so all three look the same.
///
/// This replaced a filled segmented control in Explorer. Six filled pills
/// read as six competing actions rather than one choice among six, and the
/// control drew more lines than the choice needed.
struct CategoryTabs<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.lg) {
                ForEach(items) { item in
                    let selected = item == selection
                    Button {
                        selection = item
                    } label: {
                        Text(title(item))
                            .font(selected ? Theme.Font.callout.weight(.semibold) : Theme.Font.callout)
                            .foregroundStyle(
                                selected ? Theme.Color.textPrimary : Theme.Color.textSecondary
                            )
                            .padding(.bottom, Theme.Spacing.sm)
                            .overlay(alignment: .bottom) {
                                // Only the selected tab draws its rule; the
                                // separator below carries the rest of the line.
                                Rectangle()
                                    .fill(selected ? Theme.Color.accent : .clear)
                                    .frame(height: 2)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
        }
        .scrollClipDisabled()
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.Color.separator)
                .frame(height: 1)
        }
    }
}

#Preview {
    CategoryTabs(
        items: ExplorerCategory.allCases,
        selection: .constant(.movies),
        title: \.title
    )
    .padding(Theme.Spacing.lg)
}
