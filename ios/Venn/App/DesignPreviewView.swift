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

        @State private var debugAuth: AuthState?

        var body: some View {
            Group {
                if let debugAuth {
                    // The real shell, not a second copy of it. This used to
                    // rebuild MainView's TabView by hand, which meant a
                    // change to the real one (the side-menu control, the tab
                    // list) never showed up here — and the preview looked
                    // correct while the shipped shell went untested.
                    MainView(initialTab: Self.initialSelection)
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
