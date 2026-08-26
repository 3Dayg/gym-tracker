import XCTest

final class BoxingWorkTimerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            let buttons = ["Allow", "Allow Once", "Don’t Allow", "Don't Allow"]
            for title in buttons where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
    }

    func testBoxingPlanShowsRestAndStartsWorkCountdown() throws {
        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Boxing Conditioning"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["9 exercises · 1:00 rest"].exists)

        app.staticTexts["Boxing Conditioning"].tap()

        XCTAssertTrue(app.navigationBars["Boxing Conditioning"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Rest after a round"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["startWork"].firstMatch.waitForExistence(timeout: 5))

        app.buttons["startWork"].firstMatch.tap()
        // Deliver a possible notification-permission interruption.
        app.navigationBars["Boxing Conditioning"].tap()

        XCTAssertTrue(app.buttons["pauseWork"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["workCountdown"].exists)

        app.buttons["pauseWork"].firstMatch.tap()
        XCTAssertTrue(app.buttons["resumeWork"].firstMatch.waitForExistence(timeout: 5))
    }
}
