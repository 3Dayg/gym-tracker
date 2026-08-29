import XCTest

final class PrivacyPolicyUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()
    }

    func testWelcomePrivacyLinkOpensPolicy() {
        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["onboardingPrivacyPolicy"].waitForExistence(timeout: 5))
        app.buttons["onboardingPrivacyPolicy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "does not use an account")).firstMatch.waitForExistence(timeout: 5)
        )
    }

    func testProfilePrivacyLinkOpensPolicy() {
        XCTAssertTrue(app.buttons["skipOnboarding"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()
        XCTAssertTrue(app.buttons["Settings"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.buttons["privacyPolicy"].waitForExistence(timeout: 8))
        app.buttons["privacyPolicy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 8))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Nothing you log is uploaded")).firstMatch.waitForExistence(timeout: 5)
        )
    }
}
