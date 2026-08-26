import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class PlanSeederTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var defaults: UserDefaults!
    private var suiteName: String!

    private let appBundle = Bundle(for: Exercise.self)

    override func setUp() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Exercise.self, WorkoutPlan.self, WorkoutSession.self, BodyMeasurement.self,
            configurations: configuration
        )
        context = container.mainContext
        suiteName = "PlanSeederTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
    }

    func testSeedsBoxingConditioningPlan() throws {
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)
        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)

        let boxing = try XCTUnwrap(
            try context.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.name == "Boxing Conditioning" }
        )

        XCTAssertFalse(boxing.notes.isEmpty)
        XCTAssertEqual(boxing.orderedExercises.count, 9)
        XCTAssertEqual(boxing.orderedExercises.map(\.exerciseName).first, "Jump Rope")
        XCTAssertEqual(boxing.orderedExercises.map(\.exerciseName).last, "Plank")
        XCTAssertTrue(boxing.orderedExercises.allSatisfy { $0.exercise != nil })

        // Timed work carries real durations, not the old reps-as-minutes hack.
        let jumpRope = boxing.orderedExercises[0]
        XCTAssertEqual(jumpRope.kind, .timed)
        XCTAssertEqual(jumpRope.targetDurationSeconds, 180)
        let plank = try XCTUnwrap(boxing.orderedExercises.last)
        XCTAssertEqual(plank.kind, .timed)
        XCTAssertEqual(plank.targetDurationSeconds, 45)
    }

    func testSeedsInclineWalkPlan() throws {
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)
        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)

        let walk = try XCTUnwrap(
            try context.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.name == "Incline Walk" }
        )

        XCTAssertEqual(walk.orderedExercises.count, 3)
        XCTAssertEqual(walk.orderedExercises.map(\.exerciseName), [
            "Treadmill Walk",
            "Incline Treadmill Walk",
            "Treadmill Walk",
        ])
        XCTAssertEqual(walk.orderedExercises[1].targetSets, 3)
        XCTAssertEqual(walk.orderedExercises[1].targetDurationSeconds, 600)
        XCTAssertEqual(walk.orderedExercises[1].targetSpeed, 5)
        XCTAssertEqual(walk.orderedExercises[1].targetIncline, 12)
        XCTAssertEqual(walk.orderedExercises[1].exercise?.kind, .cardio)
    }

    func testDoesNotRecreateADeletedPlan() throws {
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)
        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)

        let boxing = try XCTUnwrap(
            try context.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.name == "Boxing Conditioning" }
        )
        context.delete(boxing)
        try context.save()

        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)

        let names = Set(try context.fetch(FetchDescriptor<WorkoutPlan>()).map(\.name))
        XCTAssertFalse(names.contains("Boxing Conditioning"))
        XCTAssertTrue(names.contains("Incline Walk"))
    }

    func testSeedPlanExercisesAllExistInTheLibrary() {
        let exerciseNames = Set(ExerciseSeeder.loadSeedExercises(from: appBundle).map(\.name))
        let plans = PlanSeeder.loadSeedPlans(from: appBundle)

        XCTAssertGreaterThanOrEqual(plans.count, 2)
        for plan in plans {
            for exercise in plan.exercises {
                XCTAssertTrue(
                    exerciseNames.contains(exercise.name),
                    "Plan '\(plan.name)' references unknown exercise '\(exercise.name)'"
                )
            }
        }
    }
}
