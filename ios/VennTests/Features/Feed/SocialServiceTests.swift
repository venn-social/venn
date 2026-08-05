import Foundation
import Testing
@testable import Venn

@Suite("SocialService wire formats")
struct SocialServiceTests {
    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    @Test("decodes a post_like_info row")
    func decodesLikeInfoRow() throws {
        let json = """
        {
          "post_id": "11111111-1111-1111-1111-111111111111",
          "like_count": 4,
          "liked_by_me": true
        }
        """
        let row = try Self.decoder.decode(LikeInfoRow.self, from: Data(json.utf8))

        #expect(row.likeCount == 4)
        #expect(row.likedByMe == true)
    }

    @Test("decodes a post that nobody has liked")
    func decodesZeroLikes() throws {
        let json = """
        {
          "post_id": "11111111-1111-1111-1111-111111111111",
          "like_count": 0,
          "liked_by_me": false
        }
        """
        let row = try Self.decoder.decode(LikeInfoRow.self, from: Data(json.utf8))

        #expect(row.likeCount == 0)
        #expect(row.likedByMe == false)
    }

    @Test("decodes a post_comment_counts row")
    func decodesCommentCountRow() throws {
        let json = """
        {
          "post_id": "11111111-1111-1111-1111-111111111111",
          "comment_count": 3
        }
        """
        let row = try Self.decoder.decode(CommentCountRow.self, from: Data(json.utf8))

        #expect(row.commentCount == 3)
    }

    @Test("decodes a comment with its embedded author")
    func decodesCommentRow() throws {
        let json = """
        {
          "id": "22222222-2222-2222-2222-222222222222",
          "body": "Loved this.",
          "created_at": "2026-08-05T10:00:00Z",
          "author": {
            "id": "33333333-3333-3333-3333-333333333333",
            "username": "ada",
            "display_name": "Ada",
            "avatar_url": null,
            "bio": null,
            "created_at": "2026-01-01T00:00:00Z"
          }
        }
        """
        let row = try Self.decoder.decode(CommentRow.self, from: Data(json.utf8))
        let comment = PostComment(row: row)

        #expect(comment.body == "Loved this.")
        #expect(comment.author.username == "ada")
    }

    @Test("LikeInfo.none is an unliked post with no likes")
    func likeInfoNoneIsEmpty() {
        // The fallback when the RPC returns nothing for a post — it must
        // read as "no likes", never as "liked".
        #expect(LikeInfo.none.likeCount == 0)
        #expect(LikeInfo.none.likedByMe == false)
    }
}
