import SwiftData

/// Inserts planned exercises with the same kind-specific defaults the editor uses.
enum PlanBuilder {
    @discardableResult
    static func addExercise(
        _ exercise: Exercise,
        to plan: WorkoutPlan,
        in context: ModelContext
    ) -> PlannedExercise {
        let nextOrder = (plan.exercises.map(\.sortOrder).max() ?? -1) + 1
        let planned: PlannedExercise
        switch exercise.kind {
        case .strength:
            planned = PlannedExercise(exercise: exercise, sortOrder: nextOrder)
        case .timed:
            planned = PlannedExercise(
                exercise: exercise,
                sortOrder: nextOrder,
                targetSets: 3,
                targetDurationSeconds: 60
            )
        case .cardio:
            planned = PlannedExercise(
                exercise: exercise,
                sortOrder: nextOrder,
                targetSets: 1,
                targetDurationSeconds: 600,
                targetSpeed: SettingsDefaults.walkingSpeedKilometersPerHour,
                targetIncline: 0
            )
        }
        planned.plan = plan
        context.insert(planned)
        return planned
    }

    static func addExercises(
        _ exercises: [Exercise],
        to plan: WorkoutPlan,
        in context: ModelContext
    ) {
        for exercise in exercises {
            addExercise(exercise, to: plan, in: context)
        }
    }
}
