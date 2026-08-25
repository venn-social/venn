import SwiftUI

/// Visual variant selected from the system color scheme, used by the launch
/// splash to pick the matching mark and background.
enum AppThemeVariant {
    case light
    case dark

    /// Pale-lavender-white (light) / pure black (dark). Matches the iOS
    /// launch screen, so handing over to the SwiftUI splash shows no seam —
    /// a pure-white background here flashed against it.
    var backgroundColor: Color {
        switch self {
        case .light: Color(red: 0.918, green: 0.933, blue: 0.961)
        case .dark: .black
        }
    }

    var markColor: Color {
        switch self {
        case .light: .black
        case .dark: .white
        }
    }
}
