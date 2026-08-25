import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ExerciseSeederTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    /// The seed JSON lives in the app bundle, not the test bundle.
    private let appBundle = Bundle(for: Exercise.self)

    override func setUp() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Exercise.self, WorkoutPlan.self, WorkoutSession.self, BodyMeasurement.self,
            configurations: configuration
        )
        context = container.mainContext
    }

    func testSeedInsertsDefaultExercises() throws {
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)

        let count = try context.fetchCount(FetchDescriptor<Exercise>())
        XCTAssertGreaterThanOrEqual(count, 50)
    }

    func testSeedIsIdempotent() throws {
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)
        let countAfterFirstSeed = try context.fetchCount(FetchDescriptor<Exercise>())

        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)
        let countAfterSecondSeed = try context.fetchCount(FetchDescriptor<Exercise>())

        XCTAssertEqual(countAfterFirstSeed, countAfterSecondSeed)
    }

    func testSeedAddsMissingExercisesFromAnOlderLibrary() throws {
        context.insert(Exercise(name: "Push-Up", muscleGroup: .chest, equipment: .bodyweight))
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)

        let names = Set(try context.fetch(FetchDescriptor<Exercise>()).map(\.name))
        XCTAssertTrue(names.contains("Push-Up"))
        XCTAssertTrue(names.contains("Shadow Boxing"))
        XCTAssertTrue(names.contains("Heavy Bag Rounds"))
        XCTAssertEqual(names.filter { $0 == "Push-Up" }.count, 1, "Existing exercises must not be duplicated")
    }

    func testSeedUpgradesExistingTreadmillExercises() throws {
        context.insert(Exercise(
            name: "Incline Treadmill Walk",
            muscleGroup: .cardio,
            equipment: .machine,
            kind: .strength
        ))
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)

        let walk = try XCTUnwrap(
            try context.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Incline Treadmill Walk" }
        )
        XCTAssertEqual(walk.kind, .cardio)
    }

    func testSeedUpgradesBoxingExercisesToTimed() throws {
        context.insert(Exercise(
            name: "Jump Rope",
            muscleGroup: .cardio,
            equipment: .other,
            kind: .strength
        ))
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)

        let byName = Dictionary(
            uniqueKeysWithValues: try context.fetch(FetchDescriptor<Exercise>()).map { ($0.name, $0) }
        )
        XCTAssertEqual(byName["Jump Rope"]?.kind, .timed)
        XCTAssertEqual(byName["Shadow Boxing"]?.kind, .timed)
        XCTAssertEqual(byName["Heavy Bag Rounds"]?.kind, .timed)
        XCTAssertEqual(byName["Plank"]?.kind, .timed)
        XCTAssertEqual(byName["Push-Up"]?.kind, .strength)
    }

    func testSeedDataIsValid() {
        let seeds = ExerciseSeeder.loadSeedExercises(from: appBundle)

        XCTAssertGreaterThanOrEqual(seeds.count, 50)
        XCTAssertEqual(
            Set(seeds.map(\.name)).count,
            seeds.count,
            "Seed exercise names must be unique"
        )
    }
}
