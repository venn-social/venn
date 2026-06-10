import Foundation
import Testing
@testable import Venn

/// Tests for the shared external-catalog helpers. The HTTP status mapping
/// is exercised indirectly through the service suites; the pure year
/// parser is covered here once instead of per-service.
struct ExternalAPITests {
    @Test
    func yearParsesFromFullDate() {
        #expect(ExternalAPI.year(from: "2023-06-15") == 2023)
    }

    @Test
    func yearParsesFromYearMonth() {
        #expect(ExternalAPI.year(from: "2001-06") == 2001)
    }

    @Test
    func yearParsesFromYearOnly() {
        #expect(ExternalAPI.year(from: "1999") == 1999)
    }

    @Test
    func yearReturnsNilForShortString() {
        #expect(ExternalAPI.year(from: "202") == nil)
    }

    @Test
    func yearReturnsNilForNil() {
        #expect(ExternalAPI.year(from: nil) == nil)
    }
}
