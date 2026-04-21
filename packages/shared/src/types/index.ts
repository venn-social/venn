/**
 * Cross-app domain types. These are the canonical shapes of our data.
 * Imported by both the mobile app and any future web app or backend.
 */

export interface UserProfile {
  readonly id: string;
  readonly username: string;
  readonly displayName: string;
  readonly avatarUrl: string | null;
  readonly bio: string | null;
  readonly createdAt: string;
}

export interface Post {
  readonly id: string;
  readonly authorId: string;
  readonly caption: string;
  readonly mediaUrl: string | null;
  readonly likeCount: number;
  readonly commentCount: number;
  readonly createdAt: string;
}

export interface Comment {
  readonly id: string;
  readonly postId: string;
  readonly authorId: string;
  readonly body: string;
  readonly createdAt: string;
}
