import SwiftUI

/// Placeholder search. The real search lets you find friends and look up
/// titles to log; both routes need data shapes that aren't locked yet, so
/// this tab ships as a navigation skeleton with a search field that
/// validates queries through `Sanitize.searchQuery` and an empty result
/// state.
struct SearchView: View {
    @State private var query = ""

    var body: some View {
        NavigationStack {
            Screen(padding: .init()) {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "Search venn",
                    message: "Find friends or look up something you've watched."
                )
            }
            .navigationTitle("Search")
            .searchable(text: $query, prompt: Text("Friends, movies, music…"))
        }
    }
}

#Preview {
    SearchView()
}
