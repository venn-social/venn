import SwiftUI

/// User-facing appearance preference. `system` follows iOS; the other cases
/// force Venn into a specific color scheme.
enum AppThemeMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "venn.appearance.themeMode"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    func resolvedVariant(systemColorScheme: ColorScheme) -> AppThemeVariant {
        switch self {
        case .system:
            systemColorScheme == .dark ? .dark : .light
        case .light:
            .light
        case .dark:
            .dark
        }
    }
}
