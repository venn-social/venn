import Foundation
import Observation

/// Drives `ListDetailView` — one list and its items.
@MainActor
@Observable
final class ListDetailViewModel {
    private(set) var state: LoadState<[ListItem]> = .loading

    private let listID: UUID
    private let service: any ListServicing

    init(listID: UUID, service: any ListServicing) {
        self.listID = listID
        self.service = service
    }

    /// Where an appended item goes — see `nextListPosition`.
    var nextPosition: Int {
        if case let .loaded(items) = state {
            return nextListPosition(items)
        }
        return 0
    }

    func load() async {
        state = .loading
        do {
            state = try await .loaded(service.items(listID: listID))
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }

    /// Optimistic removal; a failure reloads rather than losing the item.
    func remove(mediaID: UUID) async {
        guard case let .loaded(items) = state else { return }
        state = .loaded(items.filter { $0.media.id != mediaID })

        do {
            try await service.removeItem(listID: listID, mediaID: mediaID)
        } catch {
            await load()
        }
    }
}
