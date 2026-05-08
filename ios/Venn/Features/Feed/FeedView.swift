import SwiftUI

/// Placeholder feed. The real feed renders posts from the people you follow
/// once `FeedService.recentPosts(limit:)` is wired up and posting lands.
/// For now it shows an empty state so the tab is real.
struct FeedView: View {
    var body: some View {
        NavigationStack {
            Screen(padding: .init()) {
                EmptyStateView(
                    systemImage: "square.stack.3d.up",
                    title: "Nothing here yet",
                    message: "Posts from people you follow will appear here."
                )
            }
            .navigationTitle("Feed")
        }
    }
}

#Preview {
    FeedView()
}
