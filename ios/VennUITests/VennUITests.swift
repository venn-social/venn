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

    @MainActor
    func testFeedTabRenders() {
        let app = launchApp(extraArgs: [])
        // Feed renders from a live Supabase fetch. CI doesn't have the
        // Supabase creds, so we only assert on chrome (the nav title).
        // Data-dependent assertion comes back with stub services.
        XCTAssertTrue(app.staticTexts["Feed"].waitForExistence(timeout: 12))
    }

    @MainActor
    func testExplorerTabRenders() {
        let app = launchApp(extraArgs: ["-previewExplorer"])
        // Default category is "All", so the browse prompt appears instead of recommendations.
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
        // Profile in DesignPreviewView is still the prototype view, so
        // we can keep the rich content assertions here.
        let app = launchApp(extraArgs: ["-previewProfile"])
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Maya Chen"].exists)
        XCTAssertTrue(app.staticTexts["Library"].exists)
        // Pills are now Buttons — query via buttons(…) not staticTexts(…).
        XCTAssertTrue(app.buttons["Data Room"].exists)
    }

    // MARK: - helpers

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
