import SwiftUI

/// What every empty list shows. Icon + title + body, with an optional
/// call-to-action button. Used when a feed has no posts, a search returns
/// no results, a profile has no activity yet, and so on.
///
/// Pass `actionTitle` and `action` together (or neither) — they're tied so
/// the button only appears when there's something to do.
struct EmptyStateView: View {
    let systemImage: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    init(
        systemImage: String,
        title: LocalizedStringKey,
        message: LocalizedStringKey,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: systemImage)
                .font(.system(size: 56))
                .foregroundStyle(Theme.Color.textSecondary)
            VStack(spacing: Theme.Spacing.xs) {
                Text(title)
                    .font(Theme.Font.title3)
                    .foregroundStyle(Theme.Color.textPrimary)
                Text(message)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                PrimaryButton(title: actionTitle, action: action)
                    .padding(.top, Theme.Spacing.sm)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityIdentifier("empty_state")
    }
}

#Preview("no action") {
    EmptyStateView(
        systemImage: "tray",
        title: "Nothing here yet",
        message: "Posts from people you follow will appear here."
    )
}

#Preview("with action") {
    EmptyStateView(
        systemImage: "person.2",
        title: "No friends yet",
        message: "Find friends to see where your tastes overlap.",
        actionTitle: "Find friends",
        action: {}
    )
}
