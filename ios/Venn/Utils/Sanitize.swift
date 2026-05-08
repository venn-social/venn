import Foundation

/// Validates and normalises everything a user can type before it touches the
/// database, the UI, or another user's screen. Per `CLAUDE.md` rule 7, this
/// is the first line of defence; the matching Postgres CHECK constraints in
/// `supabase/migrations/` are the last.
///
/// Bounds here MUST stay in sync with the SQL CHECK constraints. When you add
/// or change a validator, update the migration in the same PR.
///
/// API shape:
///   `Sanitize.handle("ada") == .valid("ada")`
///   `Sanitize.handle("ab")  == .invalid(.tooShort)`
enum Sanitize {
    /// What's wrong with a rejected input. The view-model maps these into
    /// localised user-facing messages.
    enum Reason: Equatable {
        case empty
        case tooShort
        case tooLong
        case invalidCharacters
        case invalidFormat
    }

    /// Outcome of a validation. The `.valid` payload is the *normalised* form
    /// — what should actually be stored / sent — not the raw input.
    enum Result: Equatable {
        case valid(String)
        case invalid(Reason)
    }

    // MARK: - Field validators

    /// Social-media handle / username. Lowercased, 3–24 chars, letters /
    /// digits / underscore / hyphen only. Mirrors `profiles_username_format`
    /// in the init migration.
    static func handle(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard trimmed.count >= 3 else { return .invalid(.tooShort) }
        guard trimmed.count <= 24 else { return .invalid(.tooLong) }
        guard trimmed.unicodeScalars.allSatisfy(handleAllowed.contains) else {
            return .invalid(.invalidCharacters)
        }
        return .valid(trimmed)
    }

    /// Display name. 1–40 chars after normalisation. Mirrors
    /// `profiles_display_name_length`.
    static func displayName(_ input: String) -> Result {
        let normalised = normalise(input)
        guard !normalised.isEmpty else { return .invalid(.empty) }
        guard normalised.count <= 40 else { return .invalid(.tooLong) }
        return .valid(normalised)
    }

    /// Bio. Optional (empty allowed), max 160 chars after normalisation.
    /// Mirrors `profiles_bio_length`.
    static func bio(_ input: String) -> Result {
        let normalised = normalise(input)
        guard normalised.count <= 160 else { return .invalid(.tooLong) }
        return .valid(normalised)
    }

    /// Post caption. Required, 1–500 chars after normalisation. Mirrors
    /// `posts_caption_length`.
    static func caption(_ input: String) -> Result {
        let normalised = normalise(input)
        guard !normalised.isEmpty else { return .invalid(.empty) }
        guard normalised.count <= 500 else { return .invalid(.tooLong) }
        return .valid(normalised)
    }

    /// Search query. Optional (empty allowed), max 100 chars after
    /// normalisation. No DB constraint — search is read-only — but normalising
    /// here keeps the API surface consistent.
    static func searchQuery(_ input: String) -> Result {
        let normalised = normalise(input)
        guard normalised.count <= 100 else { return .invalid(.tooLong) }
        return .valid(normalised)
    }

    /// Email address. Trims whitespace, lowercases, and runs a pragmatic
    /// RFC 5322-light format check. Capped at 254 octets per RFC 5321.
    ///
    /// Validation here is for UX feedback only — Supabase Auth runs its own
    /// validation and is the real source of truth. The point of this check
    /// is to catch obvious typos before the user submits the form.
    static func email(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid(.empty) }
        let lowered = trimmed.lowercased()
        guard lowered.count <= 254 else { return .invalid(.tooLong) }
        let pattern = /^[a-z0-9._%+-]+@(?:[a-z0-9-]+\.)+[a-z]{2,}$/
        guard lowered.wholeMatch(of: pattern) != nil else {
            return .invalid(.invalidFormat)
        }
        return .valid(lowered)
    }

    /// HTTPS URL. Plain `http://` is rejected. Returns the URL re-stringified
    /// (canonical form) on success.
    static func httpsURL(_ input: String) -> Result {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .invalid(.empty) }
        guard let url = URL(string: trimmed),
              url.scheme?.lowercased() == "https",
              url.host?.isEmpty == false
        else {
            return .invalid(.invalidFormat)
        }
        return .valid(url.absoluteString)
    }

    // MARK: - Normalisation

    /// Strips dangerous unicode (zero-width, bidi-override, control chars),
    /// applies NFC normalisation, collapses runs of horizontal whitespace,
    /// caps consecutive blank lines at 2, and trims edges. Idempotent — apply
    /// twice and you get the same result.
    static func normalise(_ input: String) -> String {
        let nfc = input.precomposedStringWithCanonicalMapping
        var stripped = ""
        stripped.unicodeScalars.reserveCapacity(nfc.unicodeScalars.count)
        for scalar in nfc.unicodeScalars where !isProblematic(scalar) {
            stripped.unicodeScalars.append(scalar)
        }
        var result = stripped.replacingOccurrences(
            of: #"[ \t]+"#,
            with: " ",
            options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"\n{3,}"#,
            with: "\n\n",
            options: .regularExpression
        )
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Internals

    /// Lowercase letters, digits, underscore, hyphen — the handle alphabet.
    private static let handleAllowed: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_-")
        return set
    }()

    /// True for unicode scalars we strip outright. Keeps tab (0x09) and
    /// newline (0x0A) — useful in captions.
    private static func isProblematic(_ scalar: Unicode.Scalar) -> Bool {
        let value = scalar.value
        // C0 controls, except tab + newline.
        if value <= 0x1F, value != 0x09, value != 0x0A { return true }
        // DEL + C1 controls.
        if value >= 0x7F, value <= 0x9F { return true }
        // Zero-width / direction marks.
        if (0x200B...0x200F).contains(value) { return true }
        // Bidi embedding / override.
        if (0x202A...0x202E).contains(value) { return true }
        // Byte order mark / zero-width no-break space.
        if value == 0xFEFF { return true }
        return false
    }
}
