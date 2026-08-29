import Foundation

/// What Follow along should show. Rest always wins so a countdown cannot
/// accidentally present — or complete — the next strength set.
enum FollowAlongFocus: Equatable {
    case rest
    case empty
    case finished
    case currentSet(exerciseName: String, setNumber: Int, setCount: Int, kind: ExerciseKind)

    static func current(
        session: WorkoutSession,
        timerPhase: SessionTimerPhase
    ) -> FollowAlongFocus {
        if timerPhase == .rest { return .rest }
        guard let set = LiveWorkoutProgress.nextPendingSet(in: session) else {
            return session.exercises.isEmpty ? .empty : .finished
        }
        guard let exercise = set.sessionExercise else { return .empty }
        let sets = exercise.orderedSets
        let number = (sets.firstIndex { $0 === set } ?? 0) + 1
        return .currentSet(
            exerciseName: exercise.exerciseName,
            setNumber: number,
            setCount: sets.count,
            kind: exercise.kind
        )
    }
}

enum SetLogging {
    @MainActor
    static func skip(_ set: SetEntry, timer: SessionTimer) {
        if timer.isTiming(set) { timer.stop() }
        set.markSkipped()
        LiveWorkoutProgress.clearExpiredFocus(in: set.sessionExercise?.session)
    }

    @MainActor
    static func fail(
        _ set: SetEntry,
        kind: ExerciseKind,
        timer: SessionTimer,
        restSeconds: Int
    ) {
        if timer.isTiming(set) { timer.stop() }
        fillDerivedDistanceIfNeeded(set, kind: kind)
        set.markCompleted(failed: true)
        LiveWorkoutProgress.clearExpiredFocus(in: set.sessionExercise?.session)
        if kind.startsRestTimer, timer.phase != .work {
            timer.startRest(seconds: restSeconds)
        }
    }

    @MainActor
    static func complete(
        _ set: SetEntry,
        kind: ExerciseKind,
        timer: SessionTimer,
        restSeconds: Int
    ) {
        if timer.isTiming(set) { timer.stop() }
        fillDerivedDistanceIfNeeded(set, kind: kind)
        set.markCompleted()
        LiveWorkoutProgress.clearExpiredFocus(in: set.sessionExercise?.session)
        if kind.startsRestTimer, timer.phase != .work {
            timer.startRest(seconds: restSeconds)
        }
    }

    static func fillDerivedDistanceIfNeeded(_ set: SetEntry, kind: ExerciseKind) {
        guard
            kind.metrics.contains(.distance),
            set.distance == nil,
            set.speed > 0,
            set.durationSeconds > 0
        else { return }
        let raw = set.speed * Double(set.durationSeconds) / 3600
        set.distance = (raw * 100).rounded() / 100
    }
}
