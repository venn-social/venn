import SwiftUI

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
        /// Brand accent. Backed by `AccentColor` in `Assets.xcassets`, which
        /// is also the color SwiftUI uses by default for `Button`,
        /// `ProgressView`, etc.
        static let accent = SwiftUI.Color.accentColor

        /// Default screen background.
        static let background = SwiftUI.Color(.systemBackground)

        /// Background for surfaces sitting on top of `background` — cards,
        /// sheets, grouped sections.
        static let surface = SwiftUI.Color(.secondarySystemBackground)

        /// Primary text color.
        static let textPrimary = SwiftUI.Color(.label)

        /// Less-prominent text — captions, metadata, helper copy.
        static let textSecondary = SwiftUI.Color(.secondaryLabel)

        /// 1pt separator hairline.
        static let separator = SwiftUI.Color(.separator)
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
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
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
