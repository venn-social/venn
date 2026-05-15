import SwiftUI

/// Frontend prototype for the Explorer tab: recommendations plus search for
/// movies, music, and books the user has watched/read/listened to or wants to.
struct ExplorerView: View {
    @State private var query = ""
    @State private var selectedCategory: ExplorerCategory = .movies

    var body: some View {
        NavigationStack {
            Screen {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
                        header
                        categoryPicker
                        recommendationStack
                        quickActions
                    }
                    .padding(.vertical, Theme.Spacing.lg)
                    .padding(.bottom, Theme.Spacing.xxxl)
                }
            }
            .navigationTitle("Explorer")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, prompt: Text("Search movies, music, books"))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Explorer")
                .font(Theme.Font.largeTitle)
                .foregroundStyle(Theme.Color.textPrimary)
            Text("Search what you know, find what to try next, and save it to your profile.")
                .font(Theme.Font.body)
                .foregroundStyle(Theme.Color.textSecondary)
        }
    }

    private var categoryPicker: some View {
        GlassSegmentedControl(
            items: ExplorerCategory.allCases,
            selection: $selectedCategory,
            title: \.title,
            systemImage: \.icon
        )
    }

    private var recommendationStack: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Recommended for you")
                .font(Theme.Font.title3)
                .foregroundStyle(Theme.Color.textPrimary)

            ExplorerRecommendationCard(
                category: selectedCategory,
                title: selectedCategory.sampleTitle,
                detail: selectedCategory.sampleDetail
            )
            .vennScrollDepth()
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            ExplorerActionRow(
                icon: "checkmark.circle",
                title: "Add to watched",
                detail: "Keep a permanent record of what you consumed."
            )
            .vennScrollDepth()
            ExplorerActionRow(
                icon: "bookmark",
                title: "Save to watchlist",
                detail: "A softer maybe list for later."
            )
            .vennScrollDepth()
        }
    }
}

#Preview {
    ExplorerView()
}
