import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class BackupServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var defaults: UserDefaults!
    private var suiteName: String!
    private let appBundle = Bundle(for: Exercise.self)

    override func setUp() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Exercise.self, WorkoutPlan.self, WorkoutSession.self, BodyMeasurement.self, UserProfile.self,
            configurations: configuration
        )
        context = container.mainContext
        suiteName = "BackupServiceTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        container = nil
        context = nil
    }

    func testJSONExportIncludesFinishedSetAndCustomExercise() throws {
        ProfileService.completeOnboarding(heightCentimeters: 170, weight: 72, in: context)
        let custom = Exercise(
            name: "My Lift",
            muscleGroup: .chest,
            equipment: .barbell,
            isCustom: true
        )
        context.insert(custom)
        let session = WorkoutSessionService.startEmptySession(in: context)
        session.planName = "Push Day"
        let entry = WorkoutSessionService.addExercise(custom, to: session, in: context)
        entry.sets.first?.weight = 80
        entry.sets.first?.reps = 5
        entry.sets.first?.markCompleted()
        try WorkoutSessionService.finish(session, in: context)

        defaults.set(UnitSystem.metric.rawValue, forKey: SettingsKeys.unitSystem)
        let document = BackupService.makeDocument(in: context, defaults: defaults)

        XCTAssertEqual(document.profile?.heightCentimeters, 170)
        XCTAssertEqual(document.bodyMeasurements.first?.weightKilograms, 72)
        XCTAssertEqual(document.customExercises.map(\.name), ["My Lift"])
        XCTAssertEqual(document.sessions.count, 1)
        XCTAssertEqual(document.sessions.first?.exercises.first?.sets.first?.outcome, "completed")
        XCTAssertEqual(document.sessions.first?.exercises.first?.sets.first?.weightKilograms, 80)

        let json = try BackupService.jsonData(from: document)
        let text = try XCTUnwrap(String(data: json, encoding: .utf8))
        XCTAssertTrue(text.contains("My Lift"))
        XCTAssertTrue(text.contains("weightKilograms"))
    }

    func testCSVExportIsReadableAndSkipsPendingRows() throws {
        let exercise = Exercise(name: "Bench Press", muscleGroup: .chest, equipment: .barbell)
        context.insert(exercise)
        let session = WorkoutSessionService.startEmptySession(in: context)
        session.planName = "Push Day"
        let entry = WorkoutSessionService.addExercise(exercise, to: session, in: context)
        WorkoutSessionService.addSet(to: entry)
        entry.orderedSets[0].weight = 100
        entry.orderedSets[0].reps = 5
        entry.orderedSets[0].markCompleted()
        entry.orderedSets[1].markSkipped()
        try WorkoutSessionService.finish(session, in: context)

        let document = BackupService.makeDocument(in: context)
        let csv = BackupService.csvString(from: document)
        XCTAssertTrue(csv.contains("date,plan,exercise,kind,set,reps,weight_kg"))
        XCTAssertTrue(csv.contains("Push Day"))
        XCTAssertTrue(csv.contains("Bench Press"))
        XCTAssertTrue(csv.contains("completed"))
        XCTAssertTrue(csv.contains("skipped"))
        XCTAssertFalse(csv.contains("pending"))
    }

    func testDeleteAllDataWipesUserDataAndReseedsLibrary() throws {
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)
        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)
        ProfileService.completeOnboarding(heightCentimeters: 170, weight: 72, in: context, now: .now)

        let custom = Exercise(name: "My Lift", muscleGroup: .chest, equipment: .barbell, isCustom: true)
        context.insert(custom)
        let session = WorkoutSessionService.startEmptySession(in: context)
        _ = WorkoutSessionService.addExercise(custom, to: session, in: context)
        defaults.set(UnitSystem.imperial.rawValue, forKey: SettingsKeys.unitSystem)
        defaults.set(true, forKey: SettingsKeys.hasDismissedWorkoutOrientation)

        try BackupService.deleteAllData(
            in: context,
            defaults: defaults,
            bundle: appBundle
        )

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BodyMeasurement>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 0)
        XCTAssertEqual(
            try context.fetch(FetchDescriptor<Exercise>()).filter(\.isCustom).count,
            0
        )
        XCTAssertGreaterThan(try context.fetchCount(FetchDescriptor<Exercise>()), 20)
        let planNames = Set(try context.fetch(FetchDescriptor<WorkoutPlan>()).map(\.name))
        XCTAssertTrue(planNames.contains("Boxing Conditioning A"))
        XCTAssertTrue(planNames.contains("Boxing Conditioning B"))
        XCTAssertTrue(planNames.contains("Boxing Conditioning C"))
        XCTAssertTrue(planNames.contains("Incline Walk"))
        XCTAssertNil(defaults.string(forKey: SettingsKeys.unitSystem))
        XCTAssertFalse(defaults.bool(forKey: SettingsKeys.hasDismissedWorkoutOrientation))
    }
}
