import Foundation
import Testing
@testable import Venn

/// Tests for the PostgREST pattern builder. No network — the query plumbing
/// is exercised through the fake in `PeopleSearchViewModelTests`.
struct PeopleSearchServiceTests {
    @Test
    func patternWrapsTermInWildcards() {
        #expect(PeopleSearchService.containsPattern(from: "ada") == "*ada*")
    }

    @Test
    func patternKeepsHandleAlphabet() {
        #expect(PeopleSearchService.containsPattern(from: "ada_lovelace-99") == "*ada_lovelace-99*")
    }

    @Test
    func patternKeepsAccentedLetters() {
        #expect(PeopleSearchService.containsPattern(from: "josé") == "*josé*")
    }

    @Test
    func patternStripsPostgRESTSyntaxCharacters() {
        // Commas, dots, parens, and quotes are PostgREST filter syntax;
        // % and * are multi-char wildcards. None may survive. Underscore
        // stays — it's part of the handle alphabet, and as a single-char
        // wildcard it still matches itself (benign over-match at worst).
        #expect(PeopleSearchService.containsPattern(from: #"a,b.c(d)e"f%g_h*i"#) == "*abcdefg_hi*")
    }

    @Test
    func patternCollapsesWhitespace() {
        #expect(PeopleSearchService.containsPattern(from: "  ada   lovelace  ") == "*ada lovelace*")
    }

    @Test
    func patternEmptyWhenNothingSearchableRemains() {
        #expect(PeopleSearchService.containsPattern(from: "(*,%)").isEmpty)
        #expect(PeopleSearchService.containsPattern(from: "   ").isEmpty)
        #expect(PeopleSearchService.containsPattern(from: "").isEmpty)
    }
}
