import XCTest

final class ProgressClarityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore", "-seedHistorySummaries"]
        app.launch()
    }

    func testProgressExplainsOneRepMaxAndUsesSearchablePicker() {
        XCTAssertTrue(app.tabBars.buttons["Progress"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Progress"].tap()

        XCTAssertTrue(app.buttons["chooseProgressExercise"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["oneRepMaxFootnote"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["onePointGuidance"].waitForExistence(timeout: 5))

        app.buttons["chooseProgressExercise"].tap()
        XCTAssertTrue(app.navigationBars["Exercise"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["selectProgressExercise-Barbell Bench Press"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["selectProgressExercise-Jump Rope"].exists)
        app.buttons["selectProgressExercise-Treadmill Walk"].tap()

        XCTAssertTrue(app.staticTexts["Longest session"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Steepest incline"].exists)
        XCTAssertTrue(app.staticTexts["onePointGuidance"].exists)
    }
}
