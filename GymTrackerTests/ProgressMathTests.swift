import XCTest
@testable import GymTracker

final class ProgressMathTests: XCTestCase {
    // MARK: - Estimated 1RM (Epley)

    func testOneRepMaxForSingleRepIsTheWeightItself() {
        XCTAssertEqual(ProgressMath.estimatedOneRepMax(weight: 100, reps: 1), 100)
    }

    func testOneRepMaxUsesEpleyFormula() {
        // 100 kg x 10 reps -> 100 * (1 + 10/30) = 133.33
        XCTAssertEqual(
            ProgressMath.estimatedOneRepMax(weight: 100, reps: 10),
            133.33,
            accuracy: 0.01
        )
    }

    func testOneRepMaxIsZeroForInvalidInput() {
        XCTAssertEqual(ProgressMath.estimatedOneRepMax(weight: 100, reps: 0), 0)
        XCTAssertEqual(ProgressMath.estimatedOneRepMax(weight: 0, reps: 5), 0)
    }

    // MARK: - Progress points

    func testProgressPointsGroupSamplesByDay() {
        let calendar = Calendar.current
        let day1 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let day2 = calendar.date(from: DateComponents(year: 2026, month: 8, day: 8))!

        let samples = [
            SetSample(date: day1, weight: 100, reps: 5),
            SetSample(date: day1.addingTimeInterval(600), weight: 105, reps: 3),
            SetSample(date: day2, weight: 110, reps: 2),
        ]

        let points = ProgressMath.progressPoints(from: samples, calendar: calendar)

        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points[0].date, calendar.startOfDay(for: day1))
        XCTAssertEqual(points[0].topSetWeight, 105)
        XCTAssertEqual(points[1].topSetWeight, 110)
    }

    func testProgressPointsUseBestOneRepMaxOfTheDay() {
        let day = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = [
            // e1RM = 100 * (1 + 10/30) = 133.33 — better than the heavier single.
            SetSample(date: day, weight: 100, reps: 10),
            SetSample(date: day, weight: 120, reps: 1),
        ]

        let points = ProgressMath.progressPoints(from: samples)

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].topSetWeight, 120)
        XCTAssertEqual(points[0].bestEstimatedOneRepMax, 133.33, accuracy: 0.01)
    }

    func testProgressPointsAreSortedByDate() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = [
            SetSample(date: base.addingTimeInterval(7 * 86_400), weight: 105, reps: 5),
            SetSample(date: base, weight: 100, reps: 5),
        ]

        let points = ProgressMath.progressPoints(from: samples)

        XCTAssertEqual(points.map(\.topSetWeight), [100, 105])
    }

    // MARK: - Personal records

    func testPersonalRecords() throws {
        let day = Date()
        let samples = [
            SetSample(date: day, weight: 100, reps: 10),
            SetSample(date: day, weight: 120, reps: 2),
            SetSample(date: day, weight: 60, reps: 15),
        ]

        let records = try XCTUnwrap(ProgressMath.personalRecords(from: samples))

        XCTAssertEqual(records.heaviestWeight, 120)
        XCTAssertEqual(records.mostRepsInASet, 15)
        // Best e1RM comes from 100 x 10 (133.33), not the heaviest single.
        XCTAssertEqual(records.bestEstimatedOneRepMax, 133.33, accuracy: 0.01)
    }

    func testPersonalRecordsAreNilWithoutSamples() {
        XCTAssertNil(ProgressMath.personalRecords(from: []))
    }

    func testCardioPointsSumTimeAndDistanceAndAverageIncline() {
        let calendar = Calendar.current
        let day = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1))!
        let samples = [
            CardioSample(date: day, durationSeconds: 600, speed: 5, incline: 12, distance: 0.8),
            CardioSample(date: day, durationSeconds: 600, speed: 5, incline: 8, distance: 0.9),
        ]

        let points = ProgressMath.cardioPoints(from: samples, calendar: calendar)

        XCTAssertEqual(points.count, 1)
        XCTAssertEqual(points[0].totalSeconds, 1200)
        XCTAssertEqual(points[0].totalMinutes, 20, accuracy: 0.01)
        XCTAssertEqual(points[0].averageIncline, 10, accuracy: 0.01)
        XCTAssertEqual(points[0].totalDistance, 1.7, accuracy: 0.01)
    }

    func testCardioRecords() throws {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86_400)
        let samples = [
            CardioSample(date: day1, durationSeconds: 1800, speed: 5, incline: 12, distance: 2.5),
            CardioSample(date: day2, durationSeconds: 2400, speed: 5.5, incline: 10, distance: 3.2),
        ]

        let records = try XCTUnwrap(ProgressMath.cardioRecords(from: samples))
        XCTAssertEqual(records.longestSessionSeconds, 2400)
        XCTAssertEqual(records.steepestIncline, 12)
        XCTAssertEqual(records.topSpeed, 5.5)
        XCTAssertEqual(records.longestSessionDistance, 3.2, accuracy: 0.01)
    }

    func testTimedRecordsTrackLongestRoundAndSession() throws {
        let day1 = Date(timeIntervalSince1970: 1_700_000_000)
        let day2 = day1.addingTimeInterval(86_400)
        let samples = [
            // Session 1: three 3-minute rounds.
            CardioSample(date: day1, durationSeconds: 180),
            CardioSample(date: day1, durationSeconds: 180),
            CardioSample(date: day1, durationSeconds: 180),
            // Session 2: one long 8-minute round.
            CardioSample(date: day2, durationSeconds: 480),
        ]

        let records = try XCTUnwrap(ProgressMath.timedRecords(from: samples))
        XCTAssertEqual(records.longestBlockSeconds, 480)
        XCTAssertEqual(records.longestSessionSeconds, 540)
    }

    func testTimedRecordsAreNilWithoutSamples() {
        XCTAssertNil(ProgressMath.timedRecords(from: []))
    }
}
