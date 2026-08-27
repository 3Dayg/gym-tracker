import XCTest

final class PlanEditorLoopUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testCancelCreateLeavesNoPlan() {
        app.launchArguments = ["-inMemoryStore", "-emptyPlans"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Plans"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Plans"].tap()
        XCTAssertTrue(app.buttons["emptyPlansCreatePlan"].waitForExistence(timeout: 8))
        app.buttons["emptyPlansCreatePlan"].tap()

        XCTAssertTrue(app.navigationBars["New Plan"].waitForExistence(timeout: 8))
        app.buttons["cancelCreatePlan"].tap()

        XCTAssertTrue(app.buttons["emptyPlansCreatePlan"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.otherElements["planRow-New Plan"].exists)
        XCTAssertFalse(app.buttons["planRow-New Plan"].exists)
    }

    func testCreateThreeExercisePlanAndStartFromEditor() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.tabBars.buttons["Plans"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Plans"].tap()
        XCTAssertTrue(app.buttons["newPlan"].waitForExistence(timeout: 8))
        app.buttons["newPlan"].tap()

        XCTAssertTrue(app.navigationBars["New Plan"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["emptyPlanAddExercise"].waitForExistence(timeout: 5))
        app.buttons["emptyPlanAddExercise"].tap()
        XCTAssertTrue(app.navigationBars["Choose Exercises"].waitForExistence(timeout: 8))
        selectExercise("Arnold Press")
        selectExercise("Back Extension")
        selectExercise("Back Squat")
        XCTAssertTrue(app.buttons["Add 3"].waitForExistence(timeout: 5))
        app.buttons["Add 3"].tap()
        XCTAssertTrue(app.navigationBars["Choose Exercises"].waitForNonExistence(timeout: 8))

        XCTAssertTrue(app.staticTexts["Arnold Press"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Back Extension"].exists)
        XCTAssertTrue(app.staticTexts["Back Squat"].exists)

        XCTAssertTrue(app.navigationBars["New Plan"].buttons["Create"].waitForExistence(timeout: 8))
        app.navigationBars["New Plan"].buttons["Create"].tap()

        XCTAssertTrue(app.navigationBars["New Plan"].buttons["Start Workout"].waitForExistence(timeout: 8))
        app.navigationBars["New Plan"].buttons["Start Workout"].tap()

        XCTAssertTrue(app.navigationBars["New Plan"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["nextSetCue"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts["nextSetCue"].label.contains("Arnold Press"),
            app.staticTexts["nextSetCue"].label
        )
    }

    func testDeletePlanRequiresConfirmation() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.tabBars.buttons["Plans"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Plans"].tap()

        let boxing = app.descendants(matching: .any)["planRow-Boxing Conditioning"]
        XCTAssertTrue(boxing.waitForExistence(timeout: 8))
        boxing.swipeLeft()
        XCTAssertTrue(app.buttons["deletePlan"].waitForExistence(timeout: 5))
        app.buttons["deletePlan"].tap()

        XCTAssertTrue(app.buttons["keepPlan"].waitForExistence(timeout: 8))
        app.buttons["keepPlan"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["planRow-Boxing Conditioning"].waitForExistence(timeout: 5))

        boxing.swipeLeft()
        XCTAssertTrue(app.buttons["deletePlan"].waitForExistence(timeout: 5))
        app.buttons["deletePlan"].tap()
        XCTAssertTrue(app.buttons["confirmDeletePlan"].waitForExistence(timeout: 8))
        app.buttons["confirmDeletePlan"].tap()
        XCTAssertFalse(
            app.descendants(matching: .any)["planRow-Boxing Conditioning"].waitForExistence(timeout: 2)
        )
    }

    private func selectExercise(_ name: String) {
        let label = app.staticTexts[name]
        XCTAssertTrue(label.waitForExistence(timeout: 8), "Expected \(name) in the picker")
        label.tap()
    }
}
