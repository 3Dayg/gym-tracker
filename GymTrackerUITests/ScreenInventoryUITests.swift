import XCTest

/// Writes real Simulator PNGs for the screen-inventory board.
/// Skipped in normal CI. Run with:
/// `TEST_RUNNER_CAPTURE_SCREEN_INVENTORY=1 xcodebuild test -only-testing:GymTrackerUITests/ScreenInventoryUITests …`
final class ScreenInventoryUITests: XCTestCase {
    private var app: XCUIApplication!
    private var shots: [Shot] = []

    private struct Shot {
        var file: String
        var title: String
        var flow: String
    }

    override func setUpWithError() throws {
        let marker = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/screen-inventory/.capture")
        try XCTSkipUnless(
            FileManager.default.fileExists(atPath: marker.path),
            "Touch docs/screen-inventory/.capture to write Simulator PNGs"
        )
        continueAfterFailure = true
        app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            for title in ["Allow", "Allow Once", "Don’t Allow", "Don't Allow"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                return true
            }
            return false
        }
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        writeIndex()
    }

    func test01Launch() { captureLaunch() }
    func test02WorkoutHome() { captureWorkoutHomeAndPreview() }
    func test03LiveStrength() { captureLiveStrengthAndRest() }
    func test04TimedAndMap() { captureTimedWorkAndMap() }
    func test05Cardio() { captureCardio() }
    func test06FinishAlerts() { captureFinishAndAlerts() }
    func test07Stale() { captureStaleAndExpired() }
    func test08Plans() { capturePlans() }
    func test09Exercises() { captureExercises() }
    func test10HistoryProgress() { captureHistoryAndProgress() }
    func test11Settings() { captureSettings() }
    func test12Remaining() { captureRemaining() }

    // MARK: - Flows

    private func captureLaunch() {
        relaunch([])
        XCTAssertTrue(app.navigationBars["Welcome"].waitForExistence(timeout: 10))
        shot("welcome", title: "Welcome", flow: "First launch")

        app.buttons["onboardingPrivacyPolicy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 8))
        shot("welcome-privacy", title: "Privacy (from Welcome)", flow: "First launch")
    }

    private func captureWorkoutHomeAndPreview() {
        relaunch(["-skipOnboarding"])
        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 10))
        shot("workout-home", title: "Workout home", flow: "Workout")

        settle()
        shot("workout-home-ready", title: "Workout home", flow: "Workout")

        app.buttons["startPlan-Boxing Conditioning A"].tap()
        XCTAssertTrue(app.staticTexts["planPreviewTitle"].waitForExistence(timeout: 8))
        shot("plan-preview", title: "Plan preview", flow: "Workout")
        app.buttons["cancelPlanPreview"].tap()

        relaunch(["-skipOnboarding", "-seedUnstartablePlans"])
        XCTAssertTrue(app.buttons["startPlan-Empty Template"].waitForExistence(timeout: 10))
        shot("workout-blocked-plans", title: "Workout home (blocked plans)", flow: "Workout")
        app.buttons["startPlan-Empty Template"].tap()
        XCTAssertTrue(app.staticTexts["planPreviewBlockedReason"].waitForExistence(timeout: 8))
        shot("plan-preview-blocked", title: "Plan preview (blocked)", flow: "Workout")
        app.buttons["cancelPlanPreview"].tap()
    }

    private func captureLiveStrengthAndRest() {
        relaunch(["-skipOnboarding"])
        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 10))
        app.buttons["quickStart"].tap()
        XCTAssertTrue(app.staticTexts["emptyWorkoutHint"].waitForExistence(timeout: 8))
        shot("follow-along-empty", title: "Follow along — empty Quick Start", flow: "Workout")

        app.buttons["addExercise"].tap()
        XCTAssertTrue(app.navigationBars["Choose Exercise"].waitForExistence(timeout: 8))
        shot("choose-exercise", title: "Choose Exercise", flow: "Workout")
        searchAndPick("Barbell Bench Press")

        XCTAssertTrue(app.buttons["followAlongDone"].waitForExistence(timeout: 8))
        app.buttons["addSetToCurrent"].tap()
        settle()
        shot("follow-along-strength", title: "Follow along — strength", flow: "Workout")

        app.buttons["weightValue"].tap()
        XCTAssertTrue(app.navigationBars["Weight"].waitForExistence(timeout: 8) || app.buttons["Done"].waitForExistence(timeout: 4))
        shot("weight-wheel", title: "Weight wheel", flow: "Workout")
        if app.buttons["Done"].exists { app.buttons["Done"].tap() }
        else if app.navigationBars.buttons["Done"].exists { app.navigationBars.buttons["Done"].tap() }

        app.buttons["followAlongDone"].tap()
        XCTAssertTrue(app.buttons["skipRest"].waitForExistence(timeout: 8))
        shot("follow-along-rest", title: "Follow along — rest", flow: "Workout")
        app.buttons["skipRest"].tap()

        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.staticTexts["finishWorkoutTitle"].waitForExistence(timeout: 8))
        shot("finish-confirm", title: "Save this workout?", flow: "Workout")
        tapIf(app.buttons["keepGoing"])

        tapIf(app.buttons["discardWorkout"])
        XCTAssertTrue(app.buttons["confirmDiscard"].waitForExistence(timeout: 8))
        shot("discard-dialog", title: "Discard this workout?", flow: "Workout")
        dismissKeepGoing()
    }

    private func captureTimedWorkAndMap() {
        relaunch(["-skipOnboarding"])
        XCTAssertTrue(app.buttons["startPlan-Boxing Conditioning A"].waitForExistence(timeout: 10))
        if app.buttons["dismissOrientation"].exists { app.buttons["dismissOrientation"].tap() }
        app.buttons["startPlan-Boxing Conditioning A"].tap()
        XCTAssertTrue(app.buttons["startPlanFromPreview"].waitForExistence(timeout: 8))
        app.buttons["startPlanFromPreview"].tap()
        XCTAssertTrue(app.buttons["startWork"].waitForExistence(timeout: 10))
        shot("follow-along-timed", title: "Follow along — timed round", flow: "Workout")

        app.buttons["showExerciseMap"].tap()
        XCTAssertTrue(app.navigationBars["Exercises"].waitForExistence(timeout: 8))
        shot("exercise-map", title: "Exercise map", flow: "Workout")
        if app.buttons["exerciseMapRow-0"].exists {
            app.buttons["exerciseMapRow-0"].tap()
        } else {
            app.swipeDown()
        }

        app.buttons["startWork"].firstMatch.tap()
        app.dismissLiveKeyboard("Boxing Conditioning A")
        if app.staticTexts["workPrepCountdown"].waitForExistence(timeout: 3) {
            shot("follow-along-prep", title: "Follow along — 3-2-1", flow: "Workout")
        }
        XCTAssertTrue(app.buttons["pauseWork"].firstMatch.waitForExistence(timeout: 10))
        shot("follow-along-work", title: "Follow along — work countdown", flow: "Workout")
        app.buttons["pauseWork"].firstMatch.tap()
        XCTAssertTrue(app.buttons["resumeWork"].firstMatch.waitForExistence(timeout: 5))
        shot("follow-along-paused", title: "Follow along — work paused", flow: "Workout")
        app.buttons["discardWorkout"].tap()
        if app.buttons["confirmDiscard"].waitForExistence(timeout: 5) {
            app.buttons["confirmDiscard"].firstMatch.tap()
        }
    }

    private func captureCardio() {
        relaunch(["-skipOnboarding"])
        XCTAssertTrue(app.buttons["startPlan-Incline Walk"].waitForExistence(timeout: 10))
        if app.buttons["dismissOrientation"].exists { app.buttons["dismissOrientation"].tap() }
        app.buttons["startPlan-Incline Walk"].tap()
        XCTAssertTrue(app.buttons["startPlanFromPreview"].waitForExistence(timeout: 8))
        app.buttons["startPlanFromPreview"].tap()
        XCTAssertTrue(app.buttons["startWork"].waitForExistence(timeout: 10))
        shot("follow-along-cardio", title: "Follow along — cardio", flow: "Workout")
        app.buttons["discardWorkout"].tap()
        if app.buttons["confirmDiscard"].waitForExistence(timeout: 5) {
            app.buttons["confirmDiscard"].firstMatch.tap()
        }
    }

    private func captureFinishAndAlerts() {
        relaunch(["-skipOnboarding"])
        XCTAssertTrue(app.buttons["quickStart"].waitForExistence(timeout: 10))
        if app.buttons["dismissOrientation"].exists { app.buttons["dismissOrientation"].tap() }
        app.buttons["quickStart"].tap()
        XCTAssertTrue(app.buttons["addExercise"].waitForExistence(timeout: 8))
        app.buttons["addExercise"].tap()
        searchAndPick("Barbell Bench Press")
        XCTAssertTrue(app.buttons["skipSet"].waitForExistence(timeout: 8))
        app.buttons["skipSet"].tap()
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.alerts["Nothing to save"].waitForExistence(timeout: 8))
        shot("nothing-to-save", title: "Nothing to save", flow: "Workout")
        app.alerts["Nothing to save"].buttons["OK"].tap()
        app.buttons["discardWorkout"].tap()
        if app.buttons["confirmDiscard"].waitForExistence(timeout: 5) {
            app.buttons["confirmDiscard"].firstMatch.tap()
        }

        relaunch(["-seedFinishableWorkout"])
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 10))
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["confirmFinish"].waitForExistence(timeout: 8))
        app.buttons["confirmFinish"].tap()
        XCTAssertTrue(app.navigationBars["Workout saved"].waitForExistence(timeout: 8))
        shot("workout-saved", title: "Workout saved", flow: "Workout")
        app.buttons["savedDone"].tap()

        relaunch(["-seedFinishableWorkout", "-failFinishSave"])
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 10))
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["confirmFinish"].waitForExistence(timeout: 8))
        app.buttons["confirmFinish"].tap()
        XCTAssertTrue(app.buttons["retrySaveWorkout"].waitForExistence(timeout: 8))
        shot("save-failed", title: "Couldn’t save workout", flow: "Workout")
        app.buttons["keepGoingAfterSaveError"].tap()
        app.buttons["discardWorkout"].tap()
        if app.buttons["confirmDiscard"].waitForExistence(timeout: 5) {
            app.buttons["confirmDiscard"].firstMatch.tap()
        }
    }

    private func captureStaleAndExpired() {
        relaunch(["-seedStaleWorkout"])
        XCTAssertTrue(app.buttons["resumeStaleWorkout"].waitForExistence(timeout: 10))
        shot("stale-workout", title: "Workout open a long time", flow: "Workout")
        app.buttons["discardStaleWorkout"].tap()

        relaunch(["-restoreRest", "45"])
        XCTAssertTrue(app.waitForLiveSession("Boxing Conditioning"))
        app.dismissLiveKeyboard("Boxing Conditioning")
        XCTAssertTrue(app.staticTexts["restBarCountdown"].waitForExistence(timeout: 8))
        shot("rest-restored", title: "Rest restored after relaunch", flow: "Workout")
        app.buttons["discardWorkout"].tap()
        if app.buttons["confirmDiscard"].waitForExistence(timeout: 5) {
            app.buttons["confirmDiscard"].firstMatch.tap()
        }

        relaunch(["-restoreExpiredWork"])
        XCTAssertTrue(app.alerts["Round finished"].waitForExistence(timeout: 10))
        shot("round-finished-alert", title: "Round finished (app closed)", flow: "Workout")
        app.alerts["Round finished"].buttons["OK"].tap()
        app.buttons["discardWorkout"].tap()
        if app.buttons["confirmDiscard"].waitForExistence(timeout: 5) {
            app.buttons["confirmDiscard"].firstMatch.tap()
        }
    }

    private func capturePlans() {
        relaunch(["-skipOnboarding", "-emptyPlans"])
        XCTAssertTrue(app.tabBars.buttons["Plans"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Plans"].tap()
        XCTAssertTrue(app.buttons["emptyPlansCreatePlan"].waitForExistence(timeout: 8))
        shot("plans-empty", title: "Plans empty", flow: "Plans")

        relaunch(["-skipOnboarding"])
        XCTAssertTrue(app.tabBars.buttons["Plans"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Plans"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["planRow-Boxing Conditioning A"].waitForExistence(timeout: 8))
        shot("plans-list", title: "Plans list", flow: "Plans")

        app.buttons["newPlan"].tap()
        XCTAssertTrue(app.navigationBars["New Plan"].waitForExistence(timeout: 8))
        shot("plan-create", title: "New plan (draft)", flow: "Plans")

        app.buttons["emptyPlanAddExercise"].tap()
        XCTAssertTrue(app.navigationBars["Choose Exercises"].waitForExistence(timeout: 8))
        if app.staticTexts["Arnold Press"].waitForExistence(timeout: 8) {
            app.staticTexts["Arnold Press"].tap()
        }
        shot("choose-exercises-multi", title: "Choose Exercises", flow: "Plans")
        if app.buttons["confirmAddExercises"].exists {
            app.buttons["confirmAddExercises"].tap()
        } else if app.buttons["Add 1"].exists {
            app.buttons["Add 1"].tap()
        } else {
            app.buttons["Cancel"].tap()
            app.buttons["cancelCreatePlan"].tap()
            openBoxingEditor()
            return
        }
        XCTAssertTrue(app.navigationBars["New Plan"].waitForExistence(timeout: 8))
        shot("plan-create-with-exercise", title: "New plan with an exercise", flow: "Plans")
        app.buttons["cancelCreatePlan"].tap()

        openBoxingEditor()

        let boxing = app.descendants(matching: .any)["planRow-Boxing Conditioning A"]
        if boxing.waitForExistence(timeout: 5) {
            boxing.swipeLeft()
            if app.buttons["deletePlan"].waitForExistence(timeout: 5) {
                app.buttons["deletePlan"].tap()
                XCTAssertTrue(app.buttons["keepPlan"].waitForExistence(timeout: 8))
                shot("delete-plan", title: "Delete this plan?", flow: "Plans")
                app.buttons["keepPlan"].tap()
            }
        }
    }

    private func openBoxingEditor() {
        XCTAssertTrue(app.tabBars.buttons["Plans"].waitForExistence(timeout: 8))
        app.tabBars.buttons["Plans"].tap()
        let boxing = app.descendants(matching: .any)["planRow-Boxing Conditioning A"]
        XCTAssertTrue(boxing.waitForExistence(timeout: 8))
        boxing.tap()
        XCTAssertTrue(app.navigationBars["Boxing Conditioning A"].waitForExistence(timeout: 8))
        shot("plan-editor", title: "Plan editor", flow: "Plans")
        app.navigationBars.buttons["Plans"].tap()
    }

    private func captureExercises() {
        relaunch(["-skipOnboarding"])
        XCTAssertTrue(app.tabBars.buttons["Exercises"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Exercises"].tap()
        XCTAssertTrue(app.navigationBars["Exercises"].waitForExistence(timeout: 8))
        shot("exercise-list", title: "Exercise library", flow: "Exercises")

        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 5) {
            search.tap()
            search.typeText("Barbell Bench Press")
            settle()
            if app.staticTexts["Barbell Bench Press"].waitForExistence(timeout: 8) {
                app.staticTexts["Barbell Bench Press"].tap()
                XCTAssertTrue(app.navigationBars["Barbell Bench Press"].waitForExistence(timeout: 8))
                shot("exercise-detail", title: "Exercise detail", flow: "Exercises")
                app.navigationBars.buttons["Exercises"].tap()
            }
        }

        XCTAssertTrue(app.buttons["Add Exercise"].waitForExistence(timeout: 8))
        app.buttons["Add Exercise"].firstMatch.tap()
        XCTAssertTrue(app.textFields["exerciseNameField"].waitForExistence(timeout: 8))
        shot("new-exercise", title: "New Exercise", flow: "Exercises")
        app.textFields["exerciseNameField"].tap()
        app.textFields["exerciseNameField"].typeText("Barbell Bench Press")
        app.buttons["saveExercise"].tap()
        XCTAssertTrue(app.alerts["Name already used"].waitForExistence(timeout: 8))
        shot("duplicate-name", title: "Name already used", flow: "Exercises")
        app.alerts["Name already used"].buttons["OK"].tap()
        app.buttons["Cancel"].tap()
    }

    private func captureHistoryAndProgress() {
        relaunch(["-skipOnboarding"])
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 10))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.buttons["emptyHistoryStartWorkout"].waitForExistence(timeout: 8))
        shot("history-empty", title: "History empty", flow: "History")

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.buttons["emptyProgressStartWorkout"].waitForExistence(timeout: 8))
        shot("progress-empty", title: "Progress empty", flow: "Progress")

        relaunch(["-seedHistorySummaries", "-seedBodyWeight"])
        XCTAssertTrue(app.tabBars.buttons["History"].waitForExistence(timeout: 10))
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["historySummary-Push Day"].waitForExistence(timeout: 8))
        shot("history-list", title: "History list", flow: "History")

        app.buttons["historyRow-Push Day"].tap()
        XCTAssertTrue(app.staticTexts["Total volume"].waitForExistence(timeout: 8))
        shot("session-detail", title: "Session detail", flow: "History")
        app.navigationBars.buttons["History"].tap()

        let mixed = app.staticTexts["historySummary-Mixed Day"]
        if mixed.waitForExistence(timeout: 5) {
            mixed.swipeLeft()
            if app.buttons["deleteHistoryWorkout"].waitForExistence(timeout: 5) {
                app.buttons["deleteHistoryWorkout"].tap()
                XCTAssertTrue(app.buttons["cancelDeleteHistory"].waitForExistence(timeout: 8))
                shot("delete-history", title: "Delete this workout?", flow: "History")
                app.buttons["cancelDeleteHistory"].tap()
            }
        }

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.buttons["chooseProgressExercise"].waitForExistence(timeout: 8))
        shot("progress-strength", title: "Progress — strength", flow: "Progress")

        app.buttons["chooseProgressExercise"].tap()
        XCTAssertTrue(app.navigationBars["Exercise"].waitForExistence(timeout: 8))
        shot("progress-choose-exercise", title: "Choose logged exercise", flow: "Progress")
        if app.buttons["selectProgressExercise-Treadmill Walk"].waitForExistence(timeout: 5) {
            app.buttons["selectProgressExercise-Treadmill Walk"].tap()
            settle()
            shot("progress-cardio", title: "Progress — cardio", flow: "Progress")
        }

        app.buttons["chooseProgressExercise"].tap()
        if app.buttons["selectProgressExercise-Jump Rope"].waitForExistence(timeout: 8) {
            app.buttons["selectProgressExercise-Jump Rope"].tap()
            settle()
            shot("progress-timed", title: "Progress — timed", flow: "Progress")
        } else if app.navigationBars["Exercise"].exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }

        XCTAssertTrue(app.buttons["Log Body Weight"].waitForExistence(timeout: 8))
        app.buttons["Log Body Weight"].tap()
        XCTAssertTrue(app.navigationBars["Log Body Weight"].waitForExistence(timeout: 8))
        shot("log-body-weight", title: "Log Body Weight", flow: "Progress")
        app.buttons["Cancel"].tap()

        if app.buttons["All entries"].waitForExistence(timeout: 5) {
            app.buttons["All entries"].tap()
            XCTAssertTrue(app.navigationBars["Body Weight"].waitForExistence(timeout: 8))
            shot("body-weight-history", title: "Body weight entries", flow: "Progress")
        }
    }

    private func captureSettings() {
        relaunch(["-skipOnboarding", "-seedBodyWeight"])
        XCTAssertTrue(app.buttons["Settings"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 8))
        shot("settings", title: "Settings", flow: "Settings")

        app.buttons["privacyPolicy"].tap()
        XCTAssertTrue(app.navigationBars["Privacy"].waitForExistence(timeout: 8))
        shot("settings-privacy", title: "Privacy", flow: "Settings")
        app.navigationBars.buttons["Settings"].tap()

        app.swipeUp()
        app.swipeUp()
        XCTAssertTrue(app.buttons["deleteAllData"].waitForExistence(timeout: 8))
        shot("settings-data", title: "Settings — data & privacy", flow: "Settings")
        app.buttons["deleteAllData"].tap()
        XCTAssertTrue(app.navigationBars["Delete all data?"].waitForExistence(timeout: 8))
        shot("delete-all-data", title: "Delete all data?", flow: "Settings")
        app.buttons["keepAllData"].tap()
    }

    private func captureRemaining() {
        relaunch(["-seedFinishableWorkout"])
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 10))
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["confirmFinish"].waitForExistence(timeout: 8))
        app.buttons["confirmFinish"].tap()
        XCTAssertTrue(app.navigationBars["Workout saved"].waitForExistence(timeout: 8))
        shot("workout-saved", title: "Workout saved", flow: "Workout")
        tapIf(app.buttons["savedDone"])

        relaunch(["-seedFinishableWorkout", "-failFinishSave"])
        XCTAssertTrue(app.buttons["finishWorkout"].waitForExistence(timeout: 10))
        app.buttons["finishWorkout"].tap()
        XCTAssertTrue(app.buttons["confirmFinish"].waitForExistence(timeout: 8))
        app.buttons["confirmFinish"].tap()
        XCTAssertTrue(app.buttons["retrySaveWorkout"].waitForExistence(timeout: 8))
        shot("save-failed", title: "Couldn’t save workout", flow: "Workout")
        tapIf(app.buttons["keepGoingAfterSaveError"])

        relaunch(["-restoreExpiredWork"])
        XCTAssertTrue(app.alerts["Round finished"].waitForExistence(timeout: 10))
        shot("round-finished-alert", title: "Round finished (app closed)", flow: "Workout")
        tapIf(app.alerts["Round finished"].buttons["OK"])

        relaunch(["-skipOnboarding"])
        XCTAssertTrue(app.tabBars.buttons["Exercises"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Exercises"].tap()
        let add = app.navigationBars["Exercises"].buttons["Add Exercise"]
        XCTAssertTrue(add.waitForExistence(timeout: 8) || app.buttons.matching(NSPredicate(format: "label == %@", "Add Exercise")).firstMatch.waitForExistence(timeout: 4))
        if add.exists {
            add.tap()
        } else {
            app.buttons.matching(NSPredicate(format: "label == %@", "Add Exercise")).firstMatch.tap()
        }
        XCTAssertTrue(app.textFields["exerciseNameField"].waitForExistence(timeout: 8))
        shot("new-exercise", title: "New Exercise", flow: "Exercises")
        app.textFields["exerciseNameField"].tap()
        app.textFields["exerciseNameField"].typeText("Barbell Bench Press")
        tapIf(app.buttons["saveExercise"])
        XCTAssertTrue(app.alerts["Name already used"].waitForExistence(timeout: 8))
        shot("duplicate-name", title: "Name already used", flow: "Exercises")
        tapIf(app.alerts["Name already used"].buttons["OK"])
        tapIf(app.buttons["Cancel"])

        relaunch(["-seedHistorySummaries", "-seedBodyWeight"])
        XCTAssertTrue(app.tabBars.buttons["Progress"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Progress"].tap()
        let logWeight = app.buttons.matching(NSPredicate(format: "label == %@", "Log Body Weight")).firstMatch
        XCTAssertTrue(logWeight.waitForExistence(timeout: 8))
        app.swipeUp()
        logWeight.tap()
        XCTAssertTrue(app.navigationBars["Log Body Weight"].waitForExistence(timeout: 8))
        shot("log-body-weight", title: "Log Body Weight", flow: "Progress")
        tapIf(app.buttons["Cancel"])
        let allEntries = app.buttons.matching(NSPredicate(format: "label == %@", "All entries")).firstMatch
        if allEntries.waitForExistence(timeout: 5) {
            allEntries.tap()
            XCTAssertTrue(app.navigationBars["Body Weight"].waitForExistence(timeout: 8))
            shot("body-weight-history", title: "Body weight entries", flow: "Progress")
        }
    }

    // MARK: - Helpers

    @discardableResult
    private func tapIf(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        element.tap()
        return true
    }

    private func dismissKeepGoing() {
        let labeled = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Keep Going")
        ).firstMatch
        if tapIf(labeled, timeout: 3) { return }
        tapIf(app.buttons["keepGoing"], timeout: 2)
    }

    private func relaunch(_ extra: [String]) {
        if app.state != .notRunning {
            app.terminate()
        }
        app = XCUIApplication()
        app.launchArguments = ["-inMemoryStore"] + extra
        app.launch()
        settle(0.6)
    }

    private func searchAndPick(_ name: String) {
        XCTAssertTrue(app.navigationBars["Choose Exercise"].waitForExistence(timeout: 8))
        let search = app.textFields["searchExercises"]
        XCTAssertTrue(search.waitForExistence(timeout: 8))
        search.tap()
        search.typeText(name)
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 8))
        app.staticTexts[name].tap()
    }

    private func shot(_ file: String, title: String, flow: String) {
        settle()
        let url = outputDir.appendingPathComponent("\(file).png")
        do {
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
            let meta = outputDir.appendingPathComponent("\(file).json")
            let payload = "{\"file\":\"\(file)\",\"title\":\"\(escape(title))\",\"flow\":\"\(escape(flow))\"}"
            if let data = payload.data(using: .utf8) {
                try data.write(to: meta)
            }
            shots.removeAll { $0.file == file }
            shots.append(Shot(file: file, title: title, flow: flow))
        } catch {
            XCTFail("Could not write \(file).png: \(error)")
        }
    }

    private func settle(_ seconds: TimeInterval = 0.45) {
        RunLoop.current.run(until: Date().addingTimeInterval(seconds))
    }

    private var outputDir: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("docs/screen-inventory/captures")
    }

    private var indexURL: URL {
        outputDir.deletingLastPathComponent().appendingPathComponent("index.html")
    }

    private func writeIndex() {
        let jsons = (try? FileManager.default.contentsOfDirectory(
            at: outputDir,
            includingPropertiesForKeys: nil
        ))?.filter { $0.pathExtension == "json" } ?? []
        let allShots: [Shot] = jsons.compactMap { url in
            guard
                let data = try? Data(contentsOf: url),
                let obj = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                let file = obj["file"],
                let title = obj["title"],
                let flow = obj["flow"]
            else { return nil }
            return Shot(file: file, title: title, flow: flow)
        }.sorted { $0.file < $1.file }
        guard !allShots.isEmpty else { return }
        let flows = ["First launch", "Workout", "Plans", "Exercises", "History", "Progress", "Settings"]
        var sections = ""
        for flow in flows {
            let items = allShots.filter { $0.flow == flow }
            guard !items.isEmpty else { continue }
            let cards = items.map { shot in
                """
                <figure>
                  <div class="phone"><img src="captures/\(shot.file).png" alt="\(escape(shot.title))"></div>
                  <figcaption>\(escape(shot.title))</figcaption>
                </figure>
                """
            }.joined(separator: "\n")
            sections += """
            <section>
              <h2>\(flow)</h2>
              <div class="board">\(cards)</div>
            </section>
            """
        }

        let html = """
        <!doctype html>
        <html lang="en">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>Gym Tracker — screen inventory</title>
          <style>
            :root { color-scheme: light; }
            * { box-sizing: border-box; }
            body {
              margin: 0;
              font: 14px/1.4 -apple-system, BlinkMacSystemFont, sans-serif;
              color: #111;
              background: #ececec;
            }
            header {
              padding: 28px 32px 8px;
              max-width: 1400px;
            }
            h1 { font-size: 22px; font-weight: 650; margin: 0 0 6px; }
            h2 { font-size: 16px; font-weight: 650; margin: 0 0 14px; }
            p { color: #555; margin: 0; max-width: 720px; }
            section { padding: 20px 32px 8px; }
            .board {
              display: grid;
              grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
              gap: 28px 20px;
              align-items: start;
            }
            figure { margin: 0; }
            .phone {
              background: #111;
              border-radius: 28px;
              padding: 10px;
              line-height: 0;
            }
            .phone img {
              width: 100%;
              height: auto;
              border-radius: 20px;
              display: block;
              background: #fff;
            }
            figcaption {
              margin-top: 8px;
              font-size: 12px;
              font-weight: 600;
              color: #222;
            }
          </style>
        </head>
        <body>
          <header>
            <h1>Gym Tracker — existing screens</h1>
            <p>Real Simulator captures of every primary screen, sheet, and alert. Use this board as the baseline for a later improvement pass.</p>
          </header>
          \(sections)
        </body>
        </html>
        """
        try? html.write(to: indexURL, atomically: true, encoding: .utf8)
    }

    private func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
