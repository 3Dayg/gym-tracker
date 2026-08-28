import XCTest

final class ConvenienceControlsUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            let buttons = ["Allow", "Allow Once", "Don’t Allow", "Don't Allow"]
            for title in buttons where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
    }

    func testWeightStepperOnNextSet() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 8))
        app.buttons["quickStart"].tap()

        XCTAssertTrue(app.staticTexts["emptyWorkoutHint"].waitForExistence(timeout: 8))
        app.buttons["addExercise"].tap()

        XCTAssertTrue(app.navigationBars["Choose Exercise"].waitForExistence(timeout: 8))
        let search = app.textFields["searchExercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap()
        search.typeText("Barbell Bench Press")
        XCTAssertTrue(app.staticTexts["Barbell Bench Press"].waitForExistence(timeout: 8))
        app.staticTexts["Barbell Bench Press"].tap()

        XCTAssertTrue(app.buttons["incrementWeight"].waitForExistence(timeout: 8))
        let chip = app.buttons["weightValue"]
        let before = chip.label
        XCTAssertFalse(before.isEmpty, "weight chip should expose a label")
        app.buttons["incrementWeight"].tap()
        let after = app.buttons["weightValue"].label
        XCTAssertNotEqual(after, before, "expected weight to change from \(before)")

        app.buttons["addSet"].tap()
        XCTAssertEqual(app.buttons.matching(identifier: "incrementWeight").count, 1)
    }

    func testRestAdjustButtonsOnRestoredTimer() {
        app.launchArguments = ["-inMemoryStore", "-restoreRest", "90"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Boxing Conditioning"].waitForExistence(timeout: 10))
        app.navigationBars["Boxing Conditioning"].tap()
        XCTAssertTrue(app.buttons["incrementRest"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["decrementRest"].exists)
        app.buttons["incrementRest"].tap()
        XCTAssertTrue(app.staticTexts["restBarCountdown"].waitForExistence(timeout: 2))
        app.buttons["skipRest"].tap()
        XCTAssertFalse(app.staticTexts["restBarCountdown"].waitForExistence(timeout: 2))
    }

    func testRecentExerciseAppearsInPicker() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 8))
        app.buttons["quickStart"].tap()

        XCTAssertTrue(app.staticTexts["emptyWorkoutHint"].waitForExistence(timeout: 8))
        app.buttons["addExercise"].tap()
        pickBenchPress()

        XCTAssertTrue(app.buttons["completeSet"].waitForExistence(timeout: 8))
        app.buttons["completeSet"].firstMatch.tap()
        if app.buttons["skipRest"].waitForExistence(timeout: 2) {
            app.buttons["skipRest"].tap()
        }

        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.navigationBars["Save workout?"].waitForExistence(timeout: 8))
        app.buttons["confirmFinish"].tap()
        XCTAssertTrue(app.navigationBars["Workout saved"].waitForExistence(timeout: 8))
        app.buttons["savedDone"].tap()

        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 8))
        app.buttons["quickStart"].tap()
        XCTAssertTrue(app.buttons["addExercise"].waitForExistence(timeout: 8))
        app.buttons["addExercise"].tap()

        XCTAssertTrue(app.navigationBars["Choose Exercise"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["recentExercise-Barbell Bench Press"].waitForExistence(timeout: 8))
    }

    private func pickBenchPress() {
        XCTAssertTrue(app.navigationBars["Choose Exercise"].waitForExistence(timeout: 8))
        let search = app.textFields["searchExercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap()
        search.typeText("Barbell Bench Press")
        XCTAssertTrue(app.staticTexts["Barbell Bench Press"].waitForExistence(timeout: 8))
        app.staticTexts["Barbell Bench Press"].tap()
    }
}
