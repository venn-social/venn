import Foundation
import Testing
@testable import Venn

/// Wire-row → domain mapping and the copy each kind produces. Mirrors web's
/// `lib/__tests__/notifications.test.ts` case for case (CLAUDE.md rule 17).
struct NotificationTests {
    private static let actor = UserProfile(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID(),
        username: "maya",
        displayName: "Maya Chen",
        avatarURL: nil,
        bio: nil,
        createdAt: Date(timeIntervalSince1970: 1_700_000_000)
    )

    private static func row(
        kind: String = "like",
        readAt: Date? = nil,
        postID: UUID? = UUID(uuidString: "22222222-2222-2222-2222-222222222222"),
        actor: UserProfile? = NotificationTests.actor,
        title: String? = "Past Lives",
        comment: String? = nil
    ) -> NotificationRowDTO {
        NotificationRowDTO(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID(),
            kind: kind,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            readAt: readAt,
            postId: postID,
            actor: actor,
            post: title.map { NotificationPostDTO(media: NotificationMediaDTO(title: $0)) },
            comment: comment.map { NotificationCommentDTO(body: $0) }
        )
    }

    @Test
    func mapsALikeIncludingTheTitleItWasAbout() throws {
        let notification = try #require(AppNotification(row: Self.row()))

        #expect(notification.kind == .like)
        #expect(notification.actor.username == "maya")
        #expect(notification.postTitle == "Past Lives")
        #expect(notification.isUnread)
    }

    @Test
    func keepsTheCommentBodySoTheRowCanQuoteIt() throws {
        let notification = try #require(
            AppNotification(row: Self.row(kind: "comment", comment: "Loved this one."))
        )

        #expect(notification.commentBody == "Loved this one.")
    }

    @Test
    func dropsARowWhoseActorVanished() {
        // The foreign key cascades, so this is a race between the delete and
        // the read — but "someone liked your post" is worse than nothing.
        #expect(AppNotification(row: Self.row(actor: nil)) == nil)
    }

    @Test
    func dropsAKindItDoesNotUnderstand() {
        // A future migration could add one; an old client must not render it
        // as a blank row.
        #expect(AppNotification(row: Self.row(kind: "reaction")) == nil)
    }

    @Test
    func survivesAFollowRowWithNoPostAttached() throws {
        let notification = try #require(
            AppNotification(row: Self.row(kind: "follow", postID: nil, title: nil))
        )

        #expect(notification.postID == nil)
        #expect(notification.postTitle == nil)
    }

    @Test
    func aReadNotificationIsNotUnread() throws {
        let notification = try #require(AppNotification(row: Self.row(readAt: Date())))
        #expect(!notification.isUnread)
    }

    // MARK: - Copy

    @Test
    func namesTheTitleWhenWeHaveOne() throws {
        // "liked your post" is forgettable; "liked your post about Past
        // Lives" is the thing worth opening.
        let notification = try #require(AppNotification(row: Self.row()))
        #expect(notification.summary == "liked your post about Past Lives")
    }

    @Test
    func omitsTheTitleWhenThePostHasNone() throws {
        let notification = try #require(AppNotification(row: Self.row(title: nil)))
        #expect(notification.summary == "liked your post")
    }

    @Test
    func distinguishesAFollowFromARequest() throws {
        // A pending request to a private account is not a follow yet, and
        // telling someone they have a new follower when they don't is a lie.
        let follow = try #require(
            AppNotification(row: Self.row(kind: "follow", postID: nil, title: nil))
        )
        let request = try #require(
            AppNotification(row: Self.row(kind: "follow_request", postID: nil, title: nil))
        )

        #expect(follow.summary == "started following you")
        #expect(request.summary == "asked to follow you")
    }

    // MARK: - Destination

    @Test
    func aLikeOpensThePostAndAFollowOpensTheProfile() throws {
        let like = try #require(AppNotification(row: Self.row()))
        let likedPostID = try #require(like.postID)
        let follow = try #require(
            AppNotification(row: Self.row(kind: "follow", postID: nil, title: nil))
        )

        #expect(NotificationDestination(like) == .post(likedPostID))
        #expect(NotificationDestination(follow) == .profile(Self.actor))
    }
}
