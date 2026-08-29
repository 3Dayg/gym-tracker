import XCTest

final class FollowAlongUITests: XCTestCase {
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

    func testStartWorkoutOpensFollowAlongCard() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["startPlan-Boxing Conditioning"].waitForExistence(timeout: 8))
        app.buttons["startPlan-Boxing Conditioning"].tap()
        XCTAssertTrue(app.staticTexts["planPreviewTitle"].waitForExistence(timeout: 8))
        XCTAssertEqual(app.staticTexts["planPreviewTitle"].label, "Boxing Conditioning")
        XCTAssertTrue(app.buttons["startPlanFromPreview"].exists)
        XCTAssertFalse(app.buttons["startFollowAlongFromPreview"].exists)
        app.buttons["startPlanFromPreview"].tap()

        XCTAssertTrue(app.buttons["startWork"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["completeSet"].exists)
        XCTAssertTrue(app.buttons["showExerciseMap"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["showAllSets"].exists)
    }

    func testLaterAndExerciseMapJumpWithoutSkipping() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["startPlan-Incline Walk"].waitForExistence(timeout: 8))
        app.buttons["startPlan-Incline Walk"].tap()
        XCTAssertTrue(app.buttons["startPlanFromPreview"].waitForExistence(timeout: 8))
        app.buttons["startPlanFromPreview"].tap()

        XCTAssertTrue(app.buttons["deferExercise"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["startWork"].waitForExistence(timeout: 5))
        let nextBefore = app.staticTexts["nextSetCue"].label
        XCTAssertFalse(nextBefore.contains("Incline"), nextBefore)
        app.buttons["deferExercise"].tap()

        let nextAfterLater = app.staticTexts["nextSetCue"].label
        XCTAssertTrue(nextAfterLater.contains("Incline Treadmill Walk"), nextAfterLater)

        app.buttons["showExerciseMap"].tap()
        XCTAssertTrue(app.buttons["exerciseMapRow-0"].waitForExistence(timeout: 8))
        app.buttons["exerciseMapRow-0"].tap()

        let nextAfterJump = app.staticTexts["nextSetCue"].label
        XCTAssertFalse(nextAfterJump.contains("Incline"), nextAfterJump)
    }

    func testStrengthDoneStartsRestWithoutLoggingTheNextSet() {
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

        XCTAssertTrue(app.buttons["addSetToCurrent"].waitForExistence(timeout: 8))
        app.buttons["addSetToCurrent"].tap()
        XCTAssertTrue(app.buttons["followAlongDone"].waitForExistence(timeout: 8))
        app.buttons["followAlongDone"].tap()

        XCTAssertTrue(app.buttons["skipRest"].waitForExistence(timeout: 8))
        app.buttons["skipRest"].tap()

        XCTAssertTrue(app.buttons["followAlongDone"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts["nextSetCue"].label.contains("Set 2"),
            app.staticTexts["nextSetCue"].label
        )
    }
}
