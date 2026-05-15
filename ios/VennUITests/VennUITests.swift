import XCTest

final class VennUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPrototypeTabsRenderPrimarySurfaces() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.otherElements["launch_video_splash"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Feed"].waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["Today"].exists)

        tapTab("Explorer", in: app)
        XCTAssertTrue(app.staticTexts["Explorer"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Recommended for you"].exists)
        XCTAssertTrue(app.staticTexts["Aftersun"].exists)

        app.buttons["Music"].tap()
        XCTAssertTrue(app.staticTexts["Dragon New Warm Mountain I Believe in You"].waitForExistence(timeout: 5))

        app.buttons["Books"].tap()
        XCTAssertTrue(app.staticTexts["Tomorrow, and Tomorrow, and Tomorrow"].waitForExistence(timeout: 5))

        tapTab("Profile", in: app)
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Maya Chen"].exists)
        XCTAssertTrue(app.staticTexts["Library"].exists)
        XCTAssertTrue(app.staticTexts["Data Room"].exists)
    }

    @MainActor
    private func tapTab(
        _ title: String,
        in app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "Missing \(title) tab", file: file, line: line)
        XCTAssertTrue(waitUntilHittable(tab), "\(title) tab was not hittable", file: file, line: line)
        tab.tap()
    }

    @MainActor
    private func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.isHittable {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return element.exists && element.isHittable
    }
}
