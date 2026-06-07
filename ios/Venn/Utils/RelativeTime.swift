import Foundation

/// Short, compact relative-time labels for feed timestamps — "now", "5m",
/// "2h", "3d", "2w". Deliberately terse (no "ago") to sit quietly in a
/// dense row. Items older than a week fall back to weeks; callers wanting a
/// calendar date for very old items can format separately.
enum RelativeTime {
    private static let minute: TimeInterval = 60
    private static let hour: TimeInterval = 60 * 60
    private static let day: TimeInterval = 60 * 60 * 24
    private static let week: TimeInterval = 60 * 60 * 24 * 7

    /// `now` is injectable so the formatting is deterministic in tests.
    static func short(from date: Date, now: Date = Date()) -> String {
        let elapsed = max(0, now.timeIntervalSince(date))
        switch elapsed {
        case ..<minute: return "now"
        case ..<hour: return "\(Int(elapsed / minute))m"
        case ..<day: return "\(Int(elapsed / hour))h"
        case ..<week: return "\(Int(elapsed / day))d"
        default: return "\(Int(elapsed / week))w"
        }
    }
}
