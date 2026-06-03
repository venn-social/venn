#if DEBUG
    import SwiftUI

    /// Design tokens for the in-development visual style preview.
    ///
    /// DEBUG-only and self-contained. These values are candidates for venn's
    /// refreshed visual language — modern, image-forward, monochrome with a
    /// single accent, clean surfaces over the app's glass-sky background. They
    /// graduate into the production theme once the language is finalized.
    enum StyleToken {
        static let accent = color(0x0070F3)

        static func ink(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? color(0xF4F4F6) : color(0x0B0B0F)
        }

        static func inkSecondary(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? color(0x9A9DA6) : color(0x73767E)
        }

        static func inkTertiary(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? color(0x6A6D75) : color(0xA8AAB2)
        }

        static func hairline(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? color(0x2A2B30) : color(0xE9E9EC)
        }

        /// Tonal background for a cover placeholder, keyed to media kind.
        static func coverTint(for kind: MediaKind, _ scheme: ColorScheme) -> Color {
            switch (kind, scheme == .dark) {
            case (.movie, false): color(0xE3E9F2)
            case (.movie, true): color(0x1E232C)
            case (.show, false): color(0xF2EAE0)
            case (.show, true): color(0x2A2520)
            case (.book, false): color(0xE2EDE5)
            case (.book, true): color(0x1C2420)
            case (.album, false): color(0xEDE6F2)
            case (.album, true): color(0x241F2B)
            }
        }

        /// Glyph color for the initial shown on a cover placeholder.
        static func coverGlyph(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? color(0xB6BAC4) : color(0x474C57)
        }

        static func color(_ hex: UInt) -> Color {
            Color(
                red: Double((hex >> 16) & 0xFF) / 255,
                green: Double((hex >> 8) & 0xFF) / 255,
                blue: Double(hex & 0xFF) / 255
            )
        }
    }
#endif
