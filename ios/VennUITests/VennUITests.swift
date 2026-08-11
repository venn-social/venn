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

    // The onboarding flow needs a session + writes, so it runs against the
    // `-previewOnboarding` shell (in-memory stubs): username step with live
    // availability, then the optional photo step. The shell treats "venn"
    // as taken and everything else as free.

    @MainActor
    func testOnboardingUsernameStepFlagsTakenHandle() {
        let app = launchApp(extraArgs: ["-previewOnboarding"])
        XCTAssertTrue(app.staticTexts["Step 1 of 2"].waitForExistence(timeout: 12))

        let field = app.textFields["onboarding_username_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        focusAndType("venn", into: field, app: app)

        XCTAssertTrue(
            app.staticTexts["@venn is taken — try another"].waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testOnboardingJourneyFreeHandleThroughPhotoStep() {
        let app = launchApp(extraArgs: ["-previewOnboarding"])
        XCTAssertTrue(app.staticTexts["Step 1 of 2"].waitForExistence(timeout: 12))

        let field = app.textFields["onboarding_username_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        focusAndType("ada", into: field, app: app)

        // Live ✓ verdict, then advance to the photo step.
        XCTAssertTrue(app.staticTexts["@ada is available"].waitForExistence(timeout: 5))
        app.buttons["Create profile"].tap()

        // Step 2: optional photo. Skip lands on the shell's done screen.
        XCTAssertTrue(app.staticTexts["Add a face to the name"].waitForExistence(timeout: 5))
        app.buttons["onboarding_photo_skip"].tap()
        XCTAssertTrue(
            app.staticTexts["onboarding_preview_done"].waitForExistence(timeout: 5)
        )
    }

    // The auth (magic-link send) and composer (log flow) write paths run
    // against the `-previewAuth` / `-previewComposer` shells (in-memory
    // stubs) — write journeys would otherwise create rows in the shared
    // remote DB on every CI run. See docs/TECH_DEBT.md item 8.

    @MainActor
    func testAuthSubmitValidEmailShowsSentConfirmationThenResets() {
        let app = launchApp(extraArgs: ["-previewAuth"])
        let field = app.textFields["auth_email_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 12))

        focusAndType("charles@example.com", into: field, app: app)
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Check your inbox"].waitForExistence(timeout: 5))
        // The address is embedded in an interpolated sentence ("We emailed a
        // sign-in link to <email>. ..."), not a standalone element — match
        // by substring rather than the full paragraph.
        let emailMention = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "charles@example.com")
        ).firstMatch
        XCTAssertTrue(emailMention.exists)

        app.buttons["Use a different email"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
    }

    @MainActor
    func testAuthSubmitRateLimitedEmailShowsError() {
        let app = launchApp(extraArgs: ["-previewAuth"])
        let field = app.textFields["auth_email_field"]
        XCTAssertTrue(field.waitForExistence(timeout: 12))

        focusAndType("blocked@example.com", into: field, app: app)
        app.buttons["Continue"].tap()

        XCTAssertTrue(
            app.staticTexts["Too many sign-in requests. Try again in a few minutes."]
                .waitForExistence(timeout: 5)
        )
    }

    @MainActor
    func testComposerLogWithRatingCompletesTheFlow() {
        let app = launchApp(extraArgs: ["-previewComposer"])
        XCTAssertTrue(app.staticTexts["Past Lives"].waitForExistence(timeout: 12))

        let ratingTitle = app.staticTexts["How was it?"]
        tapReliably(app.buttons["Log it"], until: ratingTitle)
        XCTAssertTrue(ratingTitle.exists)

        app.buttons["rating_chip_love"].tap()
        let done = app.staticTexts["composer_preview_done"]
        tapReliably(app.buttons["Finish"], until: done)
        XCTAssertTrue(done.exists)
    }

    @MainActor
    func testComposerAddToWatchlistCompletesTheFlow() {
        let app = launchApp(extraArgs: ["-previewComposer"])
        XCTAssertTrue(app.staticTexts["Past Lives"].waitForExistence(timeout: 12))

        let done = app.staticTexts["composer_preview_done"]
        tapReliably(app.buttons["Add to Watchlist"], until: done)
        XCTAssertTrue(done.exists)
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

    /// A tap that lands before the button is fully hittable (mid-transition,
    /// under-provisioned CI/local hardware) is silently swallowed — same
    /// root cause as `focusAndType`'s keyboard-focus race, different
    /// symptom. Re-tap (when hittable) between short polls for `target`
    /// rather than trusting a single tap blindly.
    @MainActor
    private func tapReliably(_ element: XCUIElement, until target: XCUIElement, attempts: Int = 6) {
        for _ in 0..<attempts {
            if element.isHittable {
                element.tap()
            }
            if target.waitForExistence(timeout: 1) {
                return
            }
        }
    }

    /// The side menu is the only way to Settings, Lists, Activity and Year
    /// in Review now that they are off the tab bar. If the control does not
    /// render, four screens are unreachable and nothing else would catch it
    /// — the unit tests check the destination list, not that anything puts
    /// it on screen.
    ///
    /// Runs against `-designPreview`, which now renders the real `MainView`
    /// with a synthetic session. Using the guest sign-in instead made this
    /// depend on anonymous auth being enabled for the Supabase project, and
    /// it silently is not — the test failed for that reason rather than for
    /// anything about the menu.
    @MainActor
    func testSideMenuReachesTheSecondarySurfaces() {
        let app = launchApp(extraArgs: ["-designPreview"])

        let menuButton = app.buttons["side_menu_button"]
        XCTAssertTrue(
            menuButton.waitForExistence(timeout: 60),
            "The side-menu control never appeared, so Settings, Lists, Activity and Year in Review are unreachable."
        )

        menuButton.tap()

        for destination in ["settings", "lists", "activity", "yearInReview"] {
            XCTAssertTrue(
                app.buttons["side_menu_\(destination)"].waitForExistence(timeout: 15),
                "The side menu is missing its \(destination) entry."
            )
        }
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
