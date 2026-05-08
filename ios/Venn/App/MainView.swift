import SwiftUI

/// Selection type for `MainView`'s `TabView`. Lives at file scope so the
/// unqualified `Tab` inside the view body resolves to SwiftUI's `Tab`
/// rather than this enum.
enum MainTab: Hashable {
    case feed
    case search
    case profile
}

/// Signed-in app shell. Three tabs: Feed (default), Search, Profile. Each
/// tab is its own feature; routing into nested views happens inside the
/// tab via `NavigationStack`. Sign-out lives on the Profile tab.
struct MainView: View {
    @State private var selection: MainTab = .feed

    var body: some View {
        TabView(selection: $selection) {
            Tab("Feed", systemImage: "square.stack.3d.up", value: MainTab.feed) {
                FeedView()
            }
            Tab("Search", systemImage: "magnifyingglass", value: MainTab.search) {
                SearchView()
            }
            Tab("Profile", systemImage: "person.crop.circle", value: MainTab.profile) {
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
