import Foundation
import Observation

/// Drives `ListsView` — the signed-in user's own lists.
///
/// Uses the shared `LoadState` machine rather than a per-feature enum
/// (docs/ARCHITECTURE.md, "The standard load pattern").
@MainActor
@Observable
final class ListsViewModel {
    private(set) var state: LoadState<[UserList]> = .loading
    private(set) var creating = false
    /// Set when a write fails; the view renders it inline.
    private(set) var errorMessage: String?

    private let ownerID: UUID
    private let service: any ListServicing

    init(ownerID: UUID, service: any ListServicing) {
        self.ownerID = ownerID
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

    /// Returns the new list's id so the caller can navigate straight to it.
    @discardableResult
    func create(title: String, description: String, isPublic: Bool) async -> UUID? {
        let trimmedTitle = Sanitize.normalise(title)
        guard !trimmedTitle.isEmpty else {
            errorMessage = "Give the list a name."
            return nil
        }
        guard trimmedTitle.count <= 60 else {
            errorMessage = "Names max out at 60 characters."
            return nil
        }

        let trimmedDescription = Sanitize.normalise(description)
        guard trimmedDescription.count <= 500 else {
            errorMessage = "Descriptions max out at 500 characters."
            return nil
        }

        creating = true
        errorMessage = nil
        defer { creating = false }

        do {
            let id = try await service.createList(
                ownerID: ownerID,
                title: trimmedTitle,
                description: trimmedDescription.isEmpty ? nil : trimmedDescription,
                isPublic: isPublic
            )
            await load()
            return id
        } catch let error as AppError {
            if case .rateLimited = error {
                errorMessage = "You're creating lists very fast — give it a moment."
            } else {
                errorMessage = "Couldn't create that list. Please try again."
            }
            return nil
        } catch {
            errorMessage = "Couldn't create that list. Please try again."
            return nil
        }
    }

    /// Optimistic: the row disappears immediately, and a failed delete puts
    /// it back by reloading — the same shape `FollowRequestsViewModel` uses.
    func delete(_ listID: UUID) async {
        guard case let .loaded(lists) = state else { return }
        state = .loaded(lists.filter { $0.id != listID })

        do {
            try await service.deleteList(id: listID)
        } catch {
            await load()
        }
    }
}
