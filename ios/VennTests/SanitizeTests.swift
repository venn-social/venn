import Testing
@testable import Venn

struct SanitizeTests {
    // MARK: - normalise

    @Test func normaliseTrimsEdges() {
        #expect(Sanitize.normalise("   hello   ") == "hello")
    }

    @Test func normaliseCollapsesInternalWhitespace() {
        #expect(Sanitize.normalise("a   b\t\tc") == "a b c")
    }

    @Test func normaliseStripsZeroWidthChars() {
        let input = "cha\u{200B}rles"
        #expect(Sanitize.normalise(input) == "charles")
    }

    @Test func normaliseStripsBidiOverride() {
        let input = "safe\u{202E}txt.exe"
        #expect(Sanitize.normalise(input) == "safetxt.exe")
    }

    @Test func normaliseStripsControlChars() {
        let input = "hello\u{0001}\u{0007}world"
        #expect(Sanitize.normalise(input) == "helloworld")
    }

    @Test func normalisePreservesNewlines() {
        #expect(Sanitize.normalise("line one\nline two") == "line one\nline two")
    }

    @Test func normaliseCapsConsecutiveBlankLines() {
        #expect(Sanitize.normalise("a\n\n\n\n\nb") == "a\n\nb")
    }

    @Test func normaliseIsIdempotent() {
        let input = "  multi   space\u{200B} mixed  "
        let once = Sanitize.normalise(input)
        let twice = Sanitize.normalise(once)
        #expect(once == twice)
    }

    // MARK: - handle

    @Test func handleAcceptsMinLength() {
        #expect(Sanitize.handle("ada") == .valid("ada"))
    }

    @Test func handleLowercasesMixedCase() {
        #expect(Sanitize.handle("Charles") == .valid("charles"))
    }

    @Test func handleAcceptsUnderscoresAndHyphens() {
        #expect(Sanitize.handle("venn_99") == .valid("venn_99"))
        #expect(Sanitize.handle("venn-99") == .valid("venn-99"))
    }

    @Test func handleRejectsTooShort() {
        #expect(Sanitize.handle("ab") == .invalid(.tooShort))
    }

    @Test func handleRejectsTooLong() {
        let twentyFive = String(repeating: "a", count: 25)
        #expect(Sanitize.handle(twentyFive) == .invalid(.tooLong))
    }

    @Test func handleRejectsSpaces() {
        #expect(Sanitize.handle("char les") == .invalid(.invalidCharacters))
    }

    @Test func handleRejectsDots() {
        #expect(Sanitize.handle("char.les") == .invalid(.invalidCharacters))
    }

    @Test func handleRejectsAtSymbol() {
        #expect(Sanitize.handle("char@les") == .invalid(.invalidCharacters))
    }

    // MARK: - displayName

    @Test func displayNameAcceptsNormal() {
        #expect(Sanitize.displayName("Charles Salomon") == .valid("Charles Salomon"))
    }

    @Test func displayNameNormalisesWhitespace() {
        #expect(Sanitize.displayName("  Charles   S  ") == .valid("Charles S"))
    }

    @Test func displayNameRejectsEmpty() {
        #expect(Sanitize.displayName("") == .invalid(.empty))
        #expect(Sanitize.displayName("   ") == .invalid(.empty))
    }

    @Test func displayNameRejectsTooLong() {
        let fortyOne = String(repeating: "a", count: 41)
        #expect(Sanitize.displayName(fortyOne) == .invalid(.tooLong))
    }

    // MARK: - bio

    @Test func bioAcceptsEmpty() {
        #expect(Sanitize.bio("") == .valid(""))
    }

    @Test func bioRejectsTooLong() {
        let oneSixtyOne = String(repeating: "a", count: 161)
        #expect(Sanitize.bio(oneSixtyOne) == .invalid(.tooLong))
    }

    // MARK: - caption

    @Test func captionAcceptsNormal() {
        #expect(Sanitize.caption("Just watched Oppenheimer.") == .valid("Just watched Oppenheimer."))
    }

    @Test func captionRejectsEmpty() {
        #expect(Sanitize.caption("") == .invalid(.empty))
    }

    @Test func captionRejectsWhitespaceOnly() {
        #expect(Sanitize.caption("   ") == .invalid(.empty))
    }

    @Test func captionRejectsTooLong() {
        let fiveOhOne = String(repeating: "a", count: 501)
        #expect(Sanitize.caption(fiveOhOne) == .invalid(.tooLong))
    }

    // MARK: - searchQuery

    @Test func searchQueryStripsSpoofingChars() {
        #expect(Sanitize.searchQuery("inception\u{200B}") == .valid("inception"))
    }

    @Test func searchQueryRejectsTooLong() {
        let oneOhOne = String(repeating: "a", count: 101)
        #expect(Sanitize.searchQuery(oneOhOne) == .invalid(.tooLong))
    }

    // MARK: - httpsURL

    @Test func httpsURLAccepts() {
        #expect(Sanitize.httpsURL("https://example.com") == .valid("https://example.com"))
    }

    @Test func httpsURLRejectsHTTP() {
        #expect(Sanitize.httpsURL("http://example.com") == .invalid(.invalidFormat))
    }

    @Test func httpsURLRejectsGarbage() {
        #expect(Sanitize.httpsURL("not a url") == .invalid(.invalidFormat))
    }

    @Test func httpsURLRejectsEmpty() {
        #expect(Sanitize.httpsURL("") == .invalid(.empty))
    }
}
