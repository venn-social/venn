import SwiftUI

/// Liquid Glass segmented control for small, mutually-exclusive option sets.
///
/// It centralizes selection animation, haptics, symbol transitions, and
/// accessibility so feature screens don't build their own chip controls.
struct GlassSegmentedControl<Item: Hashable & Identifiable>: View where Item.ID: Sendable {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    let systemImage: (Item) -> String

    @Namespace private var glassNamespace
    @State private var selectionFeedbackToken = 0

    var body: some View {
        GlassEffectContainer(spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.xs) {
                ForEach(items) { item in
                    optionButton(for: item)
                }
            }
        }
        .vennSelectionFeedback(trigger: selectionFeedbackToken)
    }

    private func optionButton(for item: Item) -> some View {
        let isSelected = item == selection

        return Button {
            guard item != selection else { return }
            withAnimation(.smooth(duration: 0.24, extraBounce: 0.08)) {
                selection = item
            }
            selectionFeedbackToken += 1
        } label: {
            optionLabel(for: item, isSelected: isSelected)
        }
        .buttonStyle(VennPressButtonStyle(feedback: .none))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func optionLabel(for item: Item, isSelected: Bool) -> some View {
        let label = ZStack {
            if isSelected {
                Capsule()
                    .fill(Theme.Color.graphite)
            }

            HStack(spacing: Theme.Spacing.xs) {
                Image(systemName: systemImage(item))
                    .font(Theme.Font.caption.weight(.semibold))
                    .symbolEffect(.bounce, value: isSelected)
                Text(verbatim: title(item))
                    .font(Theme.Font.caption.weight(.semibold))
            }
            .foregroundStyle(isSelected ? Theme.Color.onAccent : Theme.Color.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .contentShape(Capsule())

        if isSelected {
            label
                .vennGlass(.accent, in: .capsule)
                .glassEffectID(item.id, in: glassNamespace)
                .glassEffectTransition(.matchedGeometry)
        } else {
            label
        }
    }
}

#Preview {
    @Previewable @State var selection = ExplorerCategory.movies

    Screen {
        GlassSegmentedControl(
            items: ExplorerCategory.allCases,
            selection: $selection,
            title: \.title,
            systemImage: \.icon
        )
    }
}
