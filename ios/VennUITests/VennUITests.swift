import XCTest

final class VennUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testPrototypeTabsRenderPrimarySurfaces() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Today"].exists)

        app.tabBars.buttons["Explorer"].tap()
        XCTAssertTrue(app.staticTexts["Explorer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recommended for you"].exists)
        XCTAssertTrue(app.staticTexts["Aftersun"].exists)

        app.buttons["Music"].tap()
        XCTAssertTrue(app.staticTexts["Dragon New Warm Mountain I Believe in You"].waitForExistence(timeout: 5))

        app.buttons["Books"].tap()
        XCTAssertTrue(app.staticTexts["Tomorrow, and Tomorrow, and Tomorrow"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["Profile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Maya Chen"].exists)
        XCTAssertTrue(app.staticTexts["Library"].exists)
        XCTAssertTrue(app.staticTexts["Data Room"].exists)
    }
}
