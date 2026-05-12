import XCTest

final class VennUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppLaunchesIntoPrototypeFeed() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Feed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Today"].exists)
        XCTAssertTrue(app.tabBars.buttons["Explorer"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
    }
}
