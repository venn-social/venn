import SwiftUI

/// Shown exactly once: after the first sign-in, before the main app,
/// until a `profiles` row exists. Claims a username (the only required
/// field) and an optional display name. Field styling mirrors `AuthView`.
struct OnboardingView: View {
    @State var viewModel: OnboardingViewModel
    /// Called after the profile row is created — flips the onboarding gate.
    let onComplete: () -> Void

    @FocusState private var usernameFocused: Bool

    var body: some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                    header
                    fields
                    if let reason = viewModel.errorReason {
                        Text(errorMessage(for: reason))
                            .font(Theme.Font.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityIdentifier("onboarding_error")
                    }
                    PrimaryButton(
                        title: "Create profile",
                        isLoading: viewModel.state == .submitting,
                        isEnabled: viewModel.canSubmit
                    ) {
                        Task {
                            await viewModel.submit()
                            if viewModel.state == .done {
                                onComplete()
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.xxxl)
            }
            .scrollContentBackground(.hidden)
        }
        .onAppear { usernameFocused = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Claim your username")
                .font(Theme.Font.title)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("It's how people find you and your Venn. Lowercase letters, numbers, _ and - only.")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    private var fields: some View {
        VStack(spacing: Theme.Spacing.md) {
            HStack(spacing: Theme.Spacing.xs) {
                Text(verbatim: "@")
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.Color.textSecondary)
                TextField("username", text: $viewModel.username)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($usernameFocused)
                    .accessibilityIdentifier("onboarding_username_field")
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Color.surfaceStrong, in: .rect(cornerRadius: Theme.Radius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Theme.Color.separator, lineWidth: 1)
            }

            TextField("Display name (optional)", text: $viewModel.displayName)
                .textContentType(.name)
                .padding(Theme.Spacing.md)
                .background(Theme.Color.surfaceStrong, in: .rect(cornerRadius: Theme.Radius.sm))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Theme.Color.separator, lineWidth: 1)
                }
                .accessibilityIdentifier("onboarding_display_name_field")
        }
    }

    private func errorMessage(for reason: OnboardingViewModel.ErrorReason) -> LocalizedStringKey {
        switch reason {
        case .usernameTooShort: "Usernames need at least 3 characters."
        case .usernameTooLong: "Usernames max out at 24 characters."
        case .usernameInvalidCharacters: "Only lowercase letters, numbers, _ and - are allowed."
        case .usernameTaken: "That username is taken — try another."
        case .displayNameTooLong: "Display names max out at 40 characters."
        case .offline: "You're offline. Check your connection and try again."
        case .unknown: "Something went wrong. Please try again."
        }
    }
}

#Preview {
    OnboardingView(viewModel: OnboardingViewModel(
        userID: UUID(),
        service: OnboardingService(client: SupabaseClientProvider.preview.client)
    )) {}
}
