import XCTest

final class FirstWorkoutOrientationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testOrientationCardExplainsTabsThenDismisses() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.staticTexts["Your first workout"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Quick Start")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "History")).firstMatch.exists)
        XCTAssertTrue(app.buttons["quickStart"].exists)
        XCTAssertTrue(app.buttons["startPlan-Boxing Conditioning"].exists)

        app.buttons["dismissOrientation"].tap()
        XCTAssertFalse(app.buttons["dismissOrientation"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["quickStart"].exists)
    }

    func testEmptyHistoryAndProgressOfferStartWorkout() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()
        if app.buttons["dismissOrientation"].waitForExistence(timeout: 5) {
            app.buttons["dismissOrientation"].tap()
        }

        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 8))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.buttons["emptyHistoryStartWorkout"].waitForExistence(timeout: 8))
        app.buttons["emptyHistoryStartWorkout"].tap()
        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 8))

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.buttons["emptyProgressStartWorkout"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Log Body Weight"].exists)
        app.buttons["emptyProgressStartWorkout"].tap()
        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 8))
    }

    func testEmptyPlansOffersCreatePlan() {
        app.launchArguments = ["-inMemoryStore", "-emptyPlans"]
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Plans"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Plans"].tap()
        XCTAssertTrue(app.buttons["emptyPlansCreatePlan"].waitForExistence(timeout: 8))
        app.buttons["emptyPlansCreatePlan"].tap()
        XCTAssertTrue(app.navigationBars["New Plan"].waitForExistence(timeout: 8))
    }

    func testFilteredExercisesOfferClearAndAdd() {
        app.launchArguments = ["-inMemoryStore"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.tabBars.buttons["Exercises"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Exercises"].tap()

        let search = app.searchFields["Search exercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap()
        search.typeText("zzzznope")

        XCTAssertTrue(app.buttons["emptyExercisesClearFilters"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["emptyExercisesAddExercise"].exists)
        app.buttons["emptyExercisesClearFilters"].tap()
        XCTAssertTrue(app.staticTexts["Barbell Bench Press"].waitForExistence(timeout: 8))
    }
}
