import SwiftUI

/// Signed-in app shell. Three tabs: Feed (default), Search, Profile. Each
/// tab is its own feature; routing into nested views happens inside the
/// tab via `NavigationStack`. Sign-out lives on the Profile tab.
struct MainView: View {
    enum Tab: Hashable {
        case feed
        case search
        case profile
    }

    @State private var selectedTab: Tab = .feed

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Feed", systemImage: "square.stack.3d.up", value: Tab.feed) {
                FeedView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: Tab.search) {
                SearchView()
            }
            Tab("Profile", systemImage: "person.crop.circle", value: Tab.profile) {
                ProfileView()
            }
        }
        .accessibilityIdentifier("main_tab_view")
    }
}

#Preview {
    let provider = SupabaseClientProvider.preview
    let state = AuthState(service: AuthService(client: provider.client))
    return MainView()
        .environment(AppConfig.preview)
        .environment(provider)
        .environment(state)
}
