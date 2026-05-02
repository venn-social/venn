import Foundation

extension URL {
    /// Parse a URL string that's known-good at compile time (hardcoded
    /// constants in the codebase). Crashes loudly with a precondition failure
    /// if the string is not parseable as a URL — meant only for internal,
    /// audited values. Never pass user input here.
    ///
    /// Why this exists: SwiftLint's `force_unwrapping` rule (correctly) bans
    /// `URL(string: "https://…")!` in production code. This initializer makes
    /// the same intent explicit and keeps the call site clean.
    init(staticString: StaticString) {
        guard let url = URL(string: "\(staticString)") else {
            preconditionFailure("Invalid static URL: \(staticString)")
        }
        self = url
    }
}
