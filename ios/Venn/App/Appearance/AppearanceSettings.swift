import Foundation
import Observation

/// Persistent appearance settings shared across the app.
@MainActor
@Observable
final class AppearanceSettings {
    var mode: AppThemeMode {
        didSet {
            store.set(mode.rawValue, forKey: AppThemeMode.storageKey)
        }
    }

    private let store: UserDefaults

    init(store: UserDefaults = .standard) {
        self.store = store
        let storedValue = store.string(forKey: AppThemeMode.storageKey)
        mode = storedValue.flatMap(AppThemeMode.init(rawValue:)) ?? .system
    }
}
