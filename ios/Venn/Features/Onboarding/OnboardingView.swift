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
                    // Username-specific verdicts render live under the
                    // field (availabilityHint) — only the reasons that
                    // hint can't show appear here.
                    if let reason = viewModel.errorReason, !isUsernameSpecific(reason) {
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
            Text("Step 1 of 2")
                .font(Theme.Font.caption.weight(.semibold))
                .foregroundStyle(Theme.Color.textSecondary)
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
                availabilityIndicator
            }
            .padding(Theme.Spacing.md)
            .background(Theme.Color.surfaceStrong, in: .rect(cornerRadius: Theme.Radius.sm))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.sm)
                    .stroke(Theme.Color.separator, lineWidth: 1)
            }
            .onChange(of: viewModel.username) { _, _ in
                viewModel.usernameChanged()
            }

            availabilityHint

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

    /// Trailing glyph inside the username field: spinner while checking,
    /// ✓ when free, ✗ when taken or malformed.
    @ViewBuilder private var availabilityIndicator: some View {
        switch viewModel.availability {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView()
                .controlSize(.small)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .taken, .invalid:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    /// One-line live verdict under the field, so the user knows before
    /// ever tapping Continue.
    @ViewBuilder private var availabilityHint: some View {
        switch viewModel.availability {
        case let .available(handle):
            Text("@\(handle) is available")
                .font(Theme.Font.caption)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .taken(handle):
            Text("@\(handle) is taken — try another")
                .font(Theme.Font.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        case let .invalid(reason):
            Text(errorMessage(for: reason))
                .font(Theme.Font.caption)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .idle, .checking:
            EmptyView()
        }
    }

    private func isUsernameSpecific(_ reason: OnboardingViewModel.ErrorReason) -> Bool {
        switch reason {
        case .usernameTooShort, .usernameTooLong, .usernameInvalidCharacters, .usernameTaken:
            true
        case .displayNameTooLong, .offline, .unknown:
            false
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
