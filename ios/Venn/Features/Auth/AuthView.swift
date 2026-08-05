import Supabase
import SwiftUI

/// Magic-link sign-in screen. Three render branches off `viewModel.state`:
///
/// - `.idle` / `.sending` / `.error` — show the email field + Continue
///   button. The error message renders below the field; `.sending` swaps
///   the button's title for a spinner.
/// - `.sent` — confirmation: "we sent a link to <email>". Has a "use a
///   different email" affordance that resets back to `.idle`.
struct AuthView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var emailFieldFocused: Bool

    #if DEBUG
        @Environment(AuthState.self)
        private var authState
        @State private var isEnteringGuest = false
        @State private var guestFailed = false
    #endif

    var body: some View {
        Screen {
            VStack(spacing: Theme.Spacing.xl) {
                Spacer()

                header

                switch viewModel.state {
                case .idle, .sending, .error:
                    inputForm
                case .sent:
                    sentConfirmation
                }

                Spacer()

                #if DEBUG
                    guestBypass
                #endif

                Text("Private beta")
                    .font(Theme.Font.caption.weight(.semibold))
                    .foregroundStyle(Theme.Color.textSecondary)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.sm)
                    .background(Theme.Color.surface, in: .capsule)
            }
        }
    }

    #if DEBUG
        /// Developer affordance: a real anonymous session, straight into the
        /// app. Fails honestly when the project has anonymous sign-ins
        /// disabled (Supabase dashboard → Authentication → Providers).
        private var guestBypass: some View {
            VStack(spacing: Theme.Spacing.xs) {
                Button {
                    isEnteringGuest = true
                    guestFailed = false
                    Task {
                        let ok = await authState.enterGuestSession()
                        isEnteringGuest = false
                        guestFailed = !ok
                    }
                } label: {
                    Text(isEnteringGuest ? "Signing in…" : "Continue as guest")
                        .font(Theme.Font.footnote.weight(.semibold))
                        .foregroundStyle(Theme.Color.accent)
                }
                .disabled(isEnteringGuest)
                .accessibilityIdentifier("auth_guest_button")

                if guestFailed {
                    Text("Guest sign-in is disabled for this project — enable anonymous sign-ins in Supabase.")
                        .font(Theme.Font.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }
            }
        }
    #endif

    private var header: some View {
        VStack(spacing: Theme.Spacing.lg) {
            VennMark(size: 84)

            Text(verbatim: "venn")
                .font(Theme.Font.largeTitle)
                .foregroundStyle(Theme.Color.textPrimary)

            Text("you have good taste. explore it.")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var inputForm: some View {
        VStack(spacing: Theme.Spacing.md) {
            TextField("Email", text: $viewModel.email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($emailFieldFocused)
                .padding(Theme.Spacing.md)
                .background(
                    Theme.Color.surfaceStrong,
                    in: .rect(cornerRadius: Theme.Radius.sm)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Theme.Color.separator, lineWidth: 1)
                }
                .accessibilityIdentifier("auth_email_field")

            if case let .error(reason) = viewModel.state {
                Text(errorMessage(for: reason))
                    .font(Theme.Font.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("auth_error")
            }

            PrimaryButton(
                title: "Continue",
                isLoading: viewModel.state == .sending,
                isEnabled: viewModel.canSubmit
            ) {
                emailFieldFocused = false
                Task { await viewModel.submit() }
            }
        }
        .padding(Theme.Spacing.lg)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: Theme.Radius.sm))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.sm)
                .stroke(Theme.Color.separator, lineWidth: 1)
        }
    }

    /// The "verify your email" screen. The magic link doubles as email
    /// verification, so the copy says so; resend unlocks after a cooldown
    /// (the TimelineView re-evaluates the countdown once per second).
    private var sentConfirmation: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "envelope.badge")
                .font(Theme.Font.largeTitle)
                .foregroundStyle(Theme.Color.accent)

            Text("Check your inbox")
                .font(Theme.Font.title2)
                .foregroundStyle(Theme.Color.textPrimary)

            Text(
                "We emailed a sign-in link to \(Text(verbatim: viewModel.email).bold()). Tapping it verifies your email and signs you in."
            )
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Color.textSecondary)
            .multilineTextAlignment(.center)

            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let remaining = viewModel.resendSecondsRemaining
                PrimaryButton(
                    title: remaining > 0 ? "Resend in \(remaining)s" : "Resend link",
                    isEnabled: viewModel.canResend
                ) {
                    Task { await viewModel.resend() }
                }
            }
            .padding(.top, Theme.Spacing.sm)
            .accessibilityIdentifier("auth_resend_button")

            Button {
                viewModel.reset()
            } label: {
                Text("Use a different email")
                    .font(Theme.Font.callout.weight(.semibold))
                    .foregroundStyle(Theme.Color.accent)
            }
            .padding(.top, Theme.Spacing.xs)
        }
        .padding(Theme.Spacing.lg)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: Theme.Radius.sm))
        .accessibilityIdentifier("auth_sent_confirmation")
    }

    private func errorMessage(for reason: AuthViewModel.ErrorReason) -> LocalizedStringKey {
        switch reason {
        case .invalidEmail: "Please enter a valid email address."
        case .offline: "You're offline. Check your connection and try again."
        case .rateLimited: "Too many sign-in requests. Try again in a few minutes."
        case .sendFailed: "Couldn't send the magic link. Please try again."
        }
    }
}

#Preview("idle") {
    AuthView(viewModel: AuthViewModel(
        service: PreviewAuthService(),
        redirectURL: URL(staticString: "social.venn.app://auth-callback")
    ))
    .environment(AuthState(service: PreviewAuthService()))
}

#Preview("sent") {
    let viewModel = AuthViewModel(
        service: PreviewAuthService(),
        redirectURL: URL(staticString: "social.venn.app://auth-callback")
    )
    viewModel.email = "charles@example.com"
    viewModel.state = .sent
    return AuthView(viewModel: viewModel)
        .environment(AuthState(service: PreviewAuthService()))
}

/// Periphery flags this as unused — it's reachable only from the
/// `#Preview` macro above, which periphery cannot statically resolve.
private struct PreviewAuthService: AuthServicing {
    var sessionChanges: AsyncStream<Session?> {
        AsyncStream { _ in }
    }

    func currentSession() async throws -> Session? {
        nil
    }

    func sendMagicLink(email _: String, redirectTo _: URL) async throws {}
    func handleCallback(_: URL) async throws {}
    func signOut() async throws {}
    func signInAnonymously() async throws {}
}
