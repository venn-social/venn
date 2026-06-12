import SwiftUI

#if DEBUG
    import Supabase

    /// DEBUG-only harness that renders the three real signed-in tabs without
    /// going through auth, so screens can be previewed and UI-tested in
    /// isolation. Profile needs a signed-in user id, so we inject a debug
    /// `AuthState` pinned to a seeded profile (Maya); reads still go through
    /// the real client, so every tab shows real data.
    struct DesignPreviewView: View {
        @Environment(SupabaseClientProvider.self)
        private var clientProvider

        @State private var selection = initialSelection
        @State private var debugAuth: AuthState?

        var body: some View {
            Group {
                if let debugAuth {
                    TabView(selection: $selection) {
                        // Mirrors MainView: hidden tab-bar background so
                        // only the floating glass pill sits over the app.
                        Tab(value: MainTab.feed) {
                            FeedView()
                                .toolbarBackground(.hidden, for: .tabBar)
                        } label: {
                            Image(systemName: "house").accessibilityLabel("Home")
                        }
                        Tab(value: MainTab.explorer) {
                            ExplorerView()
                                .toolbarBackground(.hidden, for: .tabBar)
                        } label: {
                            Image(systemName: "magnifyingglass").accessibilityLabel("Search")
                        }
                        Tab(value: MainTab.profile) {
                            ProfileView()
                                .toolbarBackground(.hidden, for: .tabBar)
                        } label: {
                            Image(systemName: "person.fill").accessibilityLabel("Profile")
                        }
                    }
                    .tint(Theme.Color.accent)
                    .vennTabFeedback(trigger: selection)
                    .swipeBetweenTabs(selection: $selection)
                    .environment(debugAuth)
                } else {
                    Color.clear
                }
            }
            .task {
                if debugAuth == nil {
                    let state = AuthState(service: AuthService(client: clientProvider.client))
                    state.status = .signedIn(Self.debugSession)
                    debugAuth = state
                }
            }
        }

        private static var initialSelection: MainTab {
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-previewExplorer") {
                return .explorer
            }
            if arguments.contains("-previewProfile") {
                return .profile
            }
            return .feed
        }

        /// Synthetic signed-in session pinned to a fixed "ghost" id that
        /// has no profile row. The shell is for layout work, not account
        /// flows: the Feed/Explorer tabs render real public data, the
        /// Profile tab shows its error surface, and People search can find
        /// every real account (a ghost is never filtered out as "self").
        /// The token is never transmitted — reads go through the anon key.
        private static var debugSession: Session {
            let now = Date()
            let user = User(
                id: UUID(uuidString: "0000dead-0000-4000-8000-000000000001") ?? UUID(),
                appMetadata: [:],
                userMetadata: [:],
                aud: "authenticated",
                createdAt: now,
                updatedAt: now,
                isAnonymous: true
            )
            return Session(
                accessToken: "design-preview",
                tokenType: "bearer",
                expiresIn: 3600,
                expiresAt: now.addingTimeInterval(3600).timeIntervalSince1970,
                refreshToken: "design-preview",
                user: user
            )
        }
    }

    #Preview {
        DesignPreviewView()
            .environment(SupabaseClientProvider.preview)
    }
#endif
