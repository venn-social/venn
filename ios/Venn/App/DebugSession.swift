import Foundation
import Supabase

#if DEBUG
    /// Synthetic signed-in sessions for the DEBUG preview shells (`DesignPreviewView`,
    /// `ComposerPreviewView`, ...) that need a real `authorID` without going through
    /// magic-link auth. Reads still go through the real client (anon key); the token
    /// is never transmitted.
    enum DebugSession {
        /// A fixed "ghost" id with no `profiles` row, so shells built on real reads
        /// (Feed/Explorer/People-search) never treat it as "self" and filter it out.
        static let ghostUserID = UUID(uuidString: "0000dead-0000-4000-8000-000000000001") ?? UUID()

        static func make(userID: UUID = ghostUserID) -> Session {
            let now = Date()
            let user = User(
                id: userID,
                appMetadata: [:],
                userMetadata: [:],
                aud: "authenticated",
                createdAt: now,
                updatedAt: now,
                isAnonymous: true
            )
            return Session(
                accessToken: "debug-preview",
                tokenType: "bearer",
                expiresIn: 3600,
                expiresAt: now.addingTimeInterval(3600).timeIntervalSince1970,
                refreshToken: "debug-preview",
                user: user
            )
        }
    }
#endif
