import XCTest

final class DataBackupUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()
    }

    func testProfileOffersExportAndCancelableReset() {
        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["Profile"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["Profile"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))

        app.swipeUp()
        XCTAssertTrue(app.buttons["exportJSONBackup"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["exportWorkoutsCSV"].exists)
        XCTAssertTrue(app.buttons["deleteAllData"].exists)

        app.buttons["deleteAllData"].tap()
        XCTAssertTrue(app.navigationBars["Delete all data?"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["deleteAllDataWarning"].waitForExistence(timeout: 5))
        app.buttons["keepAllData"].tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["deleteAllData"].exists)
    }

    func testDeleteAllDataReturnsToWelcome() {
        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["Profile"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["Profile"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 8))
        app.swipeUp()
        XCTAssertTrue(app.buttons["deleteAllData"].waitForExistence(timeout: 8))
        app.buttons["deleteAllData"].tap()
        XCTAssertTrue(app.navigationBars["Delete all data?"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["confirmDeleteAllData"].waitForExistence(timeout: 8))
        app.buttons["confirmDeleteAllData"].tap()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["skipOnboarding"].exists)
    }
}
