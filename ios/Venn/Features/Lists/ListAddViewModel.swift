import Foundation
import Observation

/// Drives `ListAddView`: search the catalog, then append a result to this
/// list. Mirrors web's `AddToList.tsx`.
///
/// Note the two-step write. `list_items.media_id` references
/// `public.media`, so a catalog result nobody has logged yet exists nowhere
/// in our database — it has to be upserted first. Without that, adding an
/// unlogged film to a list fails on a foreign key.
@MainActor
@Observable
final class ListAddViewModel {
    private(set) var searchState: SearchState<[MediaCandidate]> = .idle
    /// Candidates already appended this session, so their rows read "Added"
    /// instead of inviting a duplicate.
    private(set) var added: Set<String> = []
    private(set) var working: String?
    private(set) var errorMessage: String?

    var kind: MediaKind = .movie {
        didSet {
            guard kind != oldValue else { return }
            search(query)
        }
    }

    private var query = ""
    private let listID: UUID
    private let catalog: any ComposerServicing
    private let lists: any ListServicing
    private var searchTask: Task<Void, Never>?
    private let debounce: Duration

    init(
        listID: UUID,
        catalog: any ComposerServicing,
        lists: any ListServicing,
        debounce: Duration = .milliseconds(350)
    ) {
        self.listID = listID
        self.catalog = catalog
        self.lists = lists
        self.debounce = debounce
    }

    /// Debounced: every keystroke would otherwise be a request to TMDB.
    func search(_ newQuery: String) {
        query = newQuery
        searchTask?.cancel()

        let trimmed = newQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchState = .idle
            return
        }

        searchState = .searching
        searchTask = Task { [debounce, catalog, kind] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            do {
                let results = try await catalog.search(query: trimmed, kind: kind, page: 1)
                guard !Task.isCancelled else { return }
                searchState = .results(results)
            } catch let error as AppError {
                guard !Task.isCancelled else { return }
                searchState = .error(LoadErrorReason(error))
            } catch {
                guard !Task.isCancelled else { return }
                searchState = .error(.unknown)
            }
        }
    }

    func add(_ candidate: MediaCandidate) async {
        guard !added.contains(candidate.id), working == nil else { return }

        working = candidate.id
        errorMessage = nil
        do {
            let mediaID = try await catalog.upsertMedia(candidate: candidate)
            // Position is read fresh rather than tracked, so a second device
            // appending at the same time doesn't claim the same slot.
            let items = try await lists.items(listID: listID)
            let position = (items.map(\.position).max() ?? -1) + 1
            try await lists.addItem(
                listID: listID,
                mediaID: mediaID,
                position: position,
                note: nil
            )
            added.insert(candidate.id)
        } catch {
            errorMessage = "Couldn't add that. Please try again."
        }
        working = nil
    }
}
