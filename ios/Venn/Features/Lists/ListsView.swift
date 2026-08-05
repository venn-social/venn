import SwiftUI

/// The signed-in user's lists, with a sheet to create another. Mirrors
/// web's `/lists` in copy and behaviour (CLAUDE.md rule 17).
struct ListsView: View {
    @Environment(SupabaseClientProvider.self)
    private var clientProvider
    @Environment(AuthState.self)
    private var authState

    @State private var viewModel: ListsViewModel?
    @State private var showingCreate = false

    private var signedInUserID: UUID? {
        if case let .signedIn(session) = authState.status {
            session.user.id
        } else {
            nil
        }
    }

    var body: some View {
        NavigationStack {
            Screen {
                content
            }
            .navigationTitle("Lists")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(signedInUserID == nil)
                    .accessibilityLabel("New list")
                }
            }
        }
        .sheet(isPresented: $showingCreate) {
            if let viewModel {
                CreateListSheet(viewModel: viewModel)
            }
        }
        .task { await ensureLoaded() }
    }

    @ViewBuilder private var content: some View {
        if let viewModel {
            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Loading your lists…")
            case let .loaded(lists):
                if lists.isEmpty {
                    EmptyStateView(
                        systemImage: "list.bullet.rectangle",
                        title: "No lists yet",
                        message: "Group things however you like — a year, a mood, a recommendation you keep repeating."
                    )
                } else {
                    loadedView(lists, viewModel: viewModel)
                }
            case let .error(reason):
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load your lists") {
                    Task { await viewModel.load() }
                }
            }
        } else {
            DeferredLoadingView()
        }
    }

    private func loadedView(_ lists: [UserList], viewModel: ListsViewModel) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                ForEach(lists) { list in
                    if let viewerID = signedInUserID {
                        NavigationLink {
                            ListDetailView(
                                list: list,
                                viewerID: viewerID,
                                service: ListService(client: clientProvider.client)
                            )
                        } label: {
                            row(list)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(Theme.Spacing.lg)
        }
        .refreshable { await viewModel.load() }
    }

    private func row(_ list: UserList) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
            HStack(spacing: Theme.Spacing.sm) {
                Text(list.title)
                    .font(Theme.Font.callout.weight(.medium))
                    .foregroundStyle(Theme.Color.textPrimary)

                if !list.isPublic {
                    Text("Private")
                        .font(Theme.Font.caption)
                        .foregroundStyle(Theme.Color.textSecondary)
                }
            }

            if let description = list.description, !description.isEmpty {
                Text(description)
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.Color.textSecondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func ensureLoaded() async {
        guard viewModel == nil, let ownerID = signedInUserID else { return }
        let model = ListsViewModel(
            ownerID: ownerID,
            service: ListService(client: clientProvider.client)
        )
        viewModel = model
        await model.load()
    }
}

/// Create-a-list sheet. Bounds mirror `lists_title_length` and
/// `lists_description_length`.
private struct CreateListSheet: View {
    let viewModel: ListsViewModel

    @Environment(\.dismiss)
    private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var isPublic = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("List name", text: $title)
                    TextField("What's this list about? (optional)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section {
                    // Per-list, deliberately independent of the account
                    // privacy flag — a public account may still want a
                    // private list.
                    Toggle("Anyone can see this list", isOn: $isPublic)
                } footer: {
                    if let message = viewModel.errorMessage {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            let id = await viewModel.create(
                                title: title,
                                description: description,
                                isPublic: isPublic
                            )
                            if id != nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(
                        viewModel.creating
                            || title.trimmingCharacters(in: .whitespaces).isEmpty
                    )
                }
            }
        }
    }
}
