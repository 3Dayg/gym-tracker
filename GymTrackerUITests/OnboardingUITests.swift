import XCTest

final class OnboardingUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"]
        app.launch()
    }

    func testWelcomeCopyHasNoCaloriePromise() {
        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["onboardingPrivacyCopy"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "calorie")).firstMatch.exists)
        XCTAssertTrue(app.buttons["skipOnboarding"].exists)
        XCTAssertTrue(app.buttons["addOnboardingMeasurements"].exists)
        XCTAssertFalse(app.buttons["continueOnboarding"].exists)
        XCTAssertTrue(app.buttons["onboardingPrivacyPolicy"].exists)
        app.buttons["addOnboardingMeasurements"].tap()
        XCTAssertTrue(app.buttons["continueOnboarding"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["onboardingWeightFooter"].waitForExistence(timeout: 5))
    }

    func testSkipForNowReachesQuickStart() {
        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["skipOnboarding"].tap()

        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.tabBars.buttons["Workout"].exists)
        XCTAssertFalse(app.navigationBars["Welcome"].exists)
        XCTAssertTrue(app.staticTexts["Boxing Conditioning A"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Boxing Conditioning B"].exists)
        XCTAssertTrue(app.staticTexts["Boxing Conditioning C"].exists)
        XCTAssertTrue(app.staticTexts["Incline Walk"].exists)
    }

    func testContinueReachesQuickStartAndHonestProfileCopy() {
        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 8))
        app.buttons["addOnboardingMeasurements"].tap()
        XCTAssertTrue(app.buttons["continueOnboarding"].waitForExistence(timeout: 5))
        app.buttons["continueOnboarding"].tap()

        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 8))
        app.buttons["Settings"].firstMatch.tap()

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["profilePrivacyCopy"].exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "calorie")).firstMatch.exists)
    }
}
