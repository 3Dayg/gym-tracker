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

    func testCompletingCardioDoesNotStartRest() throws {
        let walk = Exercise(
            name: "Treadmill Walk",
            muscleGroup: .cardio,
            equipment: .machine,
            kind: .cardio
        )
        context.insert(walk)
        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(walk, to: session, in: context)
        let set = try XCTUnwrap(entry.orderedSets.first)
        let timer = SessionTimer()
        SetLogging.complete(set, kind: .cardio, timer: timer, restSeconds: 90)
        XCTAssertTrue(set.isCompleted)
        XCTAssertEqual(timer.phase, .idle)
    }

    func testJumpShowsALaterExerciseWhileEarlierWorkIsPending() throws {
        let session = try threeLiftSession()
        let fly = session.orderedExercises[1]
        LiveWorkoutProgress.jump(to: fly, in: session)

        XCTAssertEqual(
            FollowAlongFocus.current(session: session, timerPhase: .idle),
            .currentSet(exerciseName: "Cable Fly", setNumber: 1, setCount: 1, kind: .strength)
        )
        XCTAssertTrue(session.orderedExercises[0].orderedSets[0].isPending)
        XCTAssertEqual(LiveWorkoutProgress.from(session).nextLine, "Next: Cable Fly · Set 1")
    }

    func testCompletingFocusedExerciseReturnsToFirstPending() throws {
        let session = try threeLiftSession()
        LiveWorkoutProgress.jump(to: session.orderedExercises[1], in: session)
        let flySet = try XCTUnwrap(session.orderedExercises[1].orderedSets.first)
        let timer = SessionTimer()
        SetLogging.complete(flySet, kind: .strength, timer: timer, restSeconds: 90)

        XCTAssertNil(session.focusedExerciseSortOrder)
        XCTAssertEqual(
            FollowAlongFocus.current(session: session, timerPhase: .idle),
            .currentSet(exerciseName: "Bench Press", setNumber: 1, setCount: 1, kind: .strength)
        )
    }

    func testExerciseItemsShowPendingVersusComplete() throws {
        let session = try threeLiftSession()
        try XCTUnwrap(session.orderedExercises[0].orderedSets.first).markCompleted()
        let items = LiveWorkoutProgress.exerciseItems(in: session)
        XCTAssertFalse(items[0].hasPending)
        XCTAssertEqual(items[0].caption, "1 of 1")
        XCTAssertTrue(items[1].hasPending)
        XCTAssertTrue(items[1].isFocused)
    }

    private func threeLiftSession() throws -> WorkoutSession {
        let bench = Exercise(name: "Bench Press", muscleGroup: .chest, equipment: .barbell)
        let fly = Exercise(name: "Cable Fly", muscleGroup: .chest, equipment: .cable)
        let incline = Exercise(name: "Incline DB", muscleGroup: .chest, equipment: .dumbbell)
        context.insert(bench)
        context.insert(fly)
        context.insert(incline)
        let session = WorkoutSessionService.startEmptySession(in: context)
        _ = WorkoutSessionService.addExercise(bench, to: session, in: context)
        _ = WorkoutSessionService.addExercise(fly, to: session, in: context)
        _ = WorkoutSessionService.addExercise(incline, to: session, in: context)
        return session
    }
}
