import SwiftUI
import UIKit

/// Design tokens for venn — the single source of truth for color, spacing,
/// corner radius, and typography. Every screen and component reads from
/// here rather than hardcoding literals.
///
/// `CLAUDE.md` rule 5 forbids inline `Color(red:…)`, raw padding numbers, or
/// `.font(.system(size:))` in production code. If a value isn't in `Theme`,
/// add it here first, then use it.
///
/// The numbers below are deliberately conservative placeholders — chosen so
/// the app looks reasonable today while design is still being formalised.
/// When the brand lands, tune the values once, in this file, and every
/// screen updates.
enum Theme {
    /// Brand and surface colors. Resolves through the asset catalog or the
    /// system semantic colors so light/dark mode adapt automatically.
    enum Color {
        private static func adaptive(light: UIColor, dark: UIColor) -> SwiftUI.Color {
            SwiftUI.Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            })
        }

        static let ink = SwiftUI.Color.primary
        static let graphite = adaptive(
            light: UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1),
            dark: UIColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1)
        )
        static let paper = SwiftUI.Color(.systemBackground)
        static let mist = SwiftUI.Color(.secondarySystemBackground)
        static let ash = SwiftUI.Color(.tertiarySystemBackground)
        static let violet = graphite
        static let coral = adaptive(
            light: UIColor(red: 0.29, green: 0.29, blue: 0.31, alpha: 1),
            dark: UIColor(red: 0.74, green: 0.74, blue: 0.72, alpha: 1)
        )
        static let citron = adaptive(
            light: UIColor(red: 0.91, green: 0.91, blue: 0.88, alpha: 1),
            dark: UIColor(red: 0.16, green: 0.16, blue: 0.15, alpha: 1)
        )
        static let aqua = adaptive(
            light: UIColor(red: 0.40, green: 0.41, blue: 0.43, alpha: 1),
            dark: UIColor(red: 0.64, green: 0.65, blue: 0.67, alpha: 1)
        )
        static let onAccent = adaptive(light: .white, dark: .black)

        /// Brand accent. Used for primary actions and the center of the Venn
        /// overlap motif.
        static let accent = violet

        /// Default screen background.
        static let background = paper

        /// Background for surfaces sitting on top of `background` — cards,
        /// sheets, grouped sections.
        static let surface = mist
        static let surfaceStrong = ash

        /// Primary text color.
        static let textPrimary = ink

        /// Less-prominent text — captions, metadata, helper copy.
        static let textSecondary = SwiftUI.Color.secondary

        /// 1pt separator hairline.
        static let separator = SwiftUI.Color(.separator).opacity(0.7)
    }

    enum Gradient {
        static let wash = LinearGradient(
            colors: [
                Color.paper,
                Color.paper,
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        static let overlap = LinearGradient(
            colors: [Color.graphite, Color.graphite],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// 4-pt spacing scale. Padding, gaps, and stack `spacing:` should pick
    /// from here rather than passing raw numbers.
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let xxxl: CGFloat = 48
    }

    /// Corner radius scale. `pill` is intentionally absurd so rounded-rect
    /// shapes resolve to true pills.
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let pill: CGFloat = 999
    }

    /// Typography. All entries lean on SwiftUI's text styles so Dynamic Type
    /// scales user-set font sizes correctly. Don't bypass this with
    /// `.system(size:)` — accessibility breaks the moment you do.
    enum Font {
        static let largeTitle = SwiftUI.Font.largeTitle.weight(.semibold)
        static let title = SwiftUI.Font.title.weight(.semibold)
        static let title2 = SwiftUI.Font.title2.weight(.semibold)
        static let title3 = SwiftUI.Font.title3.weight(.semibold)
        static let headline = SwiftUI.Font.headline
        static let body = SwiftUI.Font.body
        static let callout = SwiftUI.Font.callout
        static let caption = SwiftUI.Font.caption
        static let footnote = SwiftUI.Font.footnote
    }
}
