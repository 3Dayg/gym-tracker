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

        XCTAssertTrue(app.buttons["startPlan-Boxing Conditioning A"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "6 exercises")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "1:00 rest")).firstMatch.exists)

        app.buttons["startPlan-Boxing Conditioning A"].tap()
        XCTAssertTrue(app.staticTexts["planPreviewNotes"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["planPreviewNotes"].label.contains("Tap Start on a timed round"))
        XCTAssertTrue(app.buttons["startPlanFromPreview"].exists)
        app.buttons["startPlanFromPreview"].tap()

        XCTAssertTrue(app.waitForLiveSession("Boxing Conditioning A"))
        XCTAssertTrue(app.buttons["startWork"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["planGuidance"].exists)
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
        XCTAssertTrue(app.staticTexts["planPreviewSummary"].label.contains("5 sets"))
        app.buttons["startPlanFromPreview"].tap()
        XCTAssertTrue(app.waitForLiveSession("Incline Walk"))
        XCTAssertTrue(app.buttons["startWork"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["planGuidance"].exists)
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

    func testMixedMissingExercisesCannotStart() {
        app.launchArguments = ["-inMemoryStore", "-seedUnstartablePlans"]
        app.launch()

        XCTAssertTrue(app.buttons["startPlan-Half Broken"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Can't start")).firstMatch.exists)
        app.buttons["startPlan-Half Broken"].tap()
        XCTAssertTrue(app.staticTexts["planPreviewBlockedReason"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["planPreviewBlockedReason"].label.contains("nothing is skipped"))
        XCTAssertFalse(app.buttons["startPlanFromPreview"].exists)
    }

    func testDraftPlansDoNotAppearOnWorkoutStart() {
        app.launchArguments = ["-inMemoryStore", "-seedDraftPlan"]
        app.launch()

        XCTAssertTrue(app.buttons["startPlan-Boxing Conditioning A"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Unfinished Draft"].exists)
        XCTAssertFalse(app.buttons["startPlan-Unfinished Draft"].exists)
    }
}
