import Foundation
import Observation

/// Drives `NotificationsView` and the tab-bar badge.
///
/// Uses the shared `LoadState` machine rather than a per-feature enum
/// (docs/ARCHITECTURE.md, "The standard load pattern").
@MainActor
@Observable
final class NotificationsViewModel {
    typealias State = LoadState<[AppNotification]>

    private(set) var state: State = .loading
    /// Drives the tab badge. Kept separate from `state` because the badge
    /// has to be right before the screen is ever opened.
    private(set) var unreadCount = 0

    private let service: any NotificationServicing
    private let pageSize: Int

    init(service: any NotificationServicing, pageSize: Int = 50) {
        self.service = service
        self.pageSize = pageSize
    }

    func load() async {
        state = .loading
        await refresh()
    }

    /// Refetches in place (pull-to-refresh). A failure with content already
    /// on screen keeps the stale list — same rule as the feed, for the same
    /// reason: yanking a visible list for a transient blip is worse.
    func refresh() async {
        do {
            let notifications = try await service.notifications(limit: pageSize)
            state = .loaded(notifications)
            unreadCount = notifications.filter(\.isUnread).count
        } catch let error as AppError {
            if case .loaded = state {
                return
            }
            state = .error(LoadErrorReason(error))
        } catch {
            if case .loaded = state {
                return
            }
            state = .error(.unknown)
        }
    }

    /// Badge only. Cheap enough to call on every appearance of the shell,
    /// which is what keeps the count honest without loading the list.
    func refreshBadge() async {
        unreadCount = await (try? service.unreadCount()) ?? unreadCount
    }

    /// Called when the screen is shown.
    ///
    /// The badge clears immediately, but the loaded rows keep their unread
    /// styling for this viewing — you have in fact just seen them, and
    /// re-rendering the list as all-read the instant it appears would erase
    /// the only signal showing what was new.
    func markAllRead() async {
        let previous = unreadCount
        guard previous > 0 else { return }

        // Optimistic: the badge is the thing people watch, and a failed
        // clear should cost a stale badge rather than a lost notification.
        unreadCount = 0
        if await (try? service.markAllRead()) == nil {
            // Put back exactly what was there. Refetching instead would
            // need the same network that just failed, and would leave the
            // badge silently at zero — hiding real activity.
            unreadCount = previous
        }
    }
}
