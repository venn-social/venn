import SwiftUI

/// Chip row for narrowing a shelf to one media kind. Sits directly under
/// `ShelfTabs`, and mirrors web's `MediaKindFilter.tsx` chip for chip.
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
                HStack(spacing: Theme.Spacing.xs) {
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
                .font(Theme.Font.caption.weight(.medium))
                .foregroundStyle(isSelected ? Theme.Color.onAccent : Theme.Color.textSecondary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.xs)
                .background(
                    isSelected ? Theme.Color.accent : Theme.Color.surface,
                    in: .capsule
                )
                .contentShape(.capsule)
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
