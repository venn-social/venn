import SwiftUI

/// A rounded search field with a leading magnifying glass and a clear
/// button. Presentational — the owner decides what to do with `text`
/// (filtering, querying). Used at the top of Explorer.
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
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + Theme.Spacing.xxs)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.md))
        .accessibilityIdentifier("search_field")
    }
}

#Preview {
    SearchField(text: .constant(""), prompt: "Search movies, music, books")
        .padding(Theme.Spacing.lg)
}
