import Foundation

/// The language someone reads in.
///
/// Drives what the catalog is asked for — a French reader searching "the
/// stranger" should find L'étranger's French edition, not whatever language
/// the work was written in.
///
/// It deliberately does not localise stored `media` rows. That table is one
/// shared row per item, referenced by everyone's posts, so a title there
/// belongs to every reader at once and cannot be two languages at the same
/// time. This changes what each person *finds*, not what everyone *sees*.
///
/// The list is short on purpose: each case is a promise that search actually
/// behaves differently, and offering a language the providers cannot serve is
/// worse than not offering it. TMDB localises properly, Open Library only
/// through editions, MusicBrainz not at all.
///
/// Mirrors web/lib/language.ts.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case en, fr, es, de, it, pt, ja

    var id: String {
        rawValue
    }

    /// Shown in its own language, never translated into yours.
    var label: String {
        switch self {
        case .en: "English"
        case .fr: "Français"
        case .es: "Español"
        case .de: "Deutsch"
        case .it: "Italiano"
        case .pt: "Português"
        case .ja: "日本語"
        }
    }

    /// The region-qualified tag TMDB wants.
    var tmdbLanguage: String {
        switch self {
        case .en: "en-US"
        case .fr: "fr-FR"
        case .es: "es-ES"
        case .de: "de-DE"
        case .it: "it-IT"
        case .pt: "pt-PT"
        case .ja: "ja-JP"
        }
    }

    /// Narrow anything to a supported language.
    ///
    /// Used for both the stored column and the device locale, so "fr-CA",
    /// "FR" and "fr" all land on French, and anything unsupported falls back
    /// rather than failing — a bad value in one column should not stop
    /// someone using the app.
    static func from(_ value: String?) -> AppLanguage {
        guard let value, !value.isEmpty else { return .en }
        let lowered = value.lowercased()
        let primary = lowered
            .split { $0 == "-" || $0 == "_" }
            .first
            .map(String.init) ?? lowered
        return AppLanguage(rawValue: primary) ?? .en
    }

    /// What the device is set to, for the first-run default. Someone whose
    /// phone is in French should not have to go and say so.
    static var deviceDefault: AppLanguage {
        from(Locale.current.language.languageCode?.identifier)
    }
}
