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
        var foundNext = false
        for exercise in session.orderedExercises {
            for (index, set) in exercise.orderedSets.enumerated() {
                progress.totalCount += 1
                if set.isPending {
                    if !foundNext {
                        progress.nextExerciseName = exercise.exerciseName
                        progress.nextSetLabel = "\(exercise.kind.setLabel) \(index + 1)"
                        foundNext = true
                    }
                } else {
                    progress.loggedCount += 1
                }
            }
        }
        return progress
    }

    /// First pending row in list order, used to highlight the next target.
    static func nextPendingSet(in session: WorkoutSession) -> SetEntry? {
        for exercise in session.orderedExercises {
            if let set = exercise.orderedSets.first(where: \.isPending) {
                return set
            }
        }
        return nil
    }
}
