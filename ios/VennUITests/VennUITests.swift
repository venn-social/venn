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

    // The remote no longer carries demo content (the remove_demo_seed
    // migration retired it) — production data is real and therefore not
    // assertable. Tests anchor on the official @venn account (stable,
    // created by the same migration) and on data-independent chrome.

    @MainActor
    func testFeedTabMounts() {
        // Real feed content is whatever real users posted — unassertable.
        // Smoke: the preview shell mounts with the tab pill present.
        let app = launchApp(extraArgs: ["-designPreview"])
        XCTAssertTrue(app.buttons["Home"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.buttons["Search"].exists)
        XCTAssertTrue(app.buttons["Profile"].exists)
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
    func testProfileTabShowsErrorSurfaceForGhostSession() {
        // The preview shell's synthetic session is a ghost id with no
        // profile row, so the own-profile tab renders its designed error
        // surface. This pins the load → error → retry path; the *loaded*
        // profile rendering is covered by the people-search journey via
        // PublicProfileView (same view-model and components).
        let app = launchApp(extraArgs: ["-previewProfile"])
        XCTAssertTrue(app.staticTexts["Couldn't load your profile"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Try again"].exists)
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

        // The official @venn account (created by the remove_demo_seed
        // migration) is the stable search anchor. The preview session is a
        // ghost id, so @venn is never filtered out as "self".
        let searchField = app.textFields["search_field"]
        focusAndType("venn", into: searchField, app: app)

        // Official account arrives from people search; tap through.
        let row = app.staticTexts["@venn"]
        XCTAssertTrue(row.waitForExistence(timeout: 30))
        row.firstMatch.tap()

        // Public profile: bio + the shelf tabs.
        XCTAssertTrue(app.staticTexts["The official venn account."].waitForExistence(timeout: 30))
        XCTAssertTrue(app.buttons["Collection"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Watchlist"].exists)
    }

    // MARK: - helpers

    /// Tap-to-focus on a SwiftUI `TextField` races layout settling — taps
    /// can land before the field can take keyboard focus ("Neither element
    /// nor any descendant has keyboard focus"), especially on a cold
    /// simulator. Poll actual keyboard focus (not the software keyboard,
    /// which never appears when a hardware keyboard is connected) and
    /// re-tap until it sticks.
    @MainActor
    private func focusAndType(_ text: String, into field: XCUIElement, app _: XCUIApplication) {
        for attempt in 0..<6 {
            field.tap()
            if (field.value(forKey: "hasKeyboardFocus") as? Bool) == true {
                break
            }
            // Give layout/animation half a beat before the next attempt.
            Thread.sleep(forTimeInterval: 0.5 * Double(attempt + 1))
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
