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

        /// Builds an adaptive color from packed 0xRRGGBB values per mode.
        private static func hex(light: UInt, dark: UInt) -> SwiftUI.Color {
            adaptive(light: rgb(light), dark: rgb(dark))
        }

        private static func rgb(_ value: UInt) -> UIColor {
            UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        }

        static let ink = SwiftUI.Color.primary
        static let graphite = adaptive(
            light: UIColor(red: 0.11, green: 0.11, blue: 0.11, alpha: 1),
            dark: UIColor(red: 0.96, green: 0.96, blue: 0.94, alpha: 1)
        )
        static let paper = SwiftUI.Color(.systemBackground)
        static let mist = SwiftUI.Color(.secondarySystemBackground)
        static let ash = SwiftUI.Color(.tertiarySystemBackground)
        static let onAccent = adaptive(light: .white, dark: .black)

        /// Reduce-Transparency fallback solid for the glass-sky background.
        /// Approximates the gradient mid-tone so reduced-transparency users
        /// see a coherent surface instead of stark white/black.
        static let skySolid = adaptive(
            light: UIColor(red: 0.90, green: 0.93, blue: 0.97, alpha: 1),
            dark: UIColor(red: 0.06, green: 0.08, blue: 0.19, alpha: 1)
        )

        // MARK: - Glass-sky gradient stops (private; consumed by Theme.Gradient.sky)

        fileprivate static let skyTop = adaptive(
            light: UIColor(red: 0.94, green: 0.96, blue: 1.00, alpha: 1),
            dark: UIColor(red: 0.04, green: 0.05, blue: 0.12, alpha: 1)
        )
        fileprivate static let skyMid = adaptive(
            light: UIColor(red: 0.86, green: 0.91, blue: 0.97, alpha: 1),
            dark: UIColor(red: 0.11, green: 0.23, blue: 0.50, alpha: 1)
        )
        fileprivate static let skyBottom = adaptive(
            light: UIColor(red: 0.77, green: 0.82, blue: 0.89, alpha: 1),
            dark: UIColor(red: 0.02, green: 0.04, blue: 0.10, alpha: 1)
        )

        /// Brand accent — the single deliberate spot of color in an
        /// otherwise monochrome UI. Used for primary actions, selection
        /// state, and the center of the Venn overlap motif. Everything else
        /// (surfaces, text, secondary actions) stays grayscale so this reads
        /// clearly wherever it appears.
        static let accent = hex(light: 0x0070F3, dark: 0x4DA3FF)

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

        /// Glyph color for a media cover placeholder's initial.
        static let coverGlyph = hex(light: 0x474C57, dark: 0xB6BAC4)

        /// Tonal background for a media cover placeholder, keyed to kind.
        static let coverMovie = hex(light: 0xE3E9F2, dark: 0x1E232C)
        static let coverShow = hex(light: 0xF2EAE0, dark: 0x2A2520)
        static let coverBook = hex(light: 0xE2EDE5, dark: 0x1C2420)
        static let coverAlbum = hex(light: 0xEDE6F2, dark: 0x241F2B)
    }

    enum Gradient {
        /// App-wide background for the "glass-floating-over-sky" treatment.
        /// Cool atmospheric stops (pale morning sky in light mode, deep
        /// night sky in dark) read top-to-bottom. The mid stop in dark mode
        /// lives in the same blue family as the brand accent so refractions
        /// through Liquid Glass surfaces stay on-brand.
        ///
        /// Rendered edge-to-edge by `GlassSkyBackground`. Reduce
        /// Transparency users get `Color.skySolid` instead.
        static let sky = LinearGradient(
            stops: [
                .init(color: Color.skyTop, location: 0),
                .init(color: Color.skyMid, location: 0.5),
                .init(color: Color.skyBottom, location: 1),
            ],
            startPoint: .top,
            endPoint: .bottom
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

    /// Typography — Manrope (Resources/Fonts/Manrope-Variable.ttf, registered
    /// via Info.plist's UIAppFonts), matching web's app/layout.tsx. Every
    /// entry still uses `.custom(_:size:relativeTo:)`'s `relativeTo:` so
    /// Dynamic Type keeps scaling user-set font sizes correctly — don't
    /// bypass this with `.system(size:)` or a bare `.custom(_:size:)`
    /// (no `relativeTo:`) — accessibility breaks the moment you do.
    ///
    /// Base sizes match Apple's default (unscaled) point size per text
    /// style, so swapping the family here doesn't change layout. Named
    /// instances (`Manrope-Regular`, `Manrope-SemiBold`, ...) are the
    /// font's own weight variants — call sites layering `.weight(.medium)`
    /// etc. on top of these resolve to the matching Manrope instance via
    /// the same family-trait matching system fonts use.
    enum Font {
        static let largeTitle = SwiftUI.Font.custom("Manrope-SemiBold", size: 34, relativeTo: .largeTitle)
        static let title = SwiftUI.Font.custom("Manrope-SemiBold", size: 28, relativeTo: .title)
        static let title2 = SwiftUI.Font.custom("Manrope-SemiBold", size: 22, relativeTo: .title2)
        static let title3 = SwiftUI.Font.custom("Manrope-SemiBold", size: 20, relativeTo: .title3)
        static let headline = SwiftUI.Font.custom("Manrope-SemiBold", size: 17, relativeTo: .headline)
        static let body = SwiftUI.Font.custom("Manrope-Regular", size: 17, relativeTo: .body)
        static let callout = SwiftUI.Font.custom("Manrope-Regular", size: 16, relativeTo: .callout)
        static let caption = SwiftUI.Font.custom("Manrope-Regular", size: 12, relativeTo: .caption)
        static let footnote = SwiftUI.Font.custom("Manrope-Regular", size: 13, relativeTo: .footnote)
    }
}
