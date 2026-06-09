import Foundation
import Observation

/// Drives `LibraryListView` for a single `(userID, kind, shelf)` combination.
/// Load is triggered by the view's `.task` modifier; optimistic removal
/// reverts on failure.
@MainActor
@Observable
final class LibraryViewModel {
    enum State: Equatable {
        case loading
        case loaded([LibraryItem])
        case error(ErrorReason)
    }

    enum ErrorReason: Equatable {
        case offline
        case unknown
    }

    private(set) var state: State = .loading

    let userID: UUID
    let kind: MediaKind?
    let shelf: ProfileShelf
    private let service: any ProfileServicing

    init(userID: UUID, kind: MediaKind?, shelf: ProfileShelf, service: any ProfileServicing) {
        self.userID = userID
        self.kind = kind
        self.shelf = shelf
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            let items = switch shelf {
            case .watchlist:
                try await service.watchlist(for: userID, kind: kind)
            case .collection:
                try await service.collection(for: userID, kind: kind)
            }
            state = .loaded(items)
        } catch let error as AppError {
            state = .error(errorReason(for: error))
        } catch {
            state = .error(.unknown)
        }
    }

    func remove(item: LibraryItem) async {
        guard case var .loaded(items) = state else { return }
        items.removeAll { $0.id == item.id }
        state = .loaded(items)
        do {
            try await service.removeFromLibrary(postID: item.post.id)
        } catch {
            await load()
        }
    }

    private func errorReason(for error: AppError) -> ErrorReason {
        switch error {
        case .network: .offline
        default: .unknown
        }
    }
}
