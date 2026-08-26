import XCTest
@testable import GymTracker

final class LiveTimerRestorerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    func testRestInTheFutureIsRestored() {
        let endAt = now.addingTimeInterval(40)
        let state = LiveTimerState(
            phase: .rest,
            endAt: endAt,
            totalSeconds: 60,
            remainingSeconds: 40,
            followOnRestSeconds: 0
        )

        XCTAssertEqual(
            LiveTimerRestorer.action(from: state, now: now),
            .rest(endAt: endAt, total: 60, completeExercise: nil, completeSet: nil)
        )
    }

    func testExpiredRestBecomesIdle() {
        let state = LiveTimerState(
            phase: .rest,
            endAt: now.addingTimeInterval(-5),
            totalSeconds: 60,
            remainingSeconds: 0,
            followOnRestSeconds: 0
        )

        XCTAssertEqual(LiveTimerRestorer.action(from: state, now: now), .idle)
    }

    func testWorkStillRunningIsRestored() {
        let endAt = now.addingTimeInterval(20)
        let state = LiveTimerState(
            phase: .work,
            endAt: endAt,
            totalSeconds: 180,
            remainingSeconds: 20,
            exerciseSortOrder: 0,
            setSortOrder: 1,
            followOnRestSeconds: 60
        )

        XCTAssertEqual(
            LiveTimerRestorer.action(from: state, now: now),
            .work(endAt: endAt, total: 180, exercise: 0, set: 1, followOnRest: 60)
        )
    }

    func testExpiredWorkStartsRemainingRestAndCompletesTheSet() {
        let workEnded = now.addingTimeInterval(-20)
        let state = LiveTimerState(
            phase: .work,
            endAt: workEnded,
            totalSeconds: 180,
            remainingSeconds: 0,
            exerciseSortOrder: 0,
            setSortOrder: 1,
            followOnRestSeconds: 60
        )

        XCTAssertEqual(
            LiveTimerRestorer.action(from: state, now: now),
            .rest(endAt: workEnded.addingTimeInterval(60), total: 60, completeExercise: 0, completeSet: 1)
        )
    }

    func testExpiredWorkAndRestCompletesTheSetAndIdles() {
        let state = LiveTimerState(
            phase: .work,
            endAt: now.addingTimeInterval(-90),
            totalSeconds: 180,
            remainingSeconds: 0,
            exerciseSortOrder: 0,
            setSortOrder: 1,
            followOnRestSeconds: 60
        )

        XCTAssertEqual(
            LiveTimerRestorer.action(from: state, now: now),
            .completeSetAndIdle(exercise: 0, set: 1)
        )
    }

    func testPausedWorkIsRestored() {
        let state = LiveTimerState(
            phase: .pausedWork,
            endAt: nil,
            totalSeconds: 180,
            remainingSeconds: 42,
            exerciseSortOrder: 0,
            setSortOrder: 0,
            followOnRestSeconds: 60
        )

        XCTAssertEqual(
            LiveTimerRestorer.action(from: state, now: now),
            .pausedWork(remaining: 42, total: 180, exercise: 0, set: 0, followOnRest: 60)
        )
    }

    func testDayOldSessionIsStale() {
        XCTAssertTrue(StaleWorkoutPolicy.isStale(now.addingTimeInterval(-25 * 3600), now: now))
        XCTAssertFalse(StaleWorkoutPolicy.isStale(now.addingTimeInterval(-30 * 60), now: now))
    }
}
