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

    func testSeedsBoxingConditioningPlans() throws {
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)
        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)

        let plans = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<WorkoutPlan>()).map { ($0.name, $0) }
        )
        XCTAssertNil(plans["Boxing Conditioning"])

        let planA = try XCTUnwrap(plans["Boxing Conditioning A"])
        XCTAssertFalse(planA.notes.isEmpty)
        XCTAssertEqual(planA.targetRestSeconds, 60)
        XCTAssertEqual(planA.orderedExercises.map(\.exerciseName), [
            "Jump Rope", "Push-Up", "Chest Dip", "Bodyweight Squat", "Sit-Up", "Heavy Bag Rounds",
        ])
        XCTAssertTrue(planA.orderedExercises.allSatisfy { $0.exercise != nil })
        XCTAssertEqual(planA.orderedExercises[0].kind, .timed)
        XCTAssertEqual(planA.orderedExercises[0].targetDurationSeconds, 120)
        XCTAssertEqual(planA.orderedExercises[1].targetReps, 15)
        XCTAssertEqual(planA.orderedExercises.last?.targetSets, 5)
        XCTAssertEqual(planA.orderedExercises.last?.targetDurationSeconds, 180)

        let planB = try XCTUnwrap(plans["Boxing Conditioning B"])
        XCTAssertEqual(planB.targetRestSeconds, 60)
        XCTAssertEqual(planB.orderedExercises.map(\.exerciseName), [
            "Stationary Bike", "Pull-Up", "Barbell Shrug", "Neck Isometric", "Plank", "Sprint Intervals",
        ])
        XCTAssertEqual(planB.orderedExercises[0].kind, .cardio)
        XCTAssertEqual(planB.orderedExercises[0].targetDurationSeconds, 540)
        XCTAssertEqual(planB.orderedExercises[3].kind, .timed)
        XCTAssertEqual(planB.orderedExercises[3].targetDurationSeconds, 15)
        XCTAssertEqual(planB.orderedExercises.last?.targetSets, 8)

        let planC = try XCTUnwrap(plans["Boxing Conditioning C"])
        XCTAssertEqual(planC.targetRestSeconds, 60)
        XCTAssertEqual(planC.orderedExercises.map(\.exerciseName), [
            "Jump Rope", "Push-Up", "Bodyweight Squat", "Inverted Row",
            "Russian Twist", "Shadow Boxing", "Heavy Bag Rounds",
        ])
        XCTAssertEqual(planC.orderedExercises[0].targetDurationSeconds, 150)
        XCTAssertEqual(planC.orderedExercises[5].kind, .timed)
        XCTAssertEqual(planC.orderedExercises.last?.targetSets, 4)
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
        XCTAssertNil(walk.targetRestSeconds)
    }

    func testDoesNotRecreateADeletedPlan() throws {
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)
        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)

        let boxing = try XCTUnwrap(
            try context.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.name == "Boxing Conditioning A" }
        )
        context.delete(boxing)
        try context.save()

        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)

        let names = Set(try context.fetch(FetchDescriptor<WorkoutPlan>()).map(\.name))
        XCTAssertFalse(names.contains("Boxing Conditioning A"))
        XCTAssertTrue(names.contains("Boxing Conditioning B"))
        XCTAssertTrue(names.contains("Incline Walk"))
    }

    func testRetiresLegacyBoxingConditioningPlanOnce() throws {
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)
        let legacy = WorkoutPlan(name: "Boxing Conditioning", notes: "Old all-in-one session")
        context.insert(legacy)

        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)
        var names = Set(try context.fetch(FetchDescriptor<WorkoutPlan>()).map(\.name))
        XCTAssertFalse(names.contains("Boxing Conditioning"))
        XCTAssertTrue(names.contains("Boxing Conditioning A"))

        let revived = WorkoutPlan(name: "Boxing Conditioning", notes: "User rebuilt this name")
        context.insert(revived)
        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)
        names = Set(try context.fetch(FetchDescriptor<WorkoutPlan>()).map(\.name))
        XCTAssertTrue(names.contains("Boxing Conditioning"), "A later seed must not delete a plan the user recreated")
    }

    func testSeedPlanExercisesAllExistInTheLibrary() {
        let exerciseNames = Set(ExerciseSeeder.loadSeedExercises(from: appBundle).map(\.name))
        let plans = PlanSeeder.loadSeedPlans(from: appBundle)

        XCTAssertGreaterThanOrEqual(plans.count, 4)
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
