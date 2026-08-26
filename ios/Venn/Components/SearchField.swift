import SwiftUI

/// A search field: a magnifying glass, the text, and a way to clear it.
///
/// One hairline underneath rather than a filled, rounded box. Mirrors web,
/// where the field under the category tabs carries no border of its own —
/// its placeholder says what it is, and a filled rectangle inside a screen
/// of hairlines was the loudest thing on it.
///
/// Presentational: the owner decides what to do with `text`.
struct SearchField: View {
    @Binding var text: String
    var prompt: LocalizedStringKey
    var onSubmit: (() -> Void)?

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.Color.textSecondary)

            TextField(prompt, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { onSubmit?() }
                .foregroundStyle(Theme.Color.textPrimary)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.Color.textSecondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .font(Theme.Font.callout)
        .padding(.vertical, Theme.Spacing.sm + Theme.Spacing.xxs)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.Color.separator)
                .frame(height: 1)
        }
        .accessibilityIdentifier("search_field")
    }
}

#Preview {
    SearchField(text: .constant(""), prompt: "Search for anything")
        .padding(Theme.Spacing.lg)
}
