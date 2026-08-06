import SwiftUI

/// Selection type for `MainView`'s `TabView`. Lives at file scope so the
/// unqualified `Tab` inside the view body resolves to SwiftUI's `Tab`
/// rather than this enum.
enum MainTab: Hashable, CaseIterable {
    case feed
    case explorer
    case lists
    case activity
    case profile

    /// Tab to the right of this one (or nil at the trailing edge).
    var next: MainTab? {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self), idx + 1 < all.count else {
            return nil
        }
        return all[idx + 1]
    }

    /// Tab to the left of this one (or nil at the leading edge).
    var previous: MainTab? {
        let all = Self.allCases
        guard let idx = all.firstIndex(of: self), idx > 0 else { return nil }
        return all[idx - 1]
    }
}

extension View {
    /// Horizontal swipe across the body cycles `selection` between tabs.
    /// Uses `.simultaneousGesture` so it coexists with vertical scrolling
    /// inside each tab's content. The 2:1 horizontal-to-vertical bias
    /// check rejects diagonal scrolls so vertical reads don't accidentally
    /// trigger a tab switch.
    func swipeBetweenTabs(selection: Binding<MainTab>) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    let horizontal = value.translation.width
                    let vertical = value.translation.height
                    guard abs(horizontal) > abs(vertical) * 2,
                          abs(horizontal) > 60
                    else {
                        return
                    }
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        if horizontal > 0, let previous = selection.wrappedValue.previous {
                            selection.wrappedValue = previous
                        } else if horizontal < 0, let next = selection.wrappedValue.next {
                            selection.wrappedValue = next
                        }
                    }
                }
        )
    }
}

/// Signed-in app shell. Five tabs: Feed (default), Explorer, Lists,
/// Activity, Profile. Each tab is its own feature; routing into nested
/// views happens inside the tab via `NavigationStack`.
struct MainView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    @State private var selection: MainTab = .feed
    /// Owned here, not by `NotificationsView`, so the badge is right before
    /// the tab has ever been opened — which is the entire point of a badge.
    @State private var notifications: NotificationsViewModel?

    var body: some View {
        TabView(selection: $selection) {
            // .toolbarBackground(.hidden, for: .tabBar) on each tab's
            // content removes the full-width edge band behind the bar so
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
            Tab(value: MainTab.lists) {
                ListsView()
                    .toolbarBackground(.hidden, for: .tabBar)
            } label: {
                Image(systemName: "list.bullet").accessibilityLabel("Lists")
            }
            Tab(value: MainTab.activity) {
                activityTab
                    .toolbarBackground(.hidden, for: .tabBar)
            } label: {
                Image(systemName: "bell").accessibilityLabel("Activity")
            }
            .badge(notifications?.unreadCount ?? 0)
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
        .accessibilityIdentifier("main_tab_view")
        .task { await ensureNotificationsLoaded() }
    }

    @ViewBuilder private var activityTab: some View {
        if let notifications {
            NotificationsView(viewModel: notifications)
        } else {
            DeferredLoadingView()
        }
    }

    /// Fetches the badge count, not the list. The list loads when the tab
    /// is opened; the count has to be right before that.
    private func ensureNotificationsLoaded() async {
        if notifications == nil {
            notifications = NotificationsViewModel(
                service: NotificationService(client: clientProvider.client)
            )
        }
        await notifications?.refreshBadge()
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
