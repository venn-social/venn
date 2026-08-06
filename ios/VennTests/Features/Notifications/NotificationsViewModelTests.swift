import Foundation
import Testing
@testable import Venn

/// `NotificationsViewModel` against a fake service: the state machine, the
/// badge, and the read behaviour. The mapping has its own tests.
@MainActor
struct NotificationsViewModelTests {
    @Test
    func loadsNotificationsAndCountsTheUnreadOnes() async {
        let service = FakeNotificationService(notifications: [
            Self.notification(readAt: nil),
            Self.notification(readAt: Date()),
            Self.notification(readAt: nil),
        ])
        let viewModel = NotificationsViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .loaded(service.seeded))
        #expect(viewModel.unreadCount == 2)
    }

    @Test
    func mapsAFailureToTheSharedErrorReason() async {
        let service = FakeNotificationService(notifications: [])
        service.error = AppError.network
        let viewModel = NotificationsViewModel(service: service)

        await viewModel.load()

        #expect(viewModel.state == .error(.offline))
    }

    @Test
    func refreshFailureKeepsStaleContentOnScreen() async {
        // Same rule as the feed: yanking a visible list for a transient
        // blip is worse than showing it a few seconds out of date.
        let service = FakeNotificationService(notifications: [Self.notification(readAt: nil)])
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.load()

        service.error = AppError.network
        await viewModel.refresh()

        #expect(viewModel.state == .loaded(service.seeded))
    }

    @Test
    func refreshingTheBadgeDoesNotLoadTheList() async {
        // The badge has to be right before the tab is ever opened, and
        // fetching fifty rows to render one number would be absurd.
        let service = FakeNotificationService(notifications: [])
        service.unread = 7
        let viewModel = NotificationsViewModel(service: service)

        await viewModel.refreshBadge()

        #expect(viewModel.unreadCount == 7)
        #expect(service.notificationCalls == 0)
        #expect(service.unreadCalls == 1)
    }

    @Test
    func aFailedBadgeRefreshKeepsTheLastKnownCount() async {
        // Better a slightly stale badge than one that silently drops to
        // zero and hides real activity.
        let service = FakeNotificationService(notifications: [])
        service.unread = 4
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.refreshBadge()

        service.error = AppError.network
        await viewModel.refreshBadge()

        #expect(viewModel.unreadCount == 4)
    }

    @Test
    func openingTheScreenClearsTheBadge() async {
        let service = FakeNotificationService(notifications: [Self.notification(readAt: nil)])
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.load()

        await viewModel.markAllRead()

        #expect(viewModel.unreadCount == 0)
        #expect(service.markReadCalls == 1)
    }

    @Test
    func clearingLeavesTheLoadedRowsLookingUnread() async {
        // The tint is the only signal showing what arrived since last time.
        // Re-rendering the list as all-read the instant it appears would
        // erase it before it had been read.
        let service = FakeNotificationService(notifications: [Self.notification(readAt: nil)])
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.load()

        await viewModel.markAllRead()

        #expect(viewModel.state == .loaded(service.seeded))
        if case let .loaded(rows) = viewModel.state {
            // Hoisted out of `#expect`: `allSatisfy` is `rethrows`, and the
            // macro's expansion can't tell that a key-path predicate never
            // throws.
            let allStillUnread = rows.allSatisfy(\.isUnread)
            #expect(allStillUnread)
        }
    }

    @Test
    func clearingAnEmptyBadgeIsNotACall() async {
        let service = FakeNotificationService(notifications: [Self.notification(readAt: Date())])
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.load()

        await viewModel.markAllRead()

        #expect(service.markReadCalls == 0)
    }

    @Test
    func aFailedClearPutsTheBadgeBack() async {
        // The clear is optimistic, so a failure has to be reconciled —
        // otherwise the badge lies until the next cold start.
        let service = FakeNotificationService(notifications: [Self.notification(readAt: nil)])
        let viewModel = NotificationsViewModel(service: service)
        await viewModel.load()

        service.error = AppError.network
        service.unread = 1
        await viewModel.markAllRead()

        #expect(viewModel.unreadCount == 1)
    }

    // MARK: - Fixtures

    private static func notification(readAt: Date?) -> AppNotification {
        AppNotification(
            id: UUID(),
            kind: .like,
            actor: UserProfile(
                id: UUID(),
                username: "maya",
                displayName: nil,
                avatarURL: nil,
                bio: nil,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            readAt: readAt,
            postID: UUID(),
            postTitle: "Past Lives",
            commentBody: nil
        )
    }
}

/// Counts calls so tests can assert the badge path never loads the list.
/// Set `error` to fail the next call.
final class FakeNotificationService: NotificationServicing, @unchecked Sendable {
    /// Not named `notifications`: the protocol requires a
    /// `notifications(limit:)` method, and a property sharing that base name
    /// makes every `service.notifications` resolve to the throwing function
    /// instead of the array.
    let seeded: [AppNotification]
    var unread = 0
    var error: AppError?
    private(set) var notificationCalls = 0
    private(set) var unreadCalls = 0
    private(set) var markReadCalls = 0

    init(notifications: [AppNotification]) {
        seeded = notifications
    }

    func notifications(limit _: Int) async throws -> [AppNotification] {
        notificationCalls += 1
        if let error {
            throw error
        }
        return seeded
    }

    func unreadCount() async throws -> Int {
        unreadCalls += 1
        if let error {
            throw error
        }
        return unread
    }

    @discardableResult
    func markAllRead() async throws -> Int {
        markReadCalls += 1
        if let error {
            throw error
        }
        return seeded.filter(\.isUnread).count
    }
}
