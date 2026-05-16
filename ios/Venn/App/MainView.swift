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

/// Signed-in app shell. Three tabs: Feed (default), Explorer, Profile. Each
/// tab is its own feature; routing into nested views happens inside the
/// tab via `NavigationStack`. Sign-out lives on the Profile tab.
struct MainView: View {
    @State private var selection: MainTab = .feed

    var body: some View {
        TabView(selection: $selection) {
            Tab("Feed", systemImage: "square.stack.3d.up", value: MainTab.feed) {
                FeedView()
            }
            Tab("Explorer", systemImage: "sparkle.magnifyingglass", value: MainTab.explorer) {
                ExplorerView()
            }
            Tab("Profile", systemImage: "person.crop.circle", value: MainTab.profile) {
                ProfileView()
            }
        }
        .tint(Theme.Color.accent)
        .vennTabFeedback(trigger: selection)
        .swipeBetweenTabs(selection: $selection)
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
        .environment(AppearanceSettings())
}
