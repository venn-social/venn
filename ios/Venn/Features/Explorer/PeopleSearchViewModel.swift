import Foundation
import Observation

/// Drives the Explorer "People" search: debounced query → profile results.
/// Same shape as the composer's media search (`SearchState`), so the view
/// layer pattern-matches identically. The signed-in user is filtered out of
/// results — you don't need to discover yourself.
@MainActor
@Observable
final class PeopleSearchViewModel {
    typealias State = SearchState<[UserProfile]>

    private(set) var state: State = .idle

    private let service: any PeopleSearchServicing
    private let currentUserID: UUID?
    private let limit: Int
    private let debounce: Duration
    private var searchTask: Task<Void, Never>?

    /// `debounce` is injectable so tests can pass `.zero` and stay fast.
    init(
        service: any PeopleSearchServicing,
        currentUserID: UUID?,
        limit: Int = 20,
        debounce: Duration = .milliseconds(300)
    ) {
        self.service = service
        self.currentUserID = currentUserID
        self.limit = limit
        self.debounce = debounce
    }

    /// Debounced text search. An empty or invalid query resets to `.idle`.
    func search(_ query: String) {
        searchTask?.cancel()
        guard case let .valid(normalized) = Sanitize.searchQuery(query),
              !normalized.isEmpty
        else {
            state = .idle
            return
        }
        state = .searching
        let delay = debounce
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            await performSearch(query: normalized)
        }
    }

    /// Cancels any in-flight search and resets to `.idle`.
    func clear() {
        searchTask?.cancel()
        state = .idle
    }

    private func performSearch(query: String) async {
        do {
            let profiles = try await service.searchProfiles(matching: query, limit: limit)
            guard !Task.isCancelled else { return }
            state = .results(profiles.filter { $0.id != currentUserID })
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }
}
