import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class PlanBuilderTests: XCTestCase {
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

    func testAddExercisesPreservesOrderAndKindDefaults() throws {
        let bench = Exercise(name: "Barbell Bench Press", muscleGroup: .chest, equipment: .barbell)
        let rope = Exercise(name: "Jump Rope", muscleGroup: .cardio, equipment: .other, kind: .timed)
        let walk = Exercise(name: "Treadmill Walk", muscleGroup: .cardio, equipment: .machine, kind: .cardio)
        context.insert(bench)
        context.insert(rope)
        context.insert(walk)

        let plan = WorkoutPlan(name: "Gym Push", isDraft: true)
        context.insert(plan)
        PlanBuilder.addExercises([bench, rope, walk], to: plan, in: context)

        XCTAssertEqual(plan.orderedExercises.map(\.exerciseName), [
            "Barbell Bench Press",
            "Jump Rope",
            "Treadmill Walk",
        ])
        XCTAssertEqual(plan.orderedExercises[0].kind, .strength)
        XCTAssertEqual(plan.orderedExercises[0].targetSets, 3)
        XCTAssertEqual(plan.orderedExercises[1].kind, .timed)
        XCTAssertEqual(plan.orderedExercises[1].targetDurationSeconds, 60)
        XCTAssertEqual(plan.orderedExercises[2].kind, .cardio)
        XCTAssertEqual(plan.orderedExercises[2].targetSets, 1)
        XCTAssertEqual(plan.orderedExercises[2].targetSpeed, SettingsDefaults.walkingSpeedKilometersPerHour)

        let summary = PlanStartSummary.from(plan)
        XCTAssertTrue(summary.canStart)
        XCTAssertEqual(summary.startableExerciseCount, 3)
    }
}
