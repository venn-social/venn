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
    /// Optimistic: the row moves immediately and a failed write reloads to
    /// put it back. Waiting for a round trip before showing the new order
    /// would make ordering a list feel broken.
    func move(mediaID: UUID, direction: ListOrder.Direction) async {
        guard case let .loaded(items) = state else { return }

        let ordered = ListOrder.moved(items, mediaID: mediaID, direction: direction)
        guard ordered != items.map(\.media.id) else { return }

        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.media.id, $0) })
        state = .loaded(ordered.compactMap { byID[$0] })

        do {
            try await service.reorder(listID: listID, mediaIDs: ordered)
        } catch {
            await load()
        }
    }

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
