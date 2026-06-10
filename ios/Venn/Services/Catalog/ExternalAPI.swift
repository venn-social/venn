import Foundation

/// Shared HTTP plumbing for the external catalog services (TMDB,
/// OpenLibrary, MusicBrainz). Each service builds its own URLs and decodes
/// its own wire format; the request execution and HTTP-status → `AppError`
/// mapping live here so the policy is defined once (ADR 0006).
enum ExternalAPI {
    /// Perform a GET and map non-2xx statuses to semantic `AppError`s:
    /// 401/403 → `.unauthorized`, 429/503 → `.rateLimited` (503 is
    /// "overloaded, retry later" — same user guidance as a rate limit),
    /// other 4xx → `.validation`, 5xx → `.server`. Transport failures
    /// funnel through `AppError.from(_:)`.
    static func fetch(
        url: URL,
        session: URLSession,
        userAgent: String? = nil
    ) async throws -> Data {
        var request = URLRequest(url: url)
        if let userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                switch http.statusCode {
                case 200..<300:
                    break
                case 401, 403:
                    throw AppError.unauthorized
                case 429, 503:
                    throw AppError.rateLimited
                case 400..<500:
                    throw AppError.validation("HTTP \(http.statusCode)")
                default:
                    throw AppError.server
                }
            }
            return data
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.from(error)
        }
    }

    /// Extract the four-digit year from a catalog date string —
    /// "YYYY-MM-DD", "YYYY-MM", or "YYYY".
    static func year(from dateString: String?) -> Int? {
        guard let s = dateString, s.count >= 4 else { return nil }
        return Int(s.prefix(4))
    }
}
