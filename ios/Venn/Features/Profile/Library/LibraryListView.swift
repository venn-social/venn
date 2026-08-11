import SwiftUI

/// Full-screen list of a user's watchlist or consumption collection for one
/// media kind (or all kinds when `kind == nil`). Pushed onto the Profile
/// `NavigationStack` when the user taps a pill inside `LibraryCategoryCard`.
struct LibraryListView: View {
    @State var viewModel: LibraryViewModel

    var body: some View {
        Screen {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Loading…")
            case let .loaded(items):
                if items.isEmpty {
                    emptyView
                } else {
                    ScrollView {
                        LazyVStack(spacing: Theme.Spacing.sm) {
                            ForEach(items) { item in
                                NavigationLink(value: item.media) {
                                    LibraryItemRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await viewModel.remove(item: item) }
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.vertical, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.xxxl)
                    }
                    .scrollContentBackground(.hidden)
                }
            case let .error(reason):
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load library") {
                    Task { await viewModel.load() }
                }
            }
        }
        .navigationTitle(viewModel.shelf.title)
        .navigationBarTitleDisplayMode(.inline)
        .containerBackground(for: .navigation) {
            Theme.Color.background
        }
        // The Profile stack this is pushed onto already registers a
        // `Media` destination; declaring a second one is ignored.
        .task { await viewModel.load() }
    }

    private var emptyView: some View {
        EmptyStateView(
            systemImage: viewModel.shelf == .watchlist ? "bookmark" : "checkmark.circle",
            title: viewModel.shelf == .watchlist ? "Nothing saved yet" : "Nothing logged yet",
            message: viewModel.shelf == .watchlist
                ? "Search for something in the Explorer tab and tap \"Add to Watchlist\"."
                : "Log what you've watched, read, or listened to using the Explorer tab."
        )
    }
}

// MARK: - Row

private struct LibraryItemRow: View {
    let item: LibraryItem

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            MediaCoverThumb(kind: item.media.kind, coverURL: item.media.coverURL)
            details
            Spacer()
            if let rating = item.post.rating {
                ratingBadge(rating)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.sm))
        .padding(.horizontal, Theme.Spacing.lg)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            Text(item.media.title)
                .font(Theme.Font.body.weight(.medium))
                .foregroundStyle(Theme.Color.textPrimary)
                .lineLimit(1)

            HStack(spacing: 4) {
                if let creator = item.media.primaryCreator {
                    Text(creator)
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .lineLimit(1)
                }
                if let year = item.media.year {
                    if item.media.primaryCreator != nil {
                        Text("·")
                            .font(Theme.Font.caption)
                            .foregroundStyle(Theme.Color.textSecondary)
                    }
                    Text(verbatim: "\(year)")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }

            if let caption = item.post.caption {
                Text(verbatim: "\"\(caption)\"")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(2)
                    .padding(.top, 2)
            }
        }
    }

    private func ratingBadge(_ rating: Double) -> some View {
        let label = switch rating {
        case 5...: "Love"
        case 3...: "Like"
        default: "Meh"
        }
        return Text(verbatim: label)
            .font(Theme.Font.caption.weight(.semibold))
            .foregroundStyle(Theme.Color.textPrimary)
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.vertical, Theme.Spacing.xs)
            .vennGlass(.regular, in: .capsule)
    }
}
