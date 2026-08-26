import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class PlanStartSummaryTests: XCTestCase {
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
        suiteName = "PlanStartSummaryTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        container = nil
        context = nil
    }

    func testSeededBoxingSummaryIsStartableWithWorkAndRest() throws {
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)
        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)
        let boxing = try XCTUnwrap(
            try context.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.name == "Boxing Conditioning" }
        )

        let summary = PlanStartSummary.from(boxing)
        XCTAssertTrue(summary.canStart)
        XCTAssertEqual(summary.startableExerciseCount, 9)
        XCTAssertEqual(summary.strengthSets, 16)
        XCTAssertEqual(summary.timedRounds, 15)
        XCTAssertEqual(summary.cardioBlocks, 0)
        XCTAssertEqual(summary.knownWorkSeconds, 2295)
        XCTAssertEqual(summary.restSeconds, 60)
        XCTAssertTrue(summary.notes.contains("Tap Start on a timed round"))
        XCTAssertTrue(summary.listCaption().contains("9 exercises"))
        XCTAssertTrue(summary.listCaption().contains("38:15 min work"))
        XCTAssertTrue(summary.listCaption().contains("1:00 rest"))
        XCTAssertTrue(summary.detailBits().contains("16 sets"))
        XCTAssertTrue(summary.detailBits().contains("15 rounds"))
    }

    func testSeededInclineWalkSummaryUsesBlocksAndWorkTime() throws {
        ExerciseSeeder.seedIfNeeded(in: context, bundle: appBundle)
        PlanSeeder.seedIfNeeded(in: context, bundle: appBundle, defaults: defaults)
        let walk = try XCTUnwrap(
            try context.fetch(FetchDescriptor<WorkoutPlan>()).first { $0.name == "Incline Walk" }
        )

        let summary = PlanStartSummary.from(walk)
        XCTAssertTrue(summary.canStart)
        XCTAssertEqual(summary.startableExerciseCount, 3)
        XCTAssertEqual(summary.cardioBlocks, 5)
        XCTAssertEqual(summary.knownWorkSeconds, 2400)
        XCTAssertNil(summary.restSeconds)
        XCTAssertTrue(summary.notes.contains("keep walking"))
        XCTAssertTrue(summary.listCaption().contains("3 exercises"))
        XCTAssertTrue(summary.listCaption().contains("40 min work"))
        XCTAssertTrue(summary.detailBits().contains("5 blocks"))
    }

    func testEmptyPlanCannotStart() {
        let plan = WorkoutPlan(name: "Empty Template")
        context.insert(plan)
        let summary = PlanStartSummary.from(plan)
        XCTAssertFalse(summary.canStart)
        XCTAssertTrue(summary.listCaption().contains("Can't start"))
        XCTAssertTrue(summary.blockedReason.contains("empty"))
    }

    func testPlanWithOnlyDeletedExercisesCannotStart() throws {
        let gone = Exercise(name: "Gone", muscleGroup: .chest, equipment: .barbell, isCustom: true)
        context.insert(gone)
        let plan = WorkoutPlan(name: "Broken Plan")
        context.insert(plan)
        let planned = PlannedExercise(exercise: gone, sortOrder: 0)
        planned.plan = plan
        context.delete(gone)
        try context.save()

        let summary = PlanStartSummary.from(plan)
        XCTAssertEqual(summary.startableExerciseCount, 0)
        XCTAssertEqual(summary.missingExerciseCount, 1)
        XCTAssertFalse(summary.canStart)
        XCTAssertTrue(summary.blockedReason.contains("deleted"))
    }
}
