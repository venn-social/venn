import Foundation
import Testing
@testable import Venn

/// Mirrors web/lib/__tests__/language.test.ts case for case. The two have to
/// agree, or the same person gets different search results per platform.
struct AppLanguageParsingTests {
    @Test
    func acceptsABareCode() {
        #expect(AppLanguage.from("fr") == .fr)
    }

    @Test
    func takesThePrimarySubtagFromARegionalTag() {
        // A Québécois phone reports fr-CA; that is still French.
        #expect(AppLanguage.from("fr-CA") == .fr)
        #expect(AppLanguage.from("pt_BR") == .pt)
    }

    @Test
    func isCaseInsensitive() {
        #expect(AppLanguage.from("FR") == .fr)
        #expect(AppLanguage.from("Ja-JP") == .ja)
    }

    @Test
    func fallsBackRatherThanFailingOnAnUnsupportedLanguage() {
        // A bad value in one column must not stop someone using the app.
        #expect(AppLanguage.from("cy") == .en)
        #expect(AppLanguage.from("nonsense") == .en)
    }

    @Test
    func fallsBackOnNilAndEmpty() {
        #expect(AppLanguage.from(nil) == .en)
        #expect(AppLanguage.from("") == .en)
    }
}

struct AppLanguageTMDBTests {
    @Test
    func returnsTheRegionQualifiedTagTMDBExpects() {
        #expect(AppLanguage.fr.tmdbLanguage == "fr-FR")
        #expect(AppLanguage.en.tmdbLanguage == "en-US")
    }

    @Test
    func givesEverySupportedLanguageATag() {
        for language in AppLanguage.allCases {
            let parts = language.tmdbLanguage.split(separator: "-")
            #expect(parts.count == 2)
            #expect(parts[0].count == 2)
            #expect(parts[1].count == 2)
        }
    }
}

struct AppLanguageLabelTests {
    @Test
    func namesEachLanguageInItsOwnLanguageNotInYours() {
        // "Deutsch", not "German" — a picker you can read only if you already
        // speak English is not much of a language picker.
        #expect(AppLanguage.de.label == "Deutsch")
        #expect(AppLanguage.ja.label == "日本語")
    }

    @Test
    func theSupportedSetMatchesTheCheckConstraint() {
        // Adding one here without the migration would let the app offer a
        // value the database refuses.
        #expect(AppLanguage.allCases.map(\.rawValue) == ["en", "fr", "es", "de", "it", "pt", "ja"])
    }
}
