import SwiftUI

/// One list and its items. Mirrors web's `/lists/[id]` in copy and
/// behaviour (CLAUDE.md rule 17).
struct ListDetailView: View {
    let list: UserList
    let viewerID: UUID
    let service: any ListServicing

    @State private var viewModel: ListDetailViewModel?

    private var isOwner: Bool {
        list.ownerID == viewerID
    }

    var body: some View {
        Screen {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header

                    if let viewModel {
                        content(viewModel)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
        }
        .navigationTitle(list.title)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Media.self) { media in
            MediaDetailView(media: media)
        }
        .task { await ensureLoaded() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(list.title)
                    .font(Theme.Font.title2)
                    .foregroundStyle(Theme.Color.textPrimary)

                if !list.isPublic {
                    Text("Private")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .padding(.vertical, Theme.Spacing.xxs)
                        .background(
                            Theme.Color.surfaceStrong,
                            in: .capsule
                        )
                }
            }

            if let description = list.description, !description.isEmpty {
                Text(description)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: ListDetailViewModel) -> some View {
        switch viewModel.state {
        case .loading:
            DeferredLoadingView(caption: "Loading the list…")
        case let .loaded(items):
            if items.isEmpty {
                Text("Nothing in this list yet.")
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    ForEach(items) { item in
                        itemRow(item, viewModel: viewModel)
                    }
                }
            }
        case let .error(reason):
            ErrorStateView(reason: reason, unknownTitle: "Couldn't load the list") {
                Task { await viewModel.load() }
            }
        }
    }

    private func itemRow(_ item: ListItem, viewModel: ListDetailViewModel) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            // Cover and title open the title; "Remove" stays outside the
            // link so the row has exactly one tap target per action.
            NavigationLink(value: item.media) {
                HStack(spacing: Theme.Spacing.md) {
                    MediaCoverThumb(kind: item.media.kind, coverURL: item.media.coverURL)

                    VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                        Text(item.media.title)
                            .font(Theme.Font.callout.weight(.medium))
                            .foregroundStyle(Theme.Color.textPrimary)
                        if let note = item.note, !note.isEmpty {
                            Text(note)
                                .font(Theme.Font.footnote)
                                .foregroundStyle(Theme.Color.textSecondary)
                        }
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: Theme.Spacing.sm)

            if isOwner {
                Button("Remove") {
                    Task { await viewModel.remove(mediaID: item.media.id) }
                }
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
            }
        }
    }

    private func ensureLoaded() async {
        if viewModel == nil {
            let model = ListDetailViewModel(listID: list.id, service: service)
            viewModel = model
            await model.load()
        }
    }
}
