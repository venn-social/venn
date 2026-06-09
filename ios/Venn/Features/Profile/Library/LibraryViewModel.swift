import Foundation
import Observation

/// Which half of the library is being viewed.
enum LibraryTab: String, Hashable, CaseIterable {
    case watchlist
    case collection

    var title: String {
        switch self {
        case .watchlist: "Watchlist"
        case .collection: "Collection"
        }
    }
}

/// Drives `LibraryListView` for a single `(userID, kind, tab)` combination.
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
    let tab: LibraryTab
    private let service: any ProfileServicing

    init(userID: UUID, kind: MediaKind?, tab: LibraryTab, service: any ProfileServicing) {
        self.userID = userID
        self.kind = kind
        self.tab = tab
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            let items = switch tab {
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
