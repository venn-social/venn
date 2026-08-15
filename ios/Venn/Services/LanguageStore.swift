import Foundation
import Observation

/// The signed-in person's search language, held where every feature can read
/// it.
///
/// `TMDBService` is constructed in three different views, and the language
/// has to reach all of them. Threading it through each call site would mean
/// every future caller remembering to pass it, and the one that forgets
/// silently searches in English — a bug nobody would notice for months.
/// Cross-feature state like this is what CLAUDE.md's `.environment(...)`
/// rule is for.
///
/// Starts on the device's language so search is already right before the
/// profile has loaded, then follows the stored preference once it arrives.
@MainActor
@Observable
final class LanguageStore {
    private(set) var current: AppLanguage

    init(current: AppLanguage = AppLanguage.deviceDefault) {
        self.current = current
    }

    /// Called when the profile loads and whenever the picker changes, so the
    /// next search uses the new language without waiting for a relaunch.
    func set(_ language: AppLanguage) {
        current = language
    }
}
