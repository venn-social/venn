import Foundation
import Supabase
import Testing
@testable import Venn

struct AppErrorTests {
    @Test
    func passesThroughExistingAppError() {
        let original = AppError.unauthorized
        #expect(AppError.from(original) == .unauthorized)
    }

    @Test
    func mapsURLErrorToNetwork() {
        let error = URLError(.notConnectedToInternet)
        #expect(AppError.from(error) == .network)
    }

    @Test
    func mapsTimedOutToNetwork() {
        let error = URLError(.timedOut)
        #expect(AppError.from(error) == .network)
    }

    @Test
    func mapsAuthSessionMissingToUnauthorized() {
        #expect(AppError.from(AuthError.sessionMissing) == .unauthorized)
    }

    @Test
    func mapsPostgrestRLSDenialToUnauthorized() {
        let error = PostgrestError(code: "42501", message: "permission denied for table profiles")
        #expect(AppError.from(error) == .unauthorized)
    }

    @Test
    func mapsGenericPostgrestErrorToValidationCarryingTheServerMessage() {
        let error = PostgrestError(code: "23505", message: "duplicate key value violates unique constraint")
        #expect(AppError.from(error) == .validation("duplicate key value violates unique constraint"))
    }

    @Test
    func mapsCommonURLErrorVariantsToNetwork() {
        let codes: [URLError.Code] = [
            .notConnectedToInternet, .networkConnectionLost, .timedOut,
            .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed,
        ]
        for code in codes {
            #expect(AppError.from(URLError(code)) == .network)
        }
    }

    @Test
    func everyAppErrorCollapsesToALoadErrorReason() {
        #expect(LoadErrorReason(.network) == .offline)
        #expect(LoadErrorReason(.rateLimited) == .rateLimited)
        #expect(LoadErrorReason(.unauthorized) == .unknown)
        #expect(LoadErrorReason(.validation("x")) == .unknown)
        #expect(LoadErrorReason(.server) == .unknown)
        #expect(LoadErrorReason(.unknown(message: "x")) == .unknown)
    }

    @Test
    func mapsRPCRateLimitSQLStateToRateLimited() {
        // P0429 is the repo convention for rl_check failures inside RPCs —
        // see the overlap_rpc migration.
        let error = PostgrestError(code: "P0429", message: "rate_limited")
        #expect(AppError.from(error) == .rateLimited)
    }

    @Test
    func mapsUnrecognisedErrorToUnknownCarryingTheLocalizedDescription() {
        struct CustomError: Error, LocalizedError {
            var errorDescription: String? {
                "boom"
            }
        }
        let result = AppError.from(CustomError())
        if case let .unknown(message) = result {
            #expect(message == "boom")
        } else {
            Issue.record("expected .unknown(message:), got \(result)")
        }
    }
}
