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
                    // Ghost id: the Feed/Explorer tabs render real public data, the
                    // Profile tab shows its error surface (no profiles row), and
                    // People search can find every real account (a ghost is never
                    // filtered out as "self").
                    state.status = .signedIn(DebugSession.make())
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
    }

    #Preview {
        DesignPreviewView()
            .environment(SupabaseClientProvider.preview)
    }
#endif
