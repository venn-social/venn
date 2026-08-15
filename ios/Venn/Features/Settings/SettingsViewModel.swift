import Foundation
import Observation

/// Drives the account-settings sheet. Currently one field: the
/// private-account toggle (`20260626120000_private_accounts.sql`).
///
/// The toggle writes optimistically, matching `FollowViewModel.toggle()`'s
/// pattern: flips immediately, writes in the background, reverts on
/// failure. There's no separate "Save" step — this mirrors how the system
/// Settings app behaves, and it's a single boolean with no draft/dirty
/// state worth staging.
///
/// Keeps zero references to SwiftUI types so it's easy to unit-test
/// against a fake `ProfileServicing`.
@MainActor
@Observable
final class SettingsViewModel {
    enum State: Equatable {
        case idle
        case saving
        case error(ErrorReason)
    }

    /// The view layer maps these to localized copy. Cases stay here so the
    /// view-model is free of `LocalizedStringKey` and trivially testable.
    enum ErrorReason: Equatable {
        case offline
        case saveFailed
    }

    private(set) var isPrivate: Bool
    private(set) var language: AppLanguage
    private(set) var state: State = .idle

    let userID: UUID
    private let service: any ProfileServicing

    init(
        userID: UUID,
        isPrivate: Bool,
        language: AppLanguage = .en,
        service: any ProfileServicing
    ) {
        self.userID = userID
        self.isPrivate = isPrivate
        self.language = language
        self.service = service
    }

    /// Optimistic: flips immediately, writes, reverts to the prior value on
    /// failure. A no-op if `newValue` already matches the current value
    /// (e.g. a `Toggle` binding re-firing).
    /// Optimistic, like the privacy toggle: the picker moves immediately and
    /// goes back if the write fails, rather than showing a choice that was
    /// never saved.
    func setLanguage(_ newValue: AppLanguage) async {
        guard newValue != language else { return }
        let original = language
        language = newValue
        state = .saving
        do {
            try await service.updateLanguage(userID: userID, language: newValue)
            state = .idle
        } catch let error as AppError {
            language = original
            state = .error(reason(for: error))
        } catch {
            language = original
            state = .error(.saveFailed)
        }
    }

    func setPrivate(_ newValue: Bool) async {
        guard newValue != isPrivate else { return }
        let original = isPrivate
        isPrivate = newValue
        state = .saving
        do {
            try await service.updatePrivacy(userID: userID, isPrivate: newValue)
            state = .idle
        } catch let error as AppError {
            isPrivate = original
            state = .error(reason(for: error))
        } catch {
            isPrivate = original
            state = .error(.saveFailed)
        }
    }

    /// Translate a service-layer `AppError` into a UI-layer `ErrorReason`.
    /// Only network gets distinct copy — everything else collapses to
    /// `.saveFailed`, matching `ProfileEditViewModel`'s reasoning: the user
    /// can't act on the distinction between a 429 / 5xx / RLS denial.
    private func reason(for error: AppError) -> ErrorReason {
        switch error {
        case .network: .offline
        case .unauthorized, .validation, .rateLimited, .server, .unknown: .saveFailed
        }
    }
}
