import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class SessionTimerTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Exercise.self, WorkoutPlan.self, WorkoutSession.self, BodyMeasurement.self,
            configurations: configuration
        )
        context = container.mainContext
    }

    func testWorkCountdownReachesZeroAndReportsTheSet() async throws {
        let set = makeSet(durationSeconds: 1)
        let timer = SessionTimer()
        let finished = expectation(description: "work finished")
        timer.onWorkFinished = { reported in
            XCTAssertTrue(reported === set)
            finished.fulfill()
        }

        timer.startWork(seconds: 1, set: set)
        XCTAssertEqual(timer.phase, .work)
        XCTAssertTrue(timer.isTiming(set))

        await fulfillment(of: [finished], timeout: 3)
        XCTAssertEqual(timer.phase, .idle)
        XCTAssertFalse(timer.isTiming(set))
    }

    func testPauseFreezesRemainingTimeAndResumeContinues() async throws {
        let set = makeSet(durationSeconds: 10)
        let timer = SessionTimer()
        timer.startWork(seconds: 10, set: set)
        timer.pause()

        XCTAssertTrue(timer.isPaused)
        let remaining = timer.remainingSeconds
        XCTAssertGreaterThan(remaining, 0)

        try await Task.sleep(for: .milliseconds(600))
        XCTAssertEqual(timer.remainingSeconds, remaining)

        timer.resume()
        XCTAssertFalse(timer.isPaused)
        XCTAssertEqual(timer.phase, .work)
        XCTAssertTrue(timer.isTiming(set))
        XCTAssertEqual(timer.totalSeconds, 10)
        XCTAssertLessThanOrEqual(timer.remainingSeconds, remaining)
    }

    func testStopDuringWorkDoesNotFinishTheRound() async throws {
        let set = makeSet(durationSeconds: 2)
        let timer = SessionTimer()
        var finished = false
        timer.onWorkFinished = { _ in finished = true }

        timer.startWork(seconds: 2, set: set)
        timer.stop()

        try await Task.sleep(for: .milliseconds(400))
        XCTAssertFalse(finished)
        XCTAssertEqual(timer.phase, .idle)
    }

    func testStartWorkCancelsRest() {
        let set = makeSet(durationSeconds: 5)
        let timer = SessionTimer()
        timer.startRest(seconds: 60)
        XCTAssertEqual(timer.phase, .rest)

        timer.startWork(seconds: 5, set: set)
        XCTAssertEqual(timer.phase, .work)
        XCTAssertTrue(timer.isTiming(set))
    }

    func testStartSessionCopiesPlanRest() {
        let exercise = Exercise(name: "Jump Rope", muscleGroup: .cardio, equipment: .other, kind: .timed)
        context.insert(exercise)
        let plan = WorkoutPlan(name: "Boxing Conditioning", targetRestSeconds: 60)
        context.insert(plan)
        let planned = PlannedExercise(exercise: exercise, sortOrder: 0, targetSets: 1, targetDurationSeconds: 180)
        planned.plan = plan

        let session = WorkoutSessionService.startSession(from: plan, in: context)
        XCTAssertEqual(session.restSeconds, 60)
    }

    private func makeSet(durationSeconds: Int) -> SetEntry {
        let set = SetEntry(sortOrder: 0, durationSeconds: durationSeconds)
        context.insert(set)
        return set
    }
}
