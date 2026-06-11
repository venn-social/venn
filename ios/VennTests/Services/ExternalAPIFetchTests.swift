import Foundation
import Testing
@testable import Venn

/// Tests for `ExternalAPI.fetch`'s HTTP-status → `AppError` policy, the
/// one mapping every catalog service (TMDB / OpenLibrary / MusicBrainz)
/// rides through. Uses a stub `URLProtocol` — no network.
struct ExternalAPIFetchTests {
    @Test
    func successReturnsBody() async throws {
        let data = try await fetch(status: 200, body: Data("ok".utf8))
        #expect(String(bytes: data, encoding: .utf8) == "ok")
    }

    @Test
    func unauthorizedStatusesMapToUnauthorized() async {
        await #expect(throws: AppError.unauthorized) { _ = try await fetch(status: 401) }
        await #expect(throws: AppError.unauthorized) { _ = try await fetch(status: 403) }
    }

    @Test
    func throttleStatusesMapToRateLimited() async {
        await #expect(throws: AppError.rateLimited) { _ = try await fetch(status: 429) }
        await #expect(throws: AppError.rateLimited) { _ = try await fetch(status: 503) }
    }

    @Test
    func otherClientErrorsMapToValidationWithStatus() async {
        await #expect(throws: AppError.validation("HTTP 404")) { _ = try await fetch(status: 404) }
    }

    @Test
    func serverErrorsMapToServer() async {
        await #expect(throws: AppError.server) { _ = try await fetch(status: 500) }
    }

    @Test
    func userAgentHeaderIsSentWhenProvided() async throws {
        _ = try await fetch(status: 200, userAgent: "venn-test/1.0")
        let seen = StubURLProtocol.lastRequest?.value(forHTTPHeaderField: "User-Agent")
        #expect(seen == "venn-test/1.0")
    }

    // MARK: - Plumbing

    private func fetch(
        status: Int,
        body: Data = Data(),
        userAgent: String? = nil
    ) async throws -> Data {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let session = URLSession(configuration: configuration)
        StubURLProtocol.stub = StubURLProtocol.Stub(status: status, body: body)
        guard let url = URL(string: "https://stub.test/path") else {
            throw AppError.unknown(message: "bad test url")
        }
        return try await ExternalAPI.fetch(url: url, session: session, userAgent: userAgent)
    }
}

/// Serves every request from the configured stub and records the last
/// request seen. State is a pair of static slots — fine here because each
/// test configures then awaits one request at a time.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Stub {
        let status: Int
        let body: Data
    }

    nonisolated(unsafe) static var stub: Stub?
    nonisolated(unsafe) static var lastRequest: URLRequest?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let stub = Self.stub, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        Self.lastRequest = request
        if let response = HTTPURLResponse(
            url: url,
            statusCode: stub.status,
            httpVersion: "HTTP/1.1",
            headerFields: nil
        ) {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: stub.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
