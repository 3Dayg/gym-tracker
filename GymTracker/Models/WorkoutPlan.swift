import Foundation
import SwiftData

@Model
final class WorkoutPlan {
    var name: String
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.plan)
    var exercises: [PlannedExercise] = []

    /// Exercises in the order the user arranged them. SwiftData does not
    /// guarantee relationship order, so an explicit sort key is used.
    var orderedExercises: [PlannedExercise] {
        exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    init(name: String, notes: String = "", createdAt: Date = .now) {
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
    }
}

@Model
final class PlannedExercise {
    var sortOrder: Int
    var targetSets: Int
    var targetReps: Int
    /// Optional: when nil, the live workout falls back to the last weight
    /// the user logged for this exercise.
    var targetWeight: Double?
    /// Seconds per timed round or cardio block. Unused for strength
    /// exercises. Stored under the legacy column name; values are converted
    /// to seconds once at launch.
    @Attribute(originalName: "targetDurationMinutes")
    var targetDurationSeconds: Int = 0
    var targetSpeed: Double?
    var targetIncline: Double?
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
