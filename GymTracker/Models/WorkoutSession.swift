import Foundation
import SwiftData

@Model
final class WorkoutSession {
    var startedAt: Date
    /// nil while the workout is in progress; set when the user finishes.
    var endedAt: Date?
    /// Name of the plan this session was started from, if any. Stored as a
    /// plain string so history survives plan deletion.
    var planName: String?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise] = []

    var orderedExercises: [SessionExercise] {
        exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    var isFinished: Bool { endedAt != nil }

    var duration: TimeInterval { (endedAt ?? .now).timeIntervalSince(startedAt) }

    /// Total volume (weight x reps) of all completed sets.
    var totalVolume: Double {
        exercises.reduce(0) { $0 + $1.completedVolume }
    }

    var completedSetCount: Int {
        exercises.reduce(0) { $0 + $1.sets.filter(\.isCompleted).count }
    }

    var completedCardioSeconds: Int {
        exercises.reduce(0) { $0 + $1.completedDurationSeconds }
    }

    init(startedAt: Date = .now, planName: String? = nil) {
        self.startedAt = startedAt
        self.planName = planName
    }
}

@Model
final class SessionExercise {
    var sortOrder: Int
    /// Denormalized so history remains readable if the exercise is deleted.
    var exerciseName: String
    private var trackingStyleRaw: String?

    var exercise: Exercise?
    var session: WorkoutSession?

    var kind: ExerciseKind {
        get {
            if trackingStyleRaw != nil {
                return ExerciseKind.parse(trackingStyleRaw)
            }
            return exercise?.kind ?? .strength
        }
        set { trackingStyleRaw = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \SetEntry.sessionExercise)
    var sets: [SetEntry] = []

    var orderedSets: [SetEntry] {
        sets.sorted { $0.sortOrder < $1.sortOrder }
    }

    var completedVolume: Double {
        guard kind == .strength else { return 0 }
        return sets.filter(\.isCompleted).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    var completedDurationSeconds: Int {
        guard kind == .cardio else { return 0 }
        return sets.filter(\.isCompleted).reduce(0) { $0 + $1.durationSeconds }
    }

    init(exercise: Exercise, sortOrder: Int) {
        self.exercise = exercise
        self.exerciseName = exercise.name
        self.trackingStyleRaw = exercise.kind.rawValue
        self.sortOrder = sortOrder
    }
}

@Model
final class SetEntry {
    var sortOrder: Int
    var reps: Int
    var weight: Double
    /// Seconds logged. Unused for strength sets. Stored under the legacy
    /// column name; values are converted to seconds once at launch.
    @Attribute(originalName: "durationMinutes")
    var durationSeconds: Int = 0
    var speed: Double = 0
    var incline: Double = 0
    /// Distance covered (km or mi, matching the speed unit). nil when the
    /// user left it to be derived from speed and duration.
    var distance: Double?
    var isCompleted: Bool

    var sessionExercise: SessionExercise?

    init(
        sortOrder: Int,
        reps: Int = 10,
        weight: Double = 0,
        durationSeconds: Int = 600,
        speed: Double = 5,
        incline: Double = 0,
        distance: Double? = nil,
        isCompleted: Bool = false
    ) {
        self.sortOrder = sortOrder
        self.reps = reps
        self.weight = weight
        self.durationSeconds = durationSeconds
        self.speed = speed
        self.incline = incline
        self.distance = distance
        self.isCompleted = isCompleted
    }
}
