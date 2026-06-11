import Foundation
import Observation

/// Loads the taste overlap between the signed-in viewer and the profile
/// being viewed. Standard `LoadState` machine; rendered by the overlap
/// section on `PublicProfileView`.
@MainActor
@Observable
final class OverlapViewModel {
    typealias State = LoadState<OverlapSummary>

    private(set) var state: State = .loading

    let otherUserID: UUID
    private let service: any OverlapServicing

    init(otherUserID: UUID, service: any OverlapServicing) {
        self.otherUserID = otherUserID
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            let summary = try await service.overlap(with: otherUserID)
            state = .loaded(summary)
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }
}
