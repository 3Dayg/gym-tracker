import XCTest

final class PlanGuidanceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testSeededPlansShowPreviewNotesBeforeStart() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["startPlan-Boxing Conditioning"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "9 exercises")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1:00 rest")).firstMatch.exists)

        app.buttons["startPlan-Boxing Conditioning"].tap()
        XCTAssertTrue(app.staticTexts["planPreviewNotes"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["planPreviewNotes"].label.contains("Tap Start on a timed round"))
        XCTAssertTrue(app.buttons["startPlanFromPreview"].exists)
        app.buttons["startPlanFromPreview"].tap()

        XCTAssertTrue(app.navigationBars["Boxing Conditioning"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Tap Start on a timed round")).firstMatch.waitForExistence(timeout: 5)
        )
    }

    func testInclineWalkPreviewExplainsCardioBlocks() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["startPlan-Incline Walk"].waitForExistence(timeout: 8))
        app.buttons["startPlan-Incline Walk"].tap()
        XCTAssertTrue(app.staticTexts["planPreviewNotes"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["planPreviewNotes"].label.contains("keep walking"))
        XCTAssertTrue(app.staticTexts["planPreviewSummary"].label.contains("5 blocks"))
        app.buttons["startPlanFromPreview"].tap()
        XCTAssertTrue(app.navigationBars["Incline Walk"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "keep walking")).firstMatch.exists
        )
    }

    func testEmptyPlanCannotStartAndOpensEditor() {
        app.launchArguments = ["-inMemoryStore", "-seedUnstartablePlans"]
        app.launch()

        XCTAssertTrue(app.buttons["startPlan-Empty Template"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Can't start")).firstMatch.exists)

        app.buttons["startPlan-Empty Template"].tap()
        XCTAssertTrue(app.staticTexts["planPreviewBlockedReason"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["startPlanFromPreview"].exists)
        app.buttons["editBrokenPlan"].tap()

        XCTAssertTrue(app.navigationBars["Empty Template"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["planEditorBlockedReason"].waitForExistence(timeout: 5))
    }
}
