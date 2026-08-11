import SwiftUI

/// Selection type for `MainView`'s `TabView`. Lives at file scope so the
/// unqualified `Tab` inside the view body resolves to SwiftUI's `Tab`
/// rather than this enum.
enum MainTab: Hashable, CaseIterable {
    case feed
    case explorer
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

/// Signed-in app shell. Three tabs: Feed (default), Explorer, Profile —
/// the places the product lives. Lists, Activity, Year in Review and
/// Settings moved behind `SideMenuView`, reached from the trailing control
/// on the toolbar, and are not linked anywhere else.
///
/// Each tab is its own feature; routing into nested views happens inside
/// the tab via `NavigationStack`.
struct MainView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider

    /// Which tab opens first. Defaults to Feed; the DEBUG preview shell
    /// passes a pinned tab so UI tests can land straight on one.
    var initialTab: MainTab = .feed

    @State private var selection: MainTab = .feed
    @State private var showMenu = false
    @State private var menuDestination: SideMenuDestination?
    /// Built when Settings is opened, because it needs the signed-in
    /// profile's id and privacy flag, which only exist once loaded.
    @State private var settingsViewModel: SettingsViewModel?
    @Environment(AuthState.self)
    private var authState
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
        .overlay(alignment: .topLeading) { menuButton }
        .overlay {
            if showMenu {
                SideMenuView(
                    isPresented: $showMenu,
                    unreadCount: notifications?.unreadCount ?? 0
                ) { destination in
                    menuDestination = destination
                }
            }
        }
        .sheet(item: $menuDestination) { destination in
            menuSheet(for: destination)
        }
        .task { await ensureNotificationsLoaded() }
        .onAppear { selection = initialTab }
    }

    /// Trailing control that opens the secondary surfaces. An overlay
    /// rather than a toolbar item because each tab owns its own
    /// `NavigationStack`, so there is no shared toolbar to hang it from.
    private var menuButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                showMenu = true
            }
        } label: {
            Image(systemName: "line.3.horizontal")
                .font(Theme.Font.headline)
                .foregroundStyle(Theme.Color.textPrimary)
                .padding(Theme.Spacing.sm)
                .background(.ultraThinMaterial, in: .circle)
                .overlay(alignment: .topTrailing) {
                    if (notifications?.unreadCount ?? 0) > 0 {
                        Circle()
                            .fill(Theme.Color.accent)
                            .frame(width: 8, height: 8)
                    }
                }
        }
        .buttonStyle(.plain)
        .padding(.leading, Theme.Spacing.lg)
        .accessibilityLabel("More")
        .accessibilityIdentifier("side_menu_button")
    }

    @ViewBuilder
    private func menuSheet(for destination: SideMenuDestination) -> some View {
        switch destination {
        case .lists: ListsView()
        case .activity: activityTab
        case .yearInReview: YearInReviewView()
        case .settings: settingsSheet
        }
    }

    @ViewBuilder private var settingsSheet: some View {
        if let settingsViewModel {
            SettingsView(viewModel: settingsViewModel) { menuDestination = nil }
        } else {
            DeferredLoadingView()
                .task { await loadSettingsViewModel() }
        }
    }

    /// Reads the signed-in user straight from the session rather than
    /// waiting on ProfileView — the menu can be opened from any tab.
    private func loadSettingsViewModel() async {
        guard settingsViewModel == nil,
              case let .signedIn(session) = authState.status
        else {
            return
        }
        let userID = session.user.id
        let service = ProfileService(client: clientProvider.client)
        let isPrivate = await (try? service.profile(for: userID))?.isPrivate ?? false
        settingsViewModel = SettingsViewModel(
            userID: userID,
            isPrivate: isPrivate,
            service: service
        )
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
