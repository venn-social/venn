import Foundation
import Testing
@testable import Venn

struct RelativeTimeTests {
    private let now = Date(timeIntervalSince1970: 1_000_000_000)

    private func ago(_ interval: TimeInterval) -> Date {
        now.addingTimeInterval(-interval)
    }

    @Test
    func underAMinuteIsNow() {
        #expect(RelativeTime.short(from: ago(30), now: now) == "now")
    }

    @Test
    func minutesHoursDaysWeeks() {
        #expect(RelativeTime.short(from: ago(60 * 5), now: now) == "5m")
        #expect(RelativeTime.short(from: ago(60 * 60 * 2), now: now) == "2h")
        #expect(RelativeTime.short(from: ago(60 * 60 * 24 * 3), now: now) == "3d")
        #expect(RelativeTime.short(from: ago(60 * 60 * 24 * 14), now: now) == "2w")
    }

    @Test
    func boundariesRoundDown() {
        // Exactly one hour is "1h", not "60m".
        #expect(RelativeTime.short(from: ago(60 * 60), now: now) == "1h")
        // Just under an hour is still minutes.
        #expect(RelativeTime.short(from: ago(60 * 60 - 1), now: now) == "59m")
    }

    @Test
    func futureDatesClampToNow() {
        #expect(RelativeTime.short(from: now.addingTimeInterval(500), now: now) == "now")
    }
}
