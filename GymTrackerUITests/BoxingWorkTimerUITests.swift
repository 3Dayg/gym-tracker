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
        XCTAssertTrue(app.buttons["startPlan-Boxing Conditioning"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "9 exercises")).firstMatch.exists)

        app.buttons["startPlan-Boxing Conditioning"].tap()
        XCTAssertTrue(app.buttons["startPlanFromPreview"].waitForExistence(timeout: 8))
        app.buttons["startPlanFromPreview"].tap()

        XCTAssertTrue(app.navigationBars["Boxing Conditioning"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.descendants(matching: .any)["timedRestHint"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["startWork"].firstMatch.waitForExistence(timeout: 5))

        app.buttons["startWork"].firstMatch.tap()
        // Deliver a possible notification-permission interruption.
        app.navigationBars["Boxing Conditioning"].tap()

        XCTAssertTrue(app.staticTexts["workPrepCountdown"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["pauseWork"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["workCountdown"].exists)

        app.buttons["pauseWork"].firstMatch.tap()
        XCTAssertTrue(app.buttons["resumeWork"].firstMatch.waitForExistence(timeout: 5))
    }
}
