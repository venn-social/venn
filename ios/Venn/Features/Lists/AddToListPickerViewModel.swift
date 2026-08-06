import Foundation
import Observation

/// Drives `AddToListPicker`: the user's lists, and which of them this item
/// has been added to during this session.
///
/// Lists load lazily on first open rather than on mount. Most logging
/// sessions never touch a list, and fetching them every time would be a
/// query nobody asked for.
@MainActor
@Observable
final class AddToListPickerViewModel {
    typealias State = LoadState<[UserList]>

    private(set) var state: State = .loading
    /// Lists this item has landed in, so their rows can read "Added".
    private(set) var added: Set<UUID> = []
    /// The list currently being written to, for its row's spinner.
    private(set) var working: UUID?
    /// Set when a write fails; the view renders it inline.
    private(set) var errorMessage: String?

    private let ownerID: UUID
    private let mediaID: UUID
    private let service: any ListServicing

    init(ownerID: UUID, mediaID: UUID, service: any ListServicing) {
        self.ownerID = ownerID
        self.mediaID = mediaID
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            state = try await .loaded(service.lists(ownerID: ownerID))
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }

    func add(to list: UserList) async {
        guard !added.contains(list.id), working == nil else { return }

        working = list.id
        errorMessage = nil
        do {
            // Position is read fresh rather than tracked, so a second device
            // adding to the same list doesn't claim the same slot.
            let items = try await service.items(listID: list.id)
            let position = (items.map(\.position).max() ?? -1) + 1
            try await service.addItem(
                listID: list.id,
                mediaID: mediaID,
                position: position,
                note: nil
            )
            added.insert(list.id)
        } catch {
            errorMessage = "Couldn't add it to that list."
        }
        working = nil
    }
}
