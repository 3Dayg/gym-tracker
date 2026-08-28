import XCTest

final class CustomExerciseUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()
    }

    func testDuplicateNameIsRejected() {
        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.tabBars.buttons["Exercises"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Exercises"].tap()

        XCTAssertTrue(app.buttons["Add Exercise"].waitForExistence(timeout: 8))
        app.buttons["Add Exercise"].firstMatch.tap()

        let nameField = app.textFields["exerciseNameField"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 8))
        nameField.tap()
        nameField.typeText("Barbell Bench Press")
        app.buttons["saveExercise"].tap()

        XCTAssertTrue(app.alerts["Name already used"].waitForExistence(timeout: 8))
    }
}
