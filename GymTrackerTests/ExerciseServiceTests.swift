import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ExerciseServiceTests: XCTestCase {
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

    func testDuplicateNameIsCaseInsensitive() {
        let bench = Exercise(name: "Barbell Bench Press", muscleGroup: .chest, equipment: .barbell)
        context.insert(bench)

        XCTAssertTrue(ExerciseService.isDuplicateName("barbell bench press", in: context))
        XCTAssertFalse(ExerciseService.isDuplicateName("Floor Press", in: context))
        XCTAssertFalse(
            ExerciseService.isDuplicateName("Barbell Bench Press", excluding: bench, in: context)
        )
    }

    func testHasLoggedHistoryWhenSessionExists() {
        let exercise = Exercise(name: "Custom Curl", muscleGroup: .biceps, equipment: .dumbbell, isCustom: true)
        context.insert(exercise)
        XCTAssertFalse(ExerciseService.hasLoggedHistory(exercise))

        let session = WorkoutSessionService.startEmptySession(in: context)
        _ = WorkoutSessionService.addExercise(exercise, to: session, in: context)
        XCTAssertTrue(ExerciseService.hasLoggedHistory(exercise))
    }

    func testDeleteCustomRemovesPlanRowsAndKeepsHistoryName() throws {
        let exercise = Exercise(name: "My Lift", muscleGroup: .chest, equipment: .barbell, isCustom: true)
        context.insert(exercise)
        let plan = WorkoutPlan(name: "Push Day")
        context.insert(plan)
        let planned = PlannedExercise(exercise: exercise, sortOrder: 0)
        planned.plan = plan

        let session = WorkoutSessionService.startEmptySession(in: context)
        let entry = WorkoutSessionService.addExercise(exercise, to: session, in: context)
        entry.sets.first?.markCompleted()
        try WorkoutSessionService.finish(session, in: context)

        XCTAssertEqual(ExerciseService.affectedPlanNames(for: exercise), ["Push Day"])
        ExerciseService.deleteCustom(exercise, in: context)
        try context.save()

        XCTAssertEqual(plan.exercises.count, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 0)
        let kept = try XCTUnwrap(try context.fetch(FetchDescriptor<WorkoutSession>()).first)
        XCTAssertEqual(kept.orderedExercises.first?.exerciseName, "My Lift")
    }

    func testDeleteDoesNotRemoveBuiltIns() {
        let bench = Exercise(name: "Barbell Bench Press", muscleGroup: .chest, equipment: .barbell)
        context.insert(bench)
        ExerciseService.deleteCustom(bench, in: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 1)
    }
}
