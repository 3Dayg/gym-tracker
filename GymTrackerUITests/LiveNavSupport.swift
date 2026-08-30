import XCTest

extension XCUIApplication {
    /// Live workout hides the system nav bar. Prefer the custom title / Finish.
    func waitForLiveSession(_ title: String, timeout: TimeInterval = 10) -> Bool {
        if buttons["finishWorkout"].waitForExistence(timeout: timeout) { return true }
        if staticTexts["liveWorkoutTitle"].waitForExistence(timeout: 2) { return true }
        return navigationBars[title].waitForExistence(timeout: 2)
    }

    func dismissLiveKeyboard(_ title: String) {
        if staticTexts["liveWorkoutTitle"].exists {
            staticTexts["liveWorkoutTitle"].tap()
        } else if navigationBars[title].exists {
            navigationBars[title].tap()
        }
    }
}
