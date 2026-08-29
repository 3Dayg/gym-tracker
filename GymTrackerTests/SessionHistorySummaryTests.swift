import SwiftData
import XCTest
@testable import GymTracker

final class SessionHistorySummaryTests: XCTestCase {
    func testTimedSummaryDoesNotMentionKilograms() {
        var summary = SessionHistorySummary()
        summary.timedRounds = 4
        summary.timedSeconds = 720

        let bits = summary.captionBits(unit: .metric)
        XCTAssertEqual(bits.first, "4 rounds")
        XCTAssertTrue(bits.contains("12 min"))
        XCTAssertFalse(bits.joined().localizedCaseInsensitiveContains("kg"))
        XCTAssertFalse(bits.joined().localizedCaseInsensitiveContains("set"))
    }

    func testStrengthSummaryIncludesSetsAndVolume() {
        var summary = SessionHistorySummary()
        summary.strengthSets = 3
        summary.strengthVolumeKilograms = 1920

        let bits = summary.captionBits(unit: .metric)
        XCTAssertEqual(bits.first, "3 sets")
        XCTAssertTrue(bits.contains { $0.contains("kg") })
        XCTAssertFalse(bits.contains { $0.contains("round") })
    }

    func testCardioSummaryIncludesBlocksTimeAndDistance() {
        var summary = SessionHistorySummary()
        summary.cardioBlocks = 3
        summary.cardioSeconds = 1500
        summary.cardioDistanceKilometers = 2.5

        let bits = summary.captionBits(unit: .metric)
        XCTAssertTrue(bits.contains("3 sets"))
        XCTAssertTrue(bits.contains("25 min"))
        XCTAssertTrue(bits.contains { $0.contains("km") })
    }

    func testMixedCaptionIncludesEveryModality() {
        var summary = SessionHistorySummary()
        summary.strengthSets = 2
        summary.strengthVolumeKilograms = 100
        summary.timedRounds = 1
        summary.timedSeconds = 180
        summary.cardioBlocks = 1
        summary.cardioSeconds = 600
        summary.cardioDistanceKilometers = 1
        summary.skippedCount = 1

        let line = summary.caption(duration: 3600, unit: .metric)
        XCTAssertTrue(line.contains("1h 0m"))
        XCTAssertTrue(line.contains("2 sets"))
        XCTAssertTrue(line.contains("1 round"))
        XCTAssertTrue(line.contains("10 min"))
        XCTAssertTrue(line.contains("1 skipped"))
    }

    func testZeroVolumeStrengthOmitsWeightBit() {
        var summary = SessionHistorySummary()
        summary.strengthSets = 2
        let bits = summary.captionBits(unit: .metric)
        XCTAssertEqual(bits, ["2 sets"])
    }
}

@MainActor
final class SessionHistorySummaryFromSessionTests: XCTestCase {
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

    func testFromTimedSessionDoesNotCountSetsOrKilograms() throws {
        let jumpRope = Exercise(
            name: "Jump Rope",
            muscleGroup: .cardio,
            equipment: .other,
            kind: .timed
        )
        context.insert(jumpRope)
        let session = WorkoutSessionService.startEmptySession(in: context)
        session.planName = "Boxing Conditioning"
        let entry = WorkoutSessionService.addExercise(jumpRope, to: session, in: context)
        WorkoutSessionService.addSet(to: entry)
        for set in entry.sets {
            set.durationSeconds = 180
            set.markCompleted()
        }
        try WorkoutSessionService.finish(session, in: context)

        let summary = SessionHistorySummary.from(session)
        XCTAssertEqual(summary.timedRounds, 2)
        XCTAssertEqual(summary.timedSeconds, 360)
        XCTAssertEqual(summary.strengthSets, 0)
        XCTAssertEqual(summary.strengthVolumeKilograms, 0)
        XCTAssertEqual(summary.cardioBlocks, 0)

        let bits = summary.captionBits(unit: .metric)
        XCTAssertEqual(bits, ["2 rounds", "6 min"])
        XCTAssertFalse(bits.joined().localizedCaseInsensitiveContains("kg"))
        XCTAssertFalse(bits.joined().localizedCaseInsensitiveContains("set"))
    }

    func testFromMixedSessionIncludesEveryModality() throws {
        let bench = Exercise(name: "Bench", muscleGroup: .chest, equipment: .barbell)
        let jumpRope = Exercise(
            name: "Jump Rope",
            muscleGroup: .cardio,
            equipment: .other,
            kind: .timed
        )
        let walk = Exercise(
            name: "Walk",
            muscleGroup: .cardio,
            equipment: .machine,
            kind: .cardio
        )
        context.insert(bench)
        context.insert(jumpRope)
        context.insert(walk)

        let session = WorkoutSessionService.startEmptySession(in: context)
        let strength = WorkoutSessionService.addExercise(bench, to: session, in: context)
        strength.sets.first?.weight = 60
        strength.sets.first?.reps = 5
        strength.sets.first?.markCompleted()
        let timed = WorkoutSessionService.addExercise(jumpRope, to: session, in: context)
        timed.sets.first?.durationSeconds = 180
        timed.sets.first?.markCompleted()
        let cardio = WorkoutSessionService.addExercise(walk, to: session, in: context)
        cardio.sets.first?.durationSeconds = 300
        cardio.sets.first?.distance = 0.5
        cardio.sets.first?.markCompleted()
        try WorkoutSessionService.finish(session, in: context)

        let summary = SessionHistorySummary.from(session)
        XCTAssertEqual(summary.strengthSets, 1)
        XCTAssertEqual(summary.strengthVolumeKilograms, 300)
        XCTAssertEqual(summary.timedRounds, 1)
        XCTAssertEqual(summary.timedSeconds, 180)
        XCTAssertEqual(summary.cardioBlocks, 1)
        XCTAssertEqual(summary.cardioSeconds, 300)
        XCTAssertEqual(summary.cardioDistanceKilometers, 0.5)

        let line = summary.caption(duration: session.duration, unit: .metric)
        XCTAssertTrue(line.contains("1 set"))
        XCTAssertTrue(line.contains("1 round"))
        XCTAssertTrue(line.contains("5 min"))
    }
}
