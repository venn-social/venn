import Foundation
import Supabase

/// Thrown by `createProfile` when the username's unique constraint fires —
/// distinct from `AppError` because the view-model renders it as inline
/// field feedback ("taken, try another"), not a generic failure.
struct UsernameTakenError: Error, Equatable {}

/// First-run profile creation. Sign-in (magic link) only proves an email;
/// nothing creates a `profiles` row — this service fills that gap behind
/// the onboarding gate. RLS allows insert only as yourself.
protocol OnboardingServicing: Sendable {
    /// Whether a `profiles` row exists for `userID`.
    func hasProfile(userID: UUID) async throws -> Bool

    /// Insert the user's profile row. Throws `UsernameTakenError` when the
    /// username is already claimed (DB unique constraint — the only
    /// authority on uniqueness; no pre-check race).
    func createProfile(userID: UUID, username: String, displayName: String?) async throws
}

struct OnboardingService: OnboardingServicing {
    /// Postgres duplicate-key SQLSTATE — here it can only mean the
    /// username collided (id collisions are impossible for a fresh user).
    private static let uniqueViolation = "23505"

    let client: SupabaseClient

    func hasProfile(userID: UUID) async throws -> Bool {
        do {
            let count = try await client
                .from("profiles")
                .select("id", head: true, count: .exact)
                .eq("id", value: userID)
                .execute()
                .count ?? 0
            return count > 0
        } catch {
            throw AppError.from(error)
        }
    }

    func createProfile(userID: UUID, username: String, displayName: String?) async throws {
        do {
            try await client
                .from("profiles")
                .insert(NewProfilePayload(id: userID, username: username, displayName: displayName))
                .execute()
        } catch let error as PostgrestError where error.code == Self.uniqueViolation {
            throw UsernameTakenError()
        } catch {
            throw AppError.from(error)
        }
    }
}

private struct NewProfilePayload: Encodable {
    let id: UUID
    let username: String
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
    }
}
