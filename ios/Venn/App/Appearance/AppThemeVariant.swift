import SwiftUI
import UIKit

/// Resolved visual variant after combining the user's preference with the
/// system color scheme.
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

    var loadingVideo: VennVideoResource {
        switch self {
        case .light:
            .init(name: "venn-loading-light")
        case .dark:
            .init(name: "venn-loading-dark")
        }
    }

    var backgroundColor: Color {
        switch self {
        case .light: .white
        case .dark: .black
        }
    }

    var uiBackgroundColor: UIColor {
        switch self {
        case .light: .white
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
