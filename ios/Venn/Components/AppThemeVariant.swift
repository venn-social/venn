import SwiftUI
import UIKit

/// Visual variant selected from the system color scheme, used by the launch
/// splash to pick the matching brand video and background.
enum AppThemeVariant {
    case light
    case dark

    var launchVideo: VennVideoResource {
        switch self {
        case .light:
            .init(name: "venn-launch-light")
        case .dark:
            .init(name: "venn-launch-dark")
        }
    }

    /// Pale-lavender-white (light) / pure black (dark). Matches the FIRST
    /// frame of the launch + loading videos so the iOS launch screen → SwiftUI
    /// splash background → video transition is seamless. Without this, the
    /// SwiftUI splash background (previously pure white) flashed white before
    /// the video's slightly off-white background loaded in.
    var backgroundColor: Color {
        switch self {
        case .light: Color(red: 0.918, green: 0.933, blue: 0.961)
        case .dark: .black
        }
    }

    var uiBackgroundColor: UIColor {
        switch self {
        case .light: UIColor(red: 0.918, green: 0.933, blue: 0.961, alpha: 1)
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
