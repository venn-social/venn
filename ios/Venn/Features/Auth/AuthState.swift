import Foundation
import Observation
import Supabase

/// App-wide auth state. Owned by `VennApp`, injected via `.environment(...)`,
/// and observed by `RootView` so it can switch between the sign-in screen
/// and the main app when the user signs in or out.
///
/// `bootstrap()` runs once on launch: it reads the persisted session (if any)
/// and starts a long-running listener that reflects future auth changes.
@MainActor
@Observable
final class AuthState {
    enum Status: Equatable {
        /// Initial state before `bootstrap()` finishes — the app shows a
        /// splash/loading view here so the UI doesn't flash signed-out.
        case unknown
        case signedOut
        case signedIn(Session)
    }

    var status: Status = .unknown

    private let service: any AuthServicing
    private var listenerTask: Task<Void, Never>?

    init(service: any AuthServicing) {
        self.service = service
    }

    /// Loads the persisted session and starts the auth-state listener. Safe
    /// to call multiple times — subsequent calls cancel the prior listener.
    func bootstrap() async {
        do {
            if let session = try await service.currentSession() {
                status = .signedIn(session)
            } else {
                status = .signedOut
            }
        } catch {
            status = .signedOut
        }
        startListening()
    }

    /// Clears the local session. Status flips to `.signedOut` even if the
    /// server call fails — locally signed-out is the user's intent.
    func signOut() async {
        try? await service.signOut()
        status = .signedOut
    }

    #if DEBUG
        /// DEBUG bypass for the magic-link flow — gets straight into the app.
        /// Tries a real anonymous Supabase session first; if anonymous
        /// sign-ins are disabled in the project, falls back to a local debug
        /// session so the app stays reachable. Temporary: real onboarding
        /// replaces this later.
        func enterGuestSession() async {
            do {
                try await service.signInAnonymously()
                // A real anonymous session arrives via the auth-state
                // listener, which flips `status` to `.signedIn`.
            } catch {
                status = .signedIn(Self.debugGuestSession)
            }
        }

        /// Synthetic signed-in session for the DEBUG guest bypass. Pinned to a
        /// seeded profile's id so the Profile tab shows real data. Its token
        /// is never transmitted — reads go through the anon key — so nothing
        /// authenticates against this placeholder.
        private static var debugGuestSession: Session {
            let now = Date()
            let user = User(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
                appMetadata: [:],
                userMetadata: [:],
                aud: "authenticated",
                createdAt: now,
                updatedAt: now,
                isAnonymous: true
            )
            return Session(
                accessToken: "debug-guest",
                tokenType: "bearer",
                expiresIn: 3600,
                expiresAt: now.addingTimeInterval(3600).timeIntervalSince1970,
                refreshToken: "debug-guest",
                user: user
            )
        }
    #endif

    private func startListening() {
        listenerTask?.cancel()
        listenerTask = Task { [weak self, service] in
            for await session in service.sessionChanges {
                await MainActor.run {
                    guard let self else { return }
                    if let session {
                        self.status = .signedIn(session)
                    } else {
                        self.status = .signedOut
                    }
                }
            }
        }
    }
}
