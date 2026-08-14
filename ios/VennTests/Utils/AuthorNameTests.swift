import Foundation
import Testing
@testable import Venn

/// Mirrors web/lib/catalog/__tests__/authorName.test.ts case for case. The
/// two must agree, or the same book credits a different name per platform.
struct AuthorNameScriptTests {
    @Test
    func acceptsPlainEnglish() {
        #expect(AuthorName.isLatinScript("Albert Camus"))
    }

    @Test
    func acceptsDiacriticsBecauseTheTestIsScriptNotASCII() {
        // Süskind and Céline are Latin. Stripping them would be a regression
        // dressed up as a fix.
        #expect(AuthorName.isLatinScript("Patrick Süskind"))
        #expect(AuthorName.isLatinScript("Louis-Ferdinand Céline"))
        #expect(AuthorName.isLatinScript("Þórbergur Þórðarson"))
    }

    @Test
    func rejectsOtherScripts() {
        #expect(!AuthorName.isLatinScript("村上春樹"))
        #expect(!AuthorName.isLatinScript("Харуки Мураками"))
        #expect(!AuthorName.isLatinScript("هاروكي موراكامي"))
        #expect(!AuthorName.isLatinScript("Νίκος Καζαντζάκης"))
    }

    @Test
    func ignoresPunctuationDigitsAndSpaces() {
        #expect(AuthorName.isLatinScript("J. R. R. Tolkien (1892-1973)"))
    }

    @Test
    func rejectsAMixedNameSinceHalfOfItIsStillUnreadable() {
        #expect(!AuthorName.isLatinScript("Haruki 村上"))
    }
}

struct AuthorNameFlipTests {
    @Test
    func flipsTheSingleCommaForm() {
        #expect(AuthorName.flippingSurnameFirst("Murakami, Haruki") == "Haruki Murakami")
    }

    @Test
    func leavesANameWithNoCommaAlone() {
        #expect(AuthorName.flippingSurnameFirst("Haruki Murakami") == "Haruki Murakami")
    }

    @Test
    func leavesMultiCommaShapesAloneRatherThanReorderingThemWrongly() {
        // "Jr., John Smith" would be worse than leaving it be.
        #expect(AuthorName.flippingSurnameFirst("Smith, John, Jr.") == "Smith, John, Jr.")
    }

    @Test
    func leavesADanglingCommaAlone() {
        #expect(AuthorName.flippingSurnameFirst("Murakami,") == "Murakami,")
        #expect(AuthorName.flippingSurnameFirst(", Haruki") == ", Haruki")
    }
}

struct AuthorNamePreferenceTests {
    @Test
    func swapsANonLatinNameForTheLatinOne() {
        #expect(
            AuthorName.preferred(name: "村上春樹", personalName: "Murakami, Haruki")
                == "Haruki Murakami"
        )
    }

    @Test
    func keepsALatinNameEvenWhenAPersonalNameExists() {
        // personal_name is usually a worse, surname-first duplicate.
        #expect(
            AuthorName.preferred(name: "Albert Camus", personalName: "Camus, Albert")
                == "Albert Camus"
        )
    }

    @Test
    func keepsDiacriticsRatherThanReachingForAnAlternative() {
        #expect(
            AuthorName.preferred(name: "Patrick Süskind", personalName: "Suskind, Patrick")
                == "Patrick Süskind"
        )
    }

    @Test
    func keepsTheOriginalWhenThereIsNoLatinAlternative() {
        // A name in the wrong script beats no name at all.
        #expect(AuthorName.preferred(name: "村上春樹", personalName: nil) == "村上春樹")
        #expect(
            AuthorName.preferred(name: "村上春樹", personalName: "ムラカミ, ハルキ") == "村上春樹"
        )
    }

    @Test
    func fallsBackToPersonalNameWhenThereIsNoName() {
        #expect(
            AuthorName.preferred(name: nil, personalName: "Murakami, Haruki") == "Haruki Murakami"
        )
    }

    @Test
    func returnsNilWhenTheRecordHasNeither() {
        #expect(AuthorName.preferred(name: nil, personalName: nil) == nil)
        #expect(AuthorName.preferred(name: "", personalName: "") == nil)
    }
}
