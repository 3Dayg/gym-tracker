import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class LiveWorkoutProgressTests: XCTestCase {
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

    func testEmptySessionHasNoRows() {
        let session = WorkoutSessionService.startEmptySession(in: context)
        let progress = LiveWorkoutProgress.from(session)
        XCTAssertEqual(progress.caption, "No rows yet")
        XCTAssertEqual(progress.nextLine, "Add an exercise to log a set")
    }

    func testNextPointsAtFirstPendingRow() throws {
        let bench = Exercise(name: "Bench Press", muscleGroup: .chest, equipment: .barbell)
        context.insert(bench)
        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(bench, to: session, in: context)
        WorkoutSessionService.addSet(to: entry)
        WorkoutSessionService.addSet(to: entry)
        try XCTUnwrap(entry.orderedSets.first).markCompleted()

        let progress = LiveWorkoutProgress.from(session)
        XCTAssertEqual(progress.loggedCount, 1)
        XCTAssertEqual(progress.totalCount, 3)
        XCTAssertEqual(progress.caption, "1 of 3")
        XCTAssertEqual(progress.nextLine, "Next: Bench Press · Set 2")
        XCTAssertTrue(LiveWorkoutProgress.nextPendingSet(in: session) === entry.orderedSets[1])
    }

    func testSkippedRowsCountAsLogged() throws {
        let rope = Exercise(
            name: "Jump Rope",
            muscleGroup: .cardio,
            equipment: .other,
            kind: .timed
        )
        context.insert(rope)
        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(rope, to: session, in: context)
        try XCTUnwrap(entry.orderedSets.first).markSkipped()

        let progress = LiveWorkoutProgress.from(session)
        XCTAssertEqual(progress.caption, "1 of 1")
        XCTAssertEqual(progress.nextLine, "All rows logged")
        XCTAssertNil(LiveWorkoutProgress.nextPendingSet(in: session))
    }

    func testAddExerciseCopiesFormNotes() {
        let rope = Exercise(
            name: "Jump Rope",
            muscleGroup: .cardio,
            equipment: .other,
            notes: "Stay light on the balls of your feet.",
            kind: .timed
        )
        context.insert(rope)
        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(rope, to: session, in: context)
        XCTAssertEqual(entry.exerciseNotes, "Stay light on the balls of your feet.")
        XCTAssertTrue(LiveWorkoutProgress.nextPendingSet(in: session) === entry.orderedSets.first)
    }
}
