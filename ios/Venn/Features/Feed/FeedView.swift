import SwiftUI

/// Placeholder feed. The real feed renders posts from the people you follow
/// once `FeedService.recentPosts(limit:)` is wired up and posting lands.
/// For now it shows an empty state so the tab is real.
struct FeedView: View {
    var body: some View {
        NavigationStack {
            Screen {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        Text("Today")
                            .font(Theme.Font.largeTitle)
                            .foregroundStyle(Theme.Color.textPrimary)

                        VStack(spacing: Theme.Spacing.md) {
                            ActivityCard(
                                name: "Maya",
                                action: "logged",
                                title: "Past Lives",
                                detail: "quiet, devastating, exactly the right kind of Sunday movie",
                                rating: "4.5"
                            )
                            ActivityCard(
                                name: "Theo",
                                action: "rated",
                                title: "The Bear",
                                detail: "season 2 has the restaurant anxiety and the family ache",
                                rating: "4.0"
                            )
                        }
                    }
                    .padding(.vertical, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xxxl)
                }
            }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    FeedView()
}
