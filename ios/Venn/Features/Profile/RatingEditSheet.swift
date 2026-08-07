import SwiftUI

/// Change the rating on something already on your shelf.
///
/// The same three choices the composer offers, opened on whatever the item
/// currently holds — so the sheet shows you what you said before you change
/// it. Choosing the current value again clears it, which is how the
/// composer's chips already behave, so "no rating" needs no fourth control.
///
/// Mirrors the `RatingChips` popover web shows from the ⋯ menu.
struct RatingEditSheet: View {
    let item: LibraryItem
    /// Called with the action/rating pair to persist.
    var onSave: (PostAction, Double?) -> Void

    @Environment(\.dismiss)
    private var dismiss
    @State private var choice: ComposerViewModel.RatingChoice?

    var body: some View {
        NavigationStack {
            Screen {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    Text(item.media.title)
                        .font(Theme.Font.headline)
                        .foregroundStyle(Theme.Color.textPrimary)

                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(ComposerViewModel.RatingChoice.allCases, id: \.self) { option in
                            chip(option)
                        }
                    }

                    Spacer(minLength: 0)
                }
                .padding(Theme.Spacing.lg)
            }
            .navigationTitle("Edit rating")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let result = ComposerViewModel.RatingChoice.postValues(for: choice)
                        onSave(result.action, result.rating)
                    }
                    .accessibilityIdentifier("rating_edit_save")
                }
            }
            .onAppear { choice = ComposerViewModel.RatingChoice(rating: item.post.rating) }
        }
    }

    private func chip(_ option: ComposerViewModel.RatingChoice) -> some View {
        let isSelected = choice == option
        return Button {
            // Tapping the current choice clears it, so skipping needs no
            // separate control — same rule as the composer's chips.
            choice = isSelected ? nil : option
        } label: {
            Label(option.title, systemImage: option.systemImage)
                .font(Theme.Font.body.weight(.medium))
                .foregroundStyle(isSelected ? Theme.Color.onAccent : Theme.Color.textPrimary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(
                    isSelected ? Theme.Color.accent : Theme.Color.surface,
                    in: .capsule
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview("Light") {
    RatingEditSheet(
        item: LibraryItem(
            post: Post(
                id: UUID(),
                authorID: UUID(),
                mediaID: UUID(),
                action: .rated,
                rating: 5,
                caption: nil,
                createdAt: Date(timeIntervalSince1970: 0)
            ),
            media: Media(
                id: UUID(),
                kind: .movie,
                title: "Her",
                year: 2013,
                primaryCreator: "Spike Jonze",
                coverURL: nil,
                externalID: nil,
                externalSource: nil,
                createdAt: Date(timeIntervalSince1970: 0)
            )
        )
    ) { _, _ in }
}
