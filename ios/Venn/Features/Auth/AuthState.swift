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
