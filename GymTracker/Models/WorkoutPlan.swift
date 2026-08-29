import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var name: String
    var notes: String
    var createdAt: Date
    /// Seconds of rest after a completed set or timed round. Nil uses the
    /// app-wide rest setting.
    var targetRestSeconds: Int?
    /// Hidden from the list until the user taps Create, so backing out of a
    /// new plan does not leave an empty “New Plan” template.
    var isDraft: Bool = false

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.plan)
    var exercises: [PlannedExercise] = []

    /// Exercises in the order the user arranged them. SwiftData does not
    /// guarantee relationship order, so an explicit sort key is used.
    var orderedExercises: [PlannedExercise] {
        exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    init(
        name: String,
        notes: String = "",
        createdAt: Date = .now,
        targetRestSeconds: Int? = nil,
        isDraft: Bool = false
    ) {
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.targetRestSeconds = targetRestSeconds
        self.isDraft = isDraft
    }
}

@Model
final class PlannedExercise {
    var sortOrder: Int
    var targetSets: Int
    var targetReps: Int
    /// Optional canonical kilograms. When nil, the live workout falls back
    /// to the last weight the user logged for this exercise.
    var targetWeight: Double?
    /// Seconds per timed round or cardio set. Unused for strength
    /// exercises.
    var targetDurationSeconds: Int = 0
    /// Canonical kilometers per hour.
    var targetSpeed: Double?
    var targetIncline: Double?
    /// Canonical kilometers.
    var targetDistance: Double?

    var exercise: Exercise?
    var plan: WorkoutPlan?

    var exerciseName: String { exercise?.name ?? "Deleted exercise" }

    var kind: ExerciseKind { exercise?.kind ?? .strength }

    init(
        exercise: Exercise,
        sortOrder: Int,
        targetSets: Int = 3,
        targetReps: Int = 10,
        targetWeight: Double? = nil,
        targetDurationSeconds: Int = 600,
        targetSpeed: Double? = nil,
        targetIncline: Double? = nil,
        targetDistance: Double? = nil
    ) {
        self.exercise = exercise
        self.sortOrder = sortOrder
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.targetDurationSeconds = targetDurationSeconds
        self.targetSpeed = targetSpeed
        self.targetIncline = targetIncline
        self.targetDistance = targetDistance
    }
}
