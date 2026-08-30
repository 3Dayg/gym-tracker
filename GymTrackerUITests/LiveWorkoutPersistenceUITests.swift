import XCTest

final class LiveWorkoutPersistenceUITests: XCTestCase {
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

    func testStaleWorkoutAsksToResumeOrDiscard() {
        app.launchArguments = ["-inMemoryStore", "-seedStaleWorkout"]
        app.launch()

        XCTAssertTrue(app.buttons["resumeStaleWorkout"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["workoutProgress"].waitForExistence(timeout: 5))
        app.buttons["resumeStaleWorkout"].tap()

        XCTAssertTrue(app.waitForLiveSession("Push Day", timeout: 5))
        XCTAssertFalse(app.buttons["resumeStaleWorkout"].exists)
    }

    func testRestoredRestCountdownIsVisible() {
        app.launchArguments = ["-inMemoryStore", "-restoreRest", "45"]
        app.launch()

        XCTAssertTrue(app.waitForLiveSession("Boxing Conditioning"))
        app.dismissLiveKeyboard("Boxing Conditioning")
        XCTAssertTrue(app.staticTexts["restBarCountdown"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["workoutProgress"].exists)
    }

    func testExpiredRestDoesNotShowAStaleTimer() {
        app.launchArguments = ["-inMemoryStore", "-restoreExpiredRest"]
        app.launch()

        XCTAssertTrue(app.waitForLiveSession("Boxing Conditioning"))
        XCTAssertTrue(app.staticTexts["workoutProgress"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["restBarCountdown"].exists)
    }

    func testExpiredWorkRoundShowsCompletionNotice() {
        app.launchArguments = ["-inMemoryStore", "-restoreExpiredWork"]
        app.launch()

        XCTAssertTrue(app.alerts["Round finished"].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.alerts["Round finished"].staticTexts.matching(
                NSPredicate(format: "label CONTAINS %@", "marked complete")
            ).firstMatch.exists
        )
        app.alerts["Round finished"].buttons["OK"].tap()
        XCTAssertTrue(app.waitForLiveSession("Boxing Conditioning", timeout: 5))
        XCTAssertFalse(app.staticTexts["restBarCountdown"].exists)
    }
}
