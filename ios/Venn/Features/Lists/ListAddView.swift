import SwiftUI

/// Search the catalog and append a result to this list. Mirrors web's
/// `AddToList.tsx` in copy and behaviour (CLAUDE.md rule 17).
///
/// Presented as a sheet from `ListDetailView` rather than inline, so the
/// list itself stays readable while you're adding to it.
struct ListAddView: View {
    let viewModel: ListAddViewModel
    /// Called on dismiss so the list behind reloads and shows what landed.
    let onDone: () -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State private var query = ""

    private static let kinds: [(kind: MediaKind, label: LocalizedStringKey)] = [
        (.movie, "Movies"),
        (.show, "Shows"),
        (.book, "Books"),
        (.album, "Albums"),
    ]

    var body: some View {
        NavigationStack {
            Screen(padding: EdgeInsets()) {
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                        SearchField(text: $query, prompt: "Search for anything")
                        kindPicker
                        results

                        if let message = viewModel.errorMessage {
                            Text(message)
                                .font(Theme.Font.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                }
            }
            .navigationTitle("Add to list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDone()
                        dismiss()
                    }
                }
            }
        }
        .onChange(of: query) { _, newQuery in
            viewModel.search(newQuery)
        }
    }

    private var kindPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(Self.kinds, id: \.kind) { entry in
                    Button {
                        viewModel.kind = entry.kind
                    } label: {
                        Text(entry.label)
                            .font(Theme.Font.footnote.weight(.medium))
                            .foregroundStyle(
                                viewModel.kind == entry.kind
                                    ? Theme.Color.onAccent
                                    : Theme.Color.textSecondary
                            )
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .background(
                                viewModel.kind == entry.kind
                                    ? Theme.Color.accent
                                    : Theme.Color.surfaceStrong,
                                in: .capsule
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollClipDisabled()
    }

    @ViewBuilder private var results: some View {
        switch viewModel.searchState {
        case .idle:
            Text("Search for something to add.")
                .font(Theme.Font.callout)
                .foregroundStyle(Theme.Color.textSecondary)
        case .searching:
            DeferredLoadingView(caption: "Searching…")
        case let .results(candidates):
            if candidates.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No results",
                    message: "Try a different search or switch categories."
                )
            } else {
                VStack(spacing: Theme.Spacing.sm) {
                    ForEach(candidates) { candidate in
                        row(candidate)
                    }
                }
            }
        case let .error(reason):
            ErrorStateView(reason: reason, unknownTitle: "Search failed")
        }
    }

    private func row(_ candidate: MediaCandidate) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ExplorerSearchResultRow(candidate: candidate) {
                Task { await viewModel.add(candidate) }
            }

            if viewModel.added.contains(candidate.id) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.Color.accent)
                    .accessibilityLabel("Added")
            } else if viewModel.working == candidate.id {
                ProgressView()
            }
        }
    }
}
