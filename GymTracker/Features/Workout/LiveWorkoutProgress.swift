import Foundation

/// Where the trainer is in a live workout: how many rows are logged and
/// which pending row is next.
struct LiveWorkoutProgress: Equatable {
    var loggedCount: Int = 0
    var totalCount: Int = 0
    var nextExerciseName: String? = nil
    var nextSetLabel: String? = nil

    var caption: String {
        guard totalCount > 0 else { return "No rows yet" }
        return "\(loggedCount) of \(totalCount)"
    }

    var nextLine: String {
        if let nextExerciseName, let nextSetLabel {
            return "Next: \(nextExerciseName) · \(nextSetLabel)"
        }
        if totalCount == 0 {
            return "Add an exercise to log a set"
        }
        return "All rows logged"
    }

    static func from(_ session: WorkoutSession) -> LiveWorkoutProgress {
        var progress = LiveWorkoutProgress()
        for exercise in session.orderedExercises {
            for set in exercise.orderedSets {
                progress.totalCount += 1
                if !set.isPending {
                    progress.loggedCount += 1
                }
            }
        }
        if let set = nextPendingSet(in: session), let exercise = set.sessionExercise {
            let index = (exercise.orderedSets.firstIndex { $0 === set } ?? 0) + 1
            progress.nextExerciseName = exercise.exerciseName
            progress.nextSetLabel = "\(exercise.kind.setLabel) \(index)"
        }
        return progress
    }

    /// Pending row Follow along should show: the focused exercise if it
    /// still has work, otherwise the first pending row in plan order.
    static func nextPendingSet(in session: WorkoutSession) -> SetEntry? {
        if let focused = pendingSet(inFocusedExerciseOf: session) {
            return focused
        }
        return firstPendingSet(in: session)
    }

    /// First pending row in list order, ignoring Follow along focus.
    static func firstPendingSet(in session: WorkoutSession) -> SetEntry? {
        for exercise in session.orderedExercises {
            if let set = exercise.orderedSets.first(where: \.isPending) {
                return set
            }
        }
        return nil
    }

    static func pendingSet(inFocusedExerciseOf session: WorkoutSession) -> SetEntry? {
        guard let order = session.focusedExerciseSortOrder else { return nil }
        guard let exercise = session.orderedExercises.first(where: { $0.sortOrder == order }) else {
            return nil
        }
        return exercise.orderedSets.first(where: \.isPending)
    }

    /// Drop focus when the chosen exercise is done or gone so the card
    /// returns to the first unfinished exercise in plan order.
    static func clearExpiredFocus(in session: WorkoutSession?) {
        guard let session else { return }
        guard session.focusedExerciseSortOrder != nil else { return }
        if pendingSet(inFocusedExerciseOf: session) == nil {
            session.focusedExerciseSortOrder = nil
        }
    }

    static func jump(to exercise: SessionExercise, in session: WorkoutSession) {
        session.focusedExerciseSortOrder = exercise.sortOrder
    }

    static func exerciseItems(in session: WorkoutSession) -> [FollowAlongExerciseItem] {
        let focusedOrder = session.focusedExerciseSortOrder
            ?? nextPendingSet(in: session)?.sessionExercise?.sortOrder
        return session.orderedExercises.map { exercise in
            let sets = exercise.orderedSets
            let logged = sets.filter { !$0.isPending }.count
            return FollowAlongExerciseItem(
                sortOrder: exercise.sortOrder,
                name: exercise.exerciseName,
                loggedCount: logged,
                totalCount: sets.count,
                isFocused: exercise.sortOrder == focusedOrder,
                hasPending: sets.contains(where: \.isPending)
            )
        }
    }
}

struct FollowAlongExerciseItem: Identifiable, Equatable {
    var id: Int { sortOrder }
    let sortOrder: Int
    let name: String
    let loggedCount: Int
    let totalCount: Int
    let isFocused: Bool
    let hasPending: Bool

    var caption: String {
        guard totalCount > 0 else { return "No rows" }
        return "\(loggedCount) of \(totalCount)"
    }
}
