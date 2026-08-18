import Foundation
import Observation

/// Drives the search → pick → detail → rate → submit flow.
///
/// Lifecycle:
///   1. User types a query  → `search(_:kind:)` debounces and sets `searchState`
///   2. User taps a result  → `pick(_:)` captures `selectedCandidate`
///   3. Detail page: user taps "Add to Watchlist" → `addToWatchlist(authorID:)`
///                   or taps "Log it" → navigates to rating screen
///   4. Rating screen: user picks Love/Like/Dislike (or skips)
///   5. User taps Finish    → `submit(authorID:)` calls the service
@MainActor
@Observable
final class ComposerViewModel {
    // MARK: - State enums

    typealias SearchState = Venn.SearchState<[MediaCandidate]>

    enum SubmitState: Equatable {
        case ready
        case submitting
        case submitted
        case error(ErrorReason)
    }

    typealias ErrorReason = LoadErrorReason

    /// The three-way sentiment rating the user can express.
    /// Nil means the user tapped Skip — the post is logged without a rating.
    enum RatingChoice: Equatable, CaseIterable {
        case love, like, dislike

        var title: String {
            switch self {
            case .love: "Love"
            case .like: "Like"
            case .dislike: "Dislike"
            }
        }

        var systemImage: String {
            switch self {
            case .love: "heart.fill"
            case .like: "hand.thumbsup.fill"
            case .dislike: "hand.thumbsdown.fill"
            }
        }

        /// The row this choice writes. Nil means Skip — logged, unrated.
        /// The single source of the mapping, so the composer and the rating
        /// editor cannot drift. Mirrors web's `ratingToPost`.
        static func postValues(for choice: RatingChoice?) -> (action: PostAction, rating: Double?) {
            switch choice {
            case .love: (.rated, 5.0)
            case .like: (.rated, 3.0)
            case .dislike: (.rated, 1.0)
            case .none: (.logged, nil)
            }
        }

        /// The choice a stored rating corresponds to, so an editor opens on
        /// what the user actually said.
        init?(rating: Double?) {
            guard let rating else { return nil }
            switch rating {
            case 5...: self = .love
            case 3...: self = .like
            default: self = .dislike
            }
        }
    }

    // MARK: - Observable state

    private(set) var searchState: SearchState = .idle
    private(set) var submitState: SubmitState = .ready

    /// Non-nil once the user taps a search result and the detail sheet opens.
    var selectedCandidate: MediaCandidate?
    /// The sentiment the user chose on the rating screen. Nil = Skip.
    var ratingChoice: RatingChoice?
    /// Optional. Validated + sanitized on submit via `Sanitize.caption`.
    var caption = ""
    /// Whether to publish the log as a visible feed post (default on).
    var postToFeed = true

    /// The catalog row the last successful submit wrote to, so the
    /// confirmation step can offer to add it to a list without looking it
    /// up again. Nil until something has been logged.
    private(set) var loggedMediaID: UUID?

    var canSubmit: Bool {
        guard selectedCandidate != nil else { return false }
        guard submitState != .submitting else { return false }
        return true
    }

    // MARK: - Private

    private let service: any ComposerServicing
    private var searchTask: Task<Void, Never>?

    init(service: any ComposerServicing) {
        self.service = service
    }

    // MARK: - Search

    /// Debounced (300 ms) text-search across one or more media kinds.
    /// Pass multiple kinds (e.g. from `.all`) to run parallel searches and merge.
    /// Empty or whitespace-only query resets to `.idle`.
    func search(_ query: String, kinds: [MediaKind]) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchState = .idle
            return
        }
        searchState = .searching
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled, let self else { return }
            await performSearch(query: trimmed, kinds: kinds)
        }
    }

    /// Cancels any in-flight search and resets to `.idle`.
    func clearSearch() {
        searchTask?.cancel()
        searchState = .idle
    }

    // MARK: - Pick

    /// Capture the user's selection and reset all action/rating/caption fields.
    func pick(_ candidate: MediaCandidate) {
        selectedCandidate = candidate
        ratingChoice = nil
        caption = ""
        postToFeed = true
        submitState = .ready
        // A stale id here would offer to add the *previous* thing to a list.
        loggedMediaID = nil
    }

    /// Put a catalog result into `public.media` and return its row id,
    /// without logging anything about it.
    ///
    /// Explorer uses this to open a recommendation's detail page: a catalog
    /// result exists nowhere in our database, so there is no detail page to
    /// push until the row exists. Idempotent on (source, external id).
    func upsertMedia(_ candidate: MediaCandidate) async throws -> UUID {
        try await service.upsertMedia(candidate: candidate)
    }

    /// Deselect — returns the UI to the search results list.
    func clearPick() {
        selectedCandidate = nil
    }

    // MARK: - Submit

    /// Sanitize the caption, map the rating choice to an action, and submit.
    /// The view listens for `.submitted` to dismiss the sheet.
    func submit(authorID: UUID) async {
        guard let candidate = selectedCandidate, canSubmit else { return }

        let sanitizedCaption: String? = {
            let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            guard case let .valid(normalized) = Sanitize.caption(trimmed) else { return nil }
            return normalized
        }()

        let (action, numericRating) = RatingChoice.postValues(for: ratingChoice)

        submitState = .submitting
        do {
            let post = try await service.log(
                candidate: candidate,
                authorID: authorID,
                action: action,
                rating: numericRating,
                caption: sanitizedCaption
            )
            loggedMediaID = post.mediaID
            submitState = .submitted
        } catch let error as AppError {
            submitState = .error(LoadErrorReason(error))
        } catch {
            submitState = .error(.unknown)
        }
    }

    /// Log the candidate as `.saved` (watchlist) without a rating or caption.
    func addToWatchlist(authorID: UUID) async {
        guard let candidate = selectedCandidate else { return }
        submitState = .submitting
        do {
            let post = try await service.log(
                candidate: candidate,
                authorID: authorID,
                action: .saved,
                rating: nil,
                caption: nil
            )
            loggedMediaID = post.mediaID
            submitState = .submitted
        } catch let error as AppError {
            submitState = .error(LoadErrorReason(error))
        } catch {
            submitState = .error(.unknown)
        }
    }

    // MARK: - Private helpers

    private func performSearch(query: String, kinds: [MediaKind]) async {
        do {
            if kinds.count == 1, let kind = kinds.first {
                let results = try await service.search(query: query, kind: kind, page: 1)
                searchState = .results(results)
            } else {
                // Run each kind's search in parallel; per-kind failures yield empty results
                // rather than aborting the whole "All" search.
                var merged: [MediaCandidate] = []
                let svc = service
                await withTaskGroup(of: [MediaCandidate].self) { group in
                    for kind in kinds {
                        group.addTask {
                            await (try? svc.search(query: query, kind: kind, page: 1)) ?? []
                        }
                    }
                    for await results in group {
                        merged.append(contentsOf: results)
                    }
                }
                searchState = .results(merged)
            }
        } catch let error as AppError {
            searchState = .error(LoadErrorReason(error))
        } catch {
            searchState = .error(.unknown)
        }
    }
}
