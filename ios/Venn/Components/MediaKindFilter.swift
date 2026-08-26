import SwiftUI

/// Tab row for narrowing a shelf to one media kind. Sits directly under
/// `ShelfTabs`, and mirrors web's `MediaKindFilter.tsx` tab for tab.
///
/// Underline tabs rather than filled chips, like every other tab row on
/// both platforms: filled pills read as competing actions, and this is one
/// choice among a few.
///
/// Only kinds actually present are offered. With four kinds and usually
/// one or two on a shelf, a row of chips that all lead to an empty grid is
/// worse than no row at all — so the whole control hides unless it can
/// narrow something.
struct MediaKindFilter: View {
    @Binding var selection: MediaKind?
    let available: Set<MediaKind>

    private var kinds: [MediaKind] {
        MediaKind.allCases.filter { available.contains($0) }
    }

    var body: some View {
        if kinds.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Spacing.lg) {
                    chip(title: "All", isSelected: selection == nil) { selection = nil }
                    ForEach(kinds, id: \.self) { kind in
                        chip(title: kind.pluralDisplayName, isSelected: selection == kind) {
                            selection = kind
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .accessibilityIdentifier("media_kind_filter")
        }
    }

    private func chip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(
                    isSelected
                        ? Theme.Font.footnote.weight(.semibold)
                        : Theme.Font.footnote
                )
                .foregroundStyle(isSelected ? Theme.Color.textPrimary : Theme.Color.textSecondary)
                .padding(.bottom, Theme.Spacing.xs)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? Theme.Color.accent : .clear)
                        .frame(height: 2)
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("Light") {
    @Previewable @State var kind: MediaKind?
    return MediaKindFilter(selection: $kind, available: [.movie, .show, .album])
        .padding(.vertical, Theme.Spacing.lg)
}

#Preview("Dark") {
    @Previewable @State var kind: MediaKind?
    return MediaKindFilter(selection: $kind, available: [.movie, .book])
        .padding(.vertical, Theme.Spacing.lg)
        .preferredColorScheme(.dark)
}
