import SwiftUI

/// "Also add to a list" — offered after something is logged, so the catalog
/// row already exists and this is a pure append. Mirrors web's
/// `AddToListPicker.tsx` in copy and behaviour (CLAUDE.md rule 17).
///
/// Collapsed until tapped: the lists load on first open rather than on
/// appearance, because most logging sessions never touch a list.
struct AddToListPicker: View {
    let ownerID: UUID
    /// Must already exist in `public.media` — the caller writes it first.
    let mediaID: UUID
    let service: any ListServicing

    @State private var viewModel: AddToListPickerViewModel?

    var body: some View {
        if let viewModel {
            expanded(viewModel)
        } else {
            Button("Also add to a list") {
                let model = AddToListPickerViewModel(
                    ownerID: ownerID,
                    mediaID: mediaID,
                    service: service
                )
                viewModel = model
                Task { await model.load() }
            }
            .font(Theme.Font.callout.weight(.semibold))
            .foregroundStyle(Theme.Color.accent)
        }
    }

    private func expanded(_ viewModel: AddToListPickerViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Add to a list")
                .font(Theme.Font.footnote.weight(.semibold))
                .foregroundStyle(Theme.Color.textPrimary)

            switch viewModel.state {
            case .loading:
                DeferredLoadingView(caption: "Loading your lists…")
            case let .loaded(lists):
                if lists.isEmpty {
                    Text("You don't have any lists yet.")
                        .font(Theme.Font.footnote)
                        .foregroundStyle(Theme.Color.textSecondary)
                } else {
                    ForEach(lists) { list in
                        row(list, viewModel: viewModel)
                    }
                }
            case let .error(reason):
                ErrorStateView(reason: reason, unknownTitle: "Couldn't load your lists") {
                    Task { await viewModel.load() }
                }
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(Theme.Font.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(Theme.Spacing.md)
        .background(Theme.Color.surface, in: .rect(cornerRadius: Theme.Radius.md))
    }

    private func row(_ list: UserList, viewModel: AddToListPickerViewModel) -> some View {
        let isAdded = viewModel.added.contains(list.id)
        let isWorking = viewModel.working == list.id

        return Button {
            Task { await viewModel.add(to: list) }
        } label: {
            HStack {
                Text(list.title)
                    .font(Theme.Font.callout)
                    .foregroundStyle(Theme.Color.textPrimary)
                Spacer()
                Text(status(isAdded: isAdded, isWorking: isWorking))
                    .font(Theme.Font.footnote)
                    .foregroundStyle(Theme.Color.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .disabled(isAdded || viewModel.working != nil)
    }

    private func status(isAdded: Bool, isWorking: Bool) -> LocalizedStringKey {
        if isAdded {
            "Added"
        } else if isWorking {
            "Adding…"
        } else {
            "Add"
        }
    }
}
