import XCTest

final class HistorySummaryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testHistoryCaptionsMatchEachModality() {
        app.launchArguments = ["-inMemoryStore", "-seedHistorySummaries"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 10))
        app.tabBars.buttons["History"].tap()

        let strength = app.staticTexts["historySummary-Push Day"]
        XCTAssertTrue(strength.waitForExistence(timeout: 8))
        XCTAssertTrue(strength.label.localizedCaseInsensitiveContains("set"))
        XCTAssertTrue(strength.label.localizedCaseInsensitiveContains("kg"))
        XCTAssertFalse(strength.label.localizedCaseInsensitiveContains("round"))
        XCTAssertFalse(strength.label.localizedCaseInsensitiveContains("block"))

        let timed = app.staticTexts["historySummary-Boxing Conditioning"]
        XCTAssertTrue(timed.waitForExistence(timeout: 5))
        XCTAssertTrue(timed.label.localizedCaseInsensitiveContains("round"))
        XCTAssertFalse(timed.label.localizedCaseInsensitiveContains("kg"))
        XCTAssertFalse(timed.label.localizedCaseInsensitiveContains("set"))

        let cardio = app.staticTexts["historySummary-Incline Walk"]
        XCTAssertTrue(cardio.waitForExistence(timeout: 5))
        XCTAssertTrue(cardio.label.localizedCaseInsensitiveContains("block"))
        XCTAssertFalse(cardio.label.localizedCaseInsensitiveContains("kg"))

        let mixed = app.staticTexts["historySummary-Mixed Day"]
        XCTAssertTrue(mixed.waitForExistence(timeout: 5))
        XCTAssertTrue(mixed.label.localizedCaseInsensitiveContains("set"))
        XCTAssertTrue(mixed.label.localizedCaseInsensitiveContains("round"))
        XCTAssertTrue(mixed.label.localizedCaseInsensitiveContains("block"))

        app.buttons["historyRow-Boxing Conditioning"].tap()
        XCTAssertTrue(app.staticTexts["Rounds"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Work time"].exists)
        XCTAssertFalse(app.staticTexts["Total volume"].exists)
        app.navigationBars.buttons["History"].tap()

        app.buttons["historyRow-Push Day"].tap()
        XCTAssertTrue(app.staticTexts["Sets"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Total volume"].exists)
    }

    func testDeletingAWorkoutAsksBeforeRemovingIt() {
        app.launchArguments = ["-inMemoryStore", "-seedHistorySummaries"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 10))
        app.tabBars.buttons["History"].tap()

        let mixedSummary = app.staticTexts["historySummary-Mixed Day"]
        XCTAssertTrue(mixedSummary.waitForExistence(timeout: 8))
        mixedSummary.swipeLeft()

        XCTAssertTrue(app.buttons["deleteHistoryWorkout"].waitForExistence(timeout: 5))
        app.buttons["deleteHistoryWorkout"].tap()

        XCTAssertTrue(app.buttons["cancelDeleteHistory"].waitForExistence(timeout: 8))
        app.buttons["cancelDeleteHistory"].tap()
        XCTAssertFalse(app.buttons["cancelDeleteHistory"].waitForExistence(timeout: 3))
        if app.buttons["deleteHistoryWorkout"].exists {
            app.staticTexts["Mixed Day"].swipeRight()
        }
        XCTAssertTrue(app.staticTexts["Mixed Day"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["historySummary-Mixed Day"].waitForExistence(timeout: 5))

        app.staticTexts["historySummary-Mixed Day"].swipeLeft()
        XCTAssertTrue(app.buttons["deleteHistoryWorkout"].waitForExistence(timeout: 5))
        app.buttons["deleteHistoryWorkout"].tap()
        XCTAssertTrue(app.buttons["confirmDeleteHistory"].waitForExistence(timeout: 8))
        app.buttons["confirmDeleteHistory"].tap()
        XCTAssertFalse(app.staticTexts["historySummary-Mixed Day"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["historySummary-Push Day"].exists)
    }

    func testFinishSaveErrorCanBeRetried() {
        app.launchArguments = ["-inMemoryStore", "-seedFinishableWorkout", "-failFinishSave"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Push Day"].waitForExistence(timeout: 10))
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["confirmFinish"].waitForExistence(timeout: 8))
        app.buttons["confirmFinish"].tap()

        XCTAssertTrue(app.buttons["retrySaveWorkout"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.navigationBars["Push Day"].exists)
        app.buttons["retrySaveWorkout"].tap()

        XCTAssertTrue(app.navigationBars["Workout saved"].waitForExistence(timeout: 8))
        app.buttons["viewInHistory"].tap()
        XCTAssertTrue(app.navigationBars["Push Day"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Total volume"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["historyDetailStrengthSets"].exists)

        app.navigationBars.buttons["History"].tap()
        let summary = app.staticTexts["historySummary-Push Day"]
        XCTAssertTrue(summary.waitForExistence(timeout: 8))
        XCTAssertTrue(summary.label.localizedCaseInsensitiveContains("set"))
    }
}
