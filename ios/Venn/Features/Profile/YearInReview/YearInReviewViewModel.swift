import Foundation
import Observation

/// Drives `YearInReviewView`. Load is triggered by the view's `.task`
/// modifier — there's no mutation here, just fetch-and-render, so unlike
/// `ProfileViewModel` there's no optimistic-update surface to cover.
@MainActor
@Observable
final class YearInReviewViewModel {
    typealias State = LoadState<YearInReviewSummary>

    private(set) var state: State = .loading
    private let service: any YearInReviewServicing

    init(service: any YearInReviewServicing) {
        self.service = service
    }

    func load() async {
        state = .loading
        do {
            let summary = try await service.summary()
            state = .loaded(summary)
        } catch let error as AppError {
            state = .error(LoadErrorReason(error))
        } catch {
            state = .error(.unknown)
        }
    }
}
