import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class FollowAlongFocusTests: XCTestCase {
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

    override func tearDown() async throws {
        container = nil
        context = nil
    }

    func testEmptySessionIsEmptyFocus() {
        let session = WorkoutSessionService.startEmptySession(in: context)
        XCTAssertEqual(
            FollowAlongFocus.current(session: session, timerPhase: .idle),
            .empty
        )
    }

    func testRestWinsOverTheNextPendingSet() throws {
        let bench = Exercise(name: "Bench Press", muscleGroup: .chest, equipment: .barbell)
        context.insert(bench)
        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(bench, to: session, in: context)
        WorkoutSessionService.addSet(to: entry)
        let first = try XCTUnwrap(entry.orderedSets.first)
        let second = entry.orderedSets[1]
        first.markCompleted()

        XCTAssertEqual(
            FollowAlongFocus.current(session: session, timerPhase: .rest),
            .rest
        )
        XCTAssertTrue(second.isPending)
        XCTAssertFalse(second.isCompleted)
    }

    func testIdleAfterRestShowsTheNextPendingSet() throws {
        let bench = Exercise(name: "Bench Press", muscleGroup: .chest, equipment: .barbell)
        context.insert(bench)
        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(bench, to: session, in: context)
        WorkoutSessionService.addSet(to: entry)
        try XCTUnwrap(entry.orderedSets.first).markCompleted()

        XCTAssertEqual(
            FollowAlongFocus.current(session: session, timerPhase: .idle),
            .currentSet(exerciseName: "Bench Press", setNumber: 2, setCount: 2, kind: .strength)
        )
        XCTAssertTrue(entry.orderedSets[1].isPending)
    }

    func testCompleteLoggingDoesNotInventASet() throws {
        let bench = Exercise(name: "Bench Press", muscleGroup: .chest, equipment: .barbell)
        context.insert(bench)
        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(bench, to: session, in: context)
        let set = try XCTUnwrap(entry.orderedSets.first)
        set.weight = 80
        set.reps = 8

        let timer = SessionTimer()
        SetLogging.complete(set, kind: .strength, timer: timer, restSeconds: 90)

        XCTAssertTrue(set.isCompleted)
        XCTAssertEqual(set.weight, 80)
        XCTAssertEqual(set.reps, 8)
        XCTAssertEqual(timer.phase, .rest)
        XCTAssertEqual(entry.orderedSets.count, 1)
        XCTAssertEqual(
            FollowAlongFocus.current(session: session, timerPhase: timer.phase),
            .rest
        )
    }
}
