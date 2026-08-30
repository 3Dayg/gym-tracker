import XCTest

final class LiveWorkoutProgressUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()
    }

    func testBoxingShowsProgressNextCueAndNotesThenAdvances() {
        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["startPlan-Boxing Conditioning A"].waitForExistence(timeout: 8))
        app.buttons["startPlan-Boxing Conditioning A"].tap()
        XCTAssertTrue(app.buttons["startPlanFromPreview"].waitForExistence(timeout: 8))
        app.buttons["startPlanFromPreview"].tap()

        XCTAssertTrue(app.waitForLiveSession("Boxing Conditioning A"))
        XCTAssertTrue(app.staticTexts["workoutProgress"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["workoutProgress"].label.hasPrefix("0 /"))
        XCTAssertTrue(app.staticTexts["workoutProgress"].label.contains("logged"))
        XCTAssertTrue(app.staticTexts["nextSetCue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["nextSetCue"].label.hasPrefix("Up next ·"))
        XCTAssertTrue(
            app.descendants(matching: .any)["exerciseNotes"].waitForExistence(timeout: 8)
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["exerciseNotes"].label
                .contains("Stay light on the balls of your feet")
        )
        XCTAssertTrue(app.buttons["addSetToCurrent"].exists)

        app.buttons["followAlongDone"].tap()
        if app.buttons["skipRest"].waitForExistence(timeout: 3) {
            app.buttons["skipRest"].tap()
        }

        XCTAssertTrue(app.staticTexts["workoutProgress"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["workoutProgress"].label.hasPrefix("1 /"))
        XCTAssertTrue(app.staticTexts["workoutProgress"].label.contains("logged"))
        XCTAssertTrue(app.staticTexts["nextSetCue"].label.hasPrefix("Up next ·"))
    }
}
