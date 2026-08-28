import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class WorkoutSessionServiceTests: XCTestCase {
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

    // MARK: - Helpers

    private func makeExercise(_ name: String = "Bench Press") -> Exercise {
        let exercise = Exercise(name: name, muscleGroup: .chest, equipment: .barbell)
        context.insert(exercise)
        return exercise
    }

    private func makePlan(exercise: Exercise, sets: Int = 3, reps: Int = 8, weight: Double? = 80) -> WorkoutPlan {
        let plan = WorkoutPlan(name: "Push Day")
        context.insert(plan)
        let planned = PlannedExercise(
            exercise: exercise,
            sortOrder: 0,
            targetSets: sets,
            targetReps: reps,
            targetWeight: weight
        )
        planned.plan = plan
        return plan
    }

    // MARK: - Starting sessions

    func testStartSessionFromPlanPrefillsTargets() throws {
        let exercise = makeExercise()
        let plan = makePlan(exercise: exercise, sets: 3, reps: 8, weight: 80)

        let session = WorkoutSessionService.startSession(from: plan, in: context)

        XCTAssertEqual(session.planName, "Push Day")
        XCTAssertNil(session.endedAt)
        XCTAssertEqual(session.exercises.count, 1)

        let sets = try XCTUnwrap(session.orderedExercises.first).orderedSets
        XCTAssertEqual(sets.count, 3)
        XCTAssertTrue(sets.allSatisfy { $0.reps == 8 && $0.weight == 80 && !$0.isCompleted })
    }

    func testStartSessionCopiesPlanNotes() {
        let exercise = makeExercise()
        let plan = makePlan(exercise: exercise)
        plan.notes = "Aim for 2–3 sessions a week."

        let session = WorkoutSessionService.startSession(from: plan, in: context)

        XCTAssertEqual(session.planNotes, "Aim for 2–3 sessions a week.")
    }

    func testStartSessionFallsBackToLastUsedWeight() throws {
        let exercise = makeExercise()

        // A previous finished session where the user lifted 92.5.
        let previous = WorkoutSessionService.startEmptySession(in: context)
        let previousExercise = WorkoutSessionService.addExercise(exercise, to: previous, in: context)
        let previousSet = try XCTUnwrap(previousExercise.orderedSets.first)
        previousSet.weight = 92.5
        previousSet.isCompleted = true
        try WorkoutSessionService.finish(previous, in: context)

        // A plan without an explicit target weight.
        let plan = makePlan(exercise: exercise, weight: nil)
        let session = WorkoutSessionService.startSession(from: plan, in: context)

        let sets = try XCTUnwrap(session.orderedExercises.first).orderedSets
        XCTAssertTrue(sets.allSatisfy { $0.weight == 92.5 })
    }

    // MARK: - Editing a running session

    func testAddSetCopiesRepsAndWeightFromLastSet() throws {
        let exercise = makeExercise()
        let session = WorkoutSessionService.startEmptySession(in: context)
        let sessionExercise = WorkoutSessionService.addExercise(exercise, to: session, in: context)

        let firstSet = try XCTUnwrap(sessionExercise.orderedSets.first)
        firstSet.reps = 5
        firstSet.weight = 100

        let newSet = WorkoutSessionService.addSet(to: sessionExercise)

        XCTAssertEqual(newSet.reps, 5)
        XCTAssertEqual(newSet.weight, 100)
        XCTAssertEqual(sessionExercise.orderedSets.count, 2)
        XCTAssertEqual(sessionExercise.orderedSets.last?.sortOrder, newSet.sortOrder)
    }

    // MARK: - Finishing

    func testFinishDiscardsIncompleteSetsAndEmptyExercises() throws {
        let benchPress = makeExercise("Bench Press")
        let squat = makeExercise("Back Squat")
        let session = WorkoutSessionService.startEmptySession(in: context)

        // Bench: one completed set, one untouched set.
        let benchEntry = WorkoutSessionService.addExercise(benchPress, to: session, in: context)
        try XCTUnwrap(benchEntry.orderedSets.first).isCompleted = true
        WorkoutSessionService.addSet(to: benchEntry)

        // Squat: added but never logged.
        WorkoutSessionService.addExercise(squat, to: session, in: context)

        try WorkoutSessionService.finish(session, in: context)

        XCTAssertNotNil(session.endedAt)
        XCTAssertEqual(session.exercises.count, 1)
        XCTAssertEqual(session.exercises.first?.exerciseName, "Bench Press")
        XCTAssertEqual(session.exercises.first?.sets.count, 1)
        XCTAssertTrue(session.isFinished)
    }

    func testFinishPreviewCountsCompletedSkippedAndIncomplete() throws {
        let exercise = makeExercise()
        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(exercise, to: session, in: context)
        let first = try XCTUnwrap(entry.orderedSets.first)
        first.markCompleted()
        let skipped = WorkoutSessionService.addSet(to: entry)
        skipped.markSkipped()
        let failed = WorkoutSessionService.addSet(to: entry)
        failed.reps = 4
        failed.markCompleted(failed: true)
        WorkoutSessionService.addSet(to: entry)

        let preview = WorkoutSessionService.finishPreview(for: session)
        XCTAssertEqual(preview.completedCount, 2)
        XCTAssertEqual(preview.failedCount, 1)
        XCTAssertEqual(preview.skippedCount, 1)
        XCTAssertEqual(preview.incompleteCount, 1)
        XCTAssertTrue(preview.canSave)
    }

    func testFinishKeepsSkippedAndFailedAndDropsIncomplete() throws {
        let exercise = makeExercise()
        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(exercise, to: session, in: context)
        let first = try XCTUnwrap(entry.orderedSets.first)
        first.weight = 80
        first.reps = 8
        first.markCompleted()
        let skipped = WorkoutSessionService.addSet(to: entry)
        skipped.markSkipped()
        let failed = WorkoutSessionService.addSet(to: entry)
        failed.weight = 80
        failed.reps = 3
        failed.markCompleted(failed: true)
        WorkoutSessionService.addSet(to: entry)

        try WorkoutSessionService.finish(session, in: context)

        let sets = try XCTUnwrap(session.orderedExercises.first).orderedSets
        XCTAssertEqual(sets.count, 3)
        XCTAssertEqual(sets.filter(\.isCompleted).count, 2)
        XCTAssertEqual(sets.filter(\.isSkipped).count, 1)
        XCTAssertEqual(sets.filter(\.isFailed).count, 1)
        XCTAssertEqual(sets.filter(\.isFailed).first?.reps, 3)
        XCTAssertTrue(sets.allSatisfy { !$0.isPending })
    }

    func testFailedSetsAreExcludedFromProgressSamples() throws {
        let exercise = makeExercise()
        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(exercise, to: session, in: context)
        let failed = try XCTUnwrap(entry.orderedSets.first)
        failed.weight = 200
        failed.reps = 1
        failed.markCompleted(failed: true)
        let good = WorkoutSessionService.addSet(to: entry)
        good.weight = 80
        good.reps = 8
        good.markCompleted()
        try WorkoutSessionService.finish(session, in: context)

        XCTAssertEqual(exercise.completedSetSamples.count, 1)
        XCTAssertEqual(exercise.completedSetSamples.first?.weight, 80)
        XCTAssertEqual(exercise.completedSetSamples.first?.reps, 8)
    }

    func testCancelDeletesTheSession() throws {
        let session = WorkoutSessionService.startEmptySession(in: context)
        WorkoutSessionService.cancel(session, in: context)

        let remaining = try context.fetchCount(FetchDescriptor<WorkoutSession>())
        XCTAssertEqual(remaining, 0)
    }

    // MARK: - Volume

    func testTotalVolumeCountsOnlyCompletedSets() throws {
        let exercise = makeExercise()
        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(exercise, to: session, in: context)

        let set1 = try XCTUnwrap(entry.orderedSets.first)
        set1.reps = 10
        set1.weight = 50
        set1.isCompleted = true

        let set2 = WorkoutSessionService.addSet(to: entry)
        set2.reps = 10
        set2.weight = 50
        // set2 left incomplete.

        XCTAssertEqual(session.totalVolume, 500)
    }

    func testStartCardioSessionPrefillsTimeSpeedInclineAndDistance() throws {
        let exercise = Exercise(
            name: "Incline Treadmill Walk",
            muscleGroup: .cardio,
            equipment: .machine,
            kind: .cardio
        )
        context.insert(exercise)
        let plan = WorkoutPlan(name: "Incline Walk")
        context.insert(plan)
        let planned = PlannedExercise(
            exercise: exercise,
            sortOrder: 0,
            targetSets: 3,
            targetDurationSeconds: 600,
            targetSpeed: 5,
            targetIncline: 12,
            targetDistance: 0.85
        )
        planned.plan = plan

        let session = WorkoutSessionService.startSession(from: plan, in: context)
        let sets = try XCTUnwrap(session.orderedExercises.first).orderedSets

        XCTAssertEqual(session.orderedExercises.first?.kind, .cardio)
        XCTAssertEqual(sets.count, 3)
        XCTAssertTrue(sets.allSatisfy {
            $0.durationSeconds == 600 && $0.speed == 5 && $0.incline == 12 && $0.distance == 0.85
        })
    }

    func testStartTimedSessionPrefillsRoundDuration() throws {
        let exercise = Exercise(
            name: "Jump Rope",
            muscleGroup: .cardio,
            equipment: .other,
            kind: .timed
        )
        context.insert(exercise)
        let plan = WorkoutPlan(name: "Boxing Conditioning")
        context.insert(plan)
        let planned = PlannedExercise(
            exercise: exercise,
            sortOrder: 0,
            targetSets: 5,
            targetDurationSeconds: 180
        )
        planned.plan = plan

        let session = WorkoutSessionService.startSession(from: plan, in: context)
        let sets = try XCTUnwrap(session.orderedExercises.first).orderedSets

        XCTAssertEqual(session.orderedExercises.first?.kind, .timed)
        XCTAssertEqual(sets.count, 5)
        XCTAssertTrue(sets.allSatisfy { $0.durationSeconds == 180 })
    }

    func testAddTimedExercisePrefillsLastUsedDuration() throws {
        let exercise = Exercise(
            name: "Plank",
            muscleGroup: .core,
            equipment: .bodyweight,
            kind: .timed
        )
        context.insert(exercise)

        // A previous finished session with a 75-second hold.
        let previous = WorkoutSessionService.startEmptySession(in: context)
        let previousExercise = WorkoutSessionService.addExercise(exercise, to: previous, in: context)
        let previousSet = try XCTUnwrap(previousExercise.orderedSets.first)
        previousSet.durationSeconds = 75
        previousSet.isCompleted = true
        try WorkoutSessionService.finish(previous, in: context)

        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(exercise, to: session, in: context)

        XCTAssertEqual(entry.orderedSets.first?.durationSeconds, 75)
    }

    func testRecentlyLoggedOrdersByLastFinishedSession() throws {
        let bench = makeExercise("Bench")
        let squat = makeExercise("Squat")

        let first = WorkoutSessionService.startEmptySession(in: context)
        let firstEntry = WorkoutSessionService.addExercise(bench, to: first, in: context)
        firstEntry.orderedSets.first?.isCompleted = true
        try WorkoutSessionService.finish(first, in: context)
        first.endedAt = Date().addingTimeInterval(-120)

        let second = WorkoutSessionService.startEmptySession(in: context)
        let secondEntry = WorkoutSessionService.addExercise(squat, to: second, in: context)
        secondEntry.orderedSets.first?.isCompleted = true
        try WorkoutSessionService.finish(second, in: context)

        let recent = WorkoutSessionService.recentlyLoggedExercises(from: [bench, squat])
        XCTAssertEqual(recent.map(\.name), ["Squat", "Bench"])
    }

    func testRecentlyLoggedIgnoresUnfinishedSessions() {
        let bench = makeExercise()
        let live = WorkoutSessionService.startEmptySession(in: context)
        _ = WorkoutSessionService.addExercise(bench, to: live, in: context)

        XCTAssertTrue(WorkoutSessionService.recentlyLoggedExercises(from: [bench]).isEmpty)
    }
}
