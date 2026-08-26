import Foundation

/// Wall-clock snapshot of the live work/rest timer, stored on the session
/// so a kill/relaunch can restore or expire it.
struct LiveTimerState: Codable, Equatable {
    enum Phase: String, Codable, Equatable {
        case work
        case rest
        case pausedWork
    }

    var phase: Phase
    /// Absolute end of a running countdown. Nil while work is paused.
    var endAt: Date?
    var totalSeconds: Int
    var remainingSeconds: Int
    var exerciseSortOrder: Int? = nil
    var setSortOrder: Int? = nil
    /// Rest to start after a work round that expires while the app is dead.
    var followOnRestSeconds: Int
}

enum LiveTimerRestoreAction: Equatable {
    case idle
    /// Work ended while we were gone, and rest has ended too.
    case completeSetAndIdle(exercise: Int, set: Int)
    case work(endAt: Date, total: Int, exercise: Int, set: Int, followOnRest: Int)
    case pausedWork(remaining: Int, total: Int, exercise: Int, set: Int, followOnRest: Int)
    case rest(endAt: Date, total: Int, completeExercise: Int?, completeSet: Int?)
}

enum LiveTimerRestorer {
    static func action(from state: LiveTimerState, now: Date = .now) -> LiveTimerRestoreAction {
        switch state.phase {
        case .pausedWork:
            guard state.remainingSeconds > 0,
                  let exercise = state.exerciseSortOrder,
                  let set = state.setSortOrder
            else { return .idle }
            return .pausedWork(
                remaining: state.remainingSeconds,
                total: state.totalSeconds,
                exercise: exercise,
                set: set,
                followOnRest: state.followOnRestSeconds
            )

        case .rest:
            guard let endAt = state.endAt, endAt > now else { return .idle }
            return .rest(endAt: endAt, total: state.totalSeconds, completeExercise: nil, completeSet: nil)

        case .work:
            guard let exercise = state.exerciseSortOrder, let set = state.setSortOrder else {
                return .idle
            }
            if let endAt = state.endAt, endAt > now {
                return .work(
                    endAt: endAt,
                    total: state.totalSeconds,
                    exercise: exercise,
                    set: set,
                    followOnRest: state.followOnRestSeconds
                )
            }
            let workEndedAt = state.endAt ?? now
            let rest = state.followOnRestSeconds
            let restEnd = workEndedAt.addingTimeInterval(TimeInterval(max(0, rest)))
            if rest > 0, restEnd > now {
                return .rest(
                    endAt: restEnd,
                    total: rest,
                    completeExercise: exercise,
                    completeSet: set
                )
            }
            return .completeSetAndIdle(exercise: exercise, set: set)
        }
    }
}

enum StaleWorkoutPolicy {
    /// Open long enough that the user may have forgotten this session.
    static let ageThreshold: TimeInterval = 12 * 60 * 60

    static func isStale(_ startedAt: Date, now: Date = .now) -> Bool {
        now.timeIntervalSince(startedAt) >= ageThreshold
    }
}
