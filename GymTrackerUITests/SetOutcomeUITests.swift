import XCTest

final class SetOutcomeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()
    }

    func testSkipFailFinishAndOpenHistory() {
        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 8))
        app.buttons["quickStart"].tap()

        XCTAssertTrue(app.staticTexts["emptyWorkoutHint"].waitForExistence(timeout: 8))
        app.buttons["addExercise"].tap()

        XCTAssertTrue(app.navigationBars["Choose Exercise"].waitForExistence(timeout: 8))
        let search = app.searchFields["Search exercises"]
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("Barbell Bench Press")
        }
        XCTAssertTrue(app.staticTexts["Barbell Bench Press"].waitForExistence(timeout: 8))
        app.staticTexts["Barbell Bench Press"].tap()

        let completeButtons = app.buttons.matching(identifier: "completeSet")
        XCTAssertTrue(completeButtons.element(boundBy: 0).waitForExistence(timeout: 8))
        app.buttons["addSet"].tap()
        app.buttons["addSet"].tap()
        XCTAssertEqual(completeButtons.count, 3)
        completeButtons.element(boundBy: 0).tap()
        if app.buttons["skipRest"].waitForExistence(timeout: 2) {
            app.buttons["skipRest"].tap()
        }
        app.buttons["failSet"].firstMatch.tap()
        if app.buttons["skipRest"].waitForExistence(timeout: 2) {
            app.buttons["skipRest"].tap()
        }
        app.buttons["skipSet"].firstMatch.tap()

        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.navigationBars["Save workout?"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Completed"].waitForExistence(timeout: 5))
        app.buttons["confirmFinish"].tap()

        XCTAssertTrue(app.navigationBars["Workout saved"].waitForExistence(timeout: 8))
        app.buttons["viewInHistory"].tap()

        XCTAssertTrue(app.navigationBars["Workout"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Skipped"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Failed")).firstMatch.exists)
    }
}
