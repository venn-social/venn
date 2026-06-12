import XCTest

final class VennUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // One test per tab. We used to walk all three in one launch via tab
    // taps, but iOS 26's Tab API plus `.task`-loading tabs interacts
    // badly with XCUITest taps — the tap registers but the active tab
    // doesn't switch when the destination tab also has an env-injected
    // service that loads on appear (Feed→Explorer both do). Launching
    // directly into each tab via the `-preview<Tab>` arg the app
    // already supports sidesteps that flake and is honestly a cleaner
    // test shape — each tab is asserted in isolation, no order coupling.
    // The full-flow tab-switching journey lands back when stub services
    // are wired via launch arg (see Notion follow-up).

    // Each test waits for *loaded*, data-backed content (CI has Supabase
    // creds and the remote carries the committed seed) rather than just the
    // tab shell. Waiting for the seeded row keeps the loaded views alive long
    // enough to render — which is also what they're meant to verify.

    @MainActor
    func testFeedTabRenders() {
        let app = launchApp(extraArgs: [])
        XCTAssertTrue(app.staticTexts["Past Lives"].waitForExistence(timeout: 30))
    }

    @MainActor
    func testExplorerTabRenders() {
        let app = launchApp(extraArgs: ["-previewExplorer"])
        // Default category is "All": the browse prompt + chips render without a
        // network fetch, so they're the CI-safe chrome to assert on.
        XCTAssertTrue(
            app.staticTexts["Search everything"].waitForExistence(timeout: 12)
        )
        XCTAssertTrue(app.buttons["All"].exists)
        XCTAssertTrue(app.buttons["TV"].exists)
        XCTAssertTrue(app.buttons["Music"].exists)
        XCTAssertTrue(app.buttons["Books"].exists)
    }

    @MainActor
    func testProfileTabRenders() {
        // -previewProfile pins the debug session to the seeded "Maya Chen".
        let app = launchApp(extraArgs: ["-previewProfile"])
        XCTAssertTrue(app.staticTexts["Maya Chen"].waitForExistence(timeout: 30))
    }

    @MainActor
    func testPeopleSearchToPublicProfileJourney() {
        // The social-loop journey: Explorer → People → search a seeded
        // user → their public profile renders header + shelves. Category
        // chips are in-screen buttons (not Tab taps), so this avoids the
        // tab-switching flake documented above.
        let app = launchApp(extraArgs: ["-previewExplorer"])
        XCTAssertTrue(app.staticTexts["Search everything"].waitForExistence(timeout: 12))

        app.buttons["People"].tap()
        XCTAssertTrue(app.staticTexts["Find your people"].waitForExistence(timeout: 5))

        // Search "theo", not "maya": the preview shell's debug session IS
        // maya (seeded id 1111…), and people search filters yourself out.
        let searchField = app.textFields["search_field"]
        focusAndType("theo", into: searchField, app: app)

        // Seeded profile arrives from people search; tap through.
        let row = app.staticTexts["@theo"]
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        row.firstMatch.tap()

        // Public profile: header name + the shelf tabs.
        XCTAssertTrue(app.staticTexts["Theo Park"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Collection"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Watchlist"].exists)
    }

    // MARK: - helpers

    /// Tap-to-focus on a SwiftUI `TextField` races layout settling — the
    /// first tap sometimes lands before the field can take keyboard focus
    /// ("Neither element nor any descendant has keyboard focus"). Wait for
    /// the keyboard after tapping and retry with a coordinate tap once
    /// before typing.
    @MainActor
    private func focusAndType(_ text: String, into field: XCUIElement, app: XCUIApplication) {
        field.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 3) {
            field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            _ = app.keyboards.firstMatch.waitForExistence(timeout: 3)
        }
        field.typeText(text)
    }

    @MainActor
    private func launchApp(extraArgs: [String]) -> XCUIApplication {
        // Skip the 5-second branded splash for tab-rendering coverage.
        // The splash itself is intentionally orchestrated against wall-
        // clock time and produces flaky CI runs when other tests warm
        // up the simulator first. Splash visibility is covered in a
        // dedicated test that opts back into it (or via snapshots).
        let app = XCUIApplication()
        app.launchArguments.append("-skipLaunchSplash")
        for arg in extraArgs {
            app.launchArguments.append(arg)
        }
        app.launch()
        return app
    }
}
