import Supabase
import SwiftUI

/// Magic-link sign-in, laid out to match `web/app/(auth)/login/page.tsx`
/// element for element: the wordmark and tagline, a bordered card holding
/// the email field and Continue, and — once sent — the inbox panel with a
/// code field.
///
/// Plain background, like every other screen now that iOS has dropped the
/// atmospheric gradient in favour of matching web.
///
/// Render branches off `viewModel.state`:
/// - `.idle` / `.sending` / `.error` — email field + Continue.
/// - `.sent` / `.verifying` — inbox panel: paste the code, or use the link.
struct AuthView: View {
    @Bindable var viewModel: AuthViewModel
    @FocusState private var emailFieldFocused: Bool
    @FocusState private var codeFieldFocused: Bool

    #if DEBUG
        @Environment(AuthState.self)
        private var authState
        @State private var isEnteringGuest = false
        @State private var guestFailed = false
    #endif

    var body: some View {
        ZStack {
            Theme.Color.background
                .ignoresSafeArea()

            VStack(spacing: Theme.Spacing.lg) {
                Spacer()

                header

                switch viewModel.state {
                case .idle, .sending, .error:
                    inputForm
                case .sent, .verifying:
                    sentConfirmation
                }

                Spacer()

                #if DEBUG
                    guestBypass
                #endif
            }
            .padding(Theme.Spacing.lg)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Wordmark and tagline only. Web shows no logo here, and this screen is
    /// the one users compare side by side.
    private var header: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text(verbatim: "venn")
                .font(Theme.Font.title2)
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
        .cardOutline()
    }

    /// The inbox panel. The emailed code is the fallback for when the link
    /// does not work — it opens in the wrong browser, a mail client
    /// rewrites it, or it never arrives as something tappable.
    private var sentConfirmation: some View {
        VStack(spacing: Theme.Spacing.md) {
            Text("Check your inbox")
                .font(Theme.Font.title2)
                .foregroundStyle(Theme.Color.textPrimary)

            Text(
                "We emailed a sign-in link to \(Text(verbatim: viewModel.email).bold()). "
                    + "Tapping it verifies your email and signs you in — or enter the code "
                    + "from that same email below."
            )
            .font(Theme.Font.body)
            .foregroundStyle(Theme.Color.textSecondary)
            .multilineTextAlignment(.center)

            TextField("Code from email", text: $viewModel.code)
                .textContentType(.oneTimeCode)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .focused($codeFieldFocused)
                .padding(Theme.Spacing.md)
                .background(
                    Theme.Color.surfaceStrong,
                    in: .rect(cornerRadius: Theme.Radius.sm)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.sm)
                        .stroke(Theme.Color.separator, lineWidth: 1)
                }
                .accessibilityIdentifier("auth_code_field")

            if viewModel.verifyFailed {
                Text("That code didn't work — check it and try again.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("auth_code_error")
            }

            PrimaryButton(
                title: "Verify code",
                isLoading: viewModel.state == .verifying,
                isEnabled: viewModel.canVerify
            ) {
                codeFieldFocused = false
                Task { await viewModel.verifyCode() }
            }
            .accessibilityIdentifier("auth_verify_button")

            // Kept beyond web's layout: without it, a link that never
            // arrives is a dead end, and the code cannot be read out of a
            // message that was never delivered. Web should gain this rather
            // than iOS losing it.
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                let remaining = viewModel.resendSecondsRemaining
                Button {
                    Task { await viewModel.resend() }
                } label: {
                    Text(remaining > 0 ? "Resend in \(remaining)s" : "Resend link")
                        .font(Theme.Font.footnote.weight(.semibold))
                        .foregroundStyle(Theme.Color.accent)
                }
                .disabled(!viewModel.canResend)
            }
            .accessibilityIdentifier("auth_resend_button")

            Button {
                viewModel.reset()
            } label: {
                Text("Use a different email")
                    .font(Theme.Font.footnote.weight(.semibold))
                    .foregroundStyle(Theme.Color.accent)
            }
        }
        .padding(Theme.Spacing.lg)
        .cardOutline()
        .accessibilityIdentifier("auth_sent_confirmation")
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

    private func errorMessage(for reason: AuthViewModel.ErrorReason) -> LocalizedStringKey {
        switch reason {
        case .invalidEmail: "Please enter a valid email address."
        case .offline: "You're offline. Check your connection and try again."
        case .rateLimited: "Too many sign-in requests. Try again in a few minutes."
        case .sendFailed: "Couldn't send the magic link. Please try again."
        case .badCode: "That code didn't work — check it and try again."
        }
    }
}

/// Web's sign-in card is a plain bordered box, not a glass surface. Shared
/// by both panels so they cannot drift apart.
private extension View {
    func cardOutline() -> some View {
        background(Theme.Color.background, in: .rect(cornerRadius: Theme.Radius.md))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .stroke(Theme.Color.separator, lineWidth: 1)
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

#Preview("sent — dark") {
    let viewModel = AuthViewModel(
        service: PreviewAuthService(),
        redirectURL: URL(staticString: "social.venn.app://auth-callback")
    )
    viewModel.email = "charles@example.com"
    viewModel.state = .sent
    return AuthView(viewModel: viewModel)
        .environment(AuthState(service: PreviewAuthService()))
        .preferredColorScheme(.dark)
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
    func verifyCode(email _: String, token _: String) async throws {}
    func handleCallback(_: URL) async throws {}
    func signOut() async throws {}
    func signInAnonymously() async throws {}
}
