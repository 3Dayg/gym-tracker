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

    func testFollowAlongFromPlanPreviewAndSwitchToList() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["startPlan-Boxing Conditioning"].waitForExistence(timeout: 8))
        app.buttons["startPlan-Boxing Conditioning"].tap()
        XCTAssertTrue(app.buttons["startFollowAlongFromPreview"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["startPlanFromPreview"].exists)
        app.buttons["startFollowAlongFromPreview"].tap()

        XCTAssertTrue(app.buttons["startWork"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["completeSet"].exists)

        XCTAssertTrue(app.buttons["showAllSets"].waitForExistence(timeout: 5))
        app.buttons["showAllSets"].tap()
        XCTAssertTrue(app.buttons["completeSet"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["enterFollowAlong"].waitForExistence(timeout: 5))
        app.buttons["enterFollowAlong"].tap()
        XCTAssertTrue(app.buttons["startWork"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["completeSet"].exists)
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

        XCTAssertTrue(app.buttons["addSet"].waitForExistence(timeout: 8))
        app.buttons["addSet"].tap()
        XCTAssertTrue(app.buttons["enterFollowAlong"].waitForExistence(timeout: 5))
        app.buttons["enterFollowAlong"].tap()

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
