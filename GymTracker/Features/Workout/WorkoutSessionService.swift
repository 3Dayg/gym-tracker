import Foundation
import SwiftData

/// Pure session-manipulation logic, kept out of the views so it can be
/// unit-tested with an in-memory container.
enum WorkoutSessionService {
    /// Starts a session pre-filled from a plan.
    @discardableResult
    static func startSession(from plan: WorkoutPlan, in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(planName: plan.name)
        context.insert(session)

        for (index, planned) in plan.orderedExercises.enumerated() {
            guard let exercise = planned.exercise else { continue }
            let sessionExercise = SessionExercise(exercise: exercise, sortOrder: index)
            sessionExercise.session = session

            for setIndex in 0..<planned.targetSets {
                let set = makeSet(sortOrder: setIndex, from: planned)
                set.sessionExercise = sessionExercise
            }
        }
        return session
    }

    @discardableResult
    static func startEmptySession(in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession()
        context.insert(session)
        return session
    }

    /// Appends an exercise to a running session with one block/set pre-filled
    /// from the user's most recent log of that exercise.
    @discardableResult
    static func addExercise(
        _ exercise: Exercise,
        to session: WorkoutSession,
        in context: ModelContext
    ) -> SessionExercise {
        let nextOrder = (session.exercises.map(\.sortOrder).max() ?? -1) + 1
        let sessionExercise = SessionExercise(exercise: exercise, sortOrder: nextOrder)
        sessionExercise.session = session

        let set: SetEntry
        switch exercise.kind {
        case .strength:
            set = SetEntry(
                sortOrder: 0,
                reps: 10,
                weight: lastUsedWeight(for: exercise) ?? 0
            )
        case .timed:
            set = SetEntry(
                sortOrder: 0,
                durationSeconds: lastUsedDurationSeconds(for: exercise) ?? 60
            )
        case .cardio:
            let last = lastUsedCardio(for: exercise)
            set = SetEntry(
                sortOrder: 0,
                durationSeconds: last?.durationSeconds ?? 600,
                speed: last?.speed ?? SettingsDefaults.walkingSpeedKilometersPerHour,
                incline: last?.incline ?? 0
            )
        }
        set.sessionExercise = sessionExercise
        return sessionExercise
    }

    /// Adds a set, round, or cardio block copying metrics from the current
    /// last row.
    @discardableResult
    static func addSet(to sessionExercise: SessionExercise) -> SetEntry {
        let lastSet = sessionExercise.orderedSets.last
        let nextOrder = (sessionExercise.sets.map(\.sortOrder).max() ?? -1) + 1
        let set = SetEntry(
            sortOrder: nextOrder,
            reps: lastSet?.reps ?? 10,
            weight: lastSet?.weight ?? 0,
            durationSeconds: lastSet?.durationSeconds ?? 600,
            speed: lastSet?.speed ?? SettingsDefaults.walkingSpeedKilometersPerHour,
            incline: lastSet?.incline ?? 0
        )
        set.sessionExercise = sessionExercise
        return set
    }

    /// Finishes the session, discarding rows that were never completed and
    /// exercises that end up with no completed rows.
    static func finish(_ session: WorkoutSession, in context: ModelContext) {
        for sessionExercise in session.exercises {
            for set in sessionExercise.sets where !set.isCompleted {
                context.delete(set)
            }
            if sessionExercise.sets.allSatisfy({ !$0.isCompleted }) {
                context.delete(sessionExercise)
            }
        }
        session.endedAt = .now
        try? context.save()
    }

    static func cancel(_ session: WorkoutSession, in context: ModelContext) {
        context.delete(session)
    }

    static func lastUsedWeight(for exercise: Exercise) -> Double? {
        latestCompletedSets(for: exercise).first?.weight
    }

    static func lastUsedDurationSeconds(for exercise: Exercise) -> Int? {
        latestCompletedSets(for: exercise).first?.durationSeconds
    }

    static func lastUsedCardio(for exercise: Exercise) -> (durationSeconds: Int, speed: Double, incline: Double)? {
        guard let set = latestCompletedSets(for: exercise).first else { return nil }
        return (set.durationSeconds, set.speed, set.incline)
    }

    private static func latestCompletedSets(for exercise: Exercise) -> [SetEntry] {
        exercise.sessionExercises
            .filter { $0.session?.endedAt != nil }
            .sorted { ($0.session?.endedAt ?? .distantPast) > ($1.session?.endedAt ?? .distantPast) }
            .flatMap { $0.orderedSets.filter(\.isCompleted) }
    }

    private static func makeSet(sortOrder: Int, from planned: PlannedExercise) -> SetEntry {
        guard let exercise = planned.exercise else {
            return SetEntry(sortOrder: sortOrder)
        }

        switch exercise.kind {
        case .strength:
            let weight = planned.targetWeight ?? lastUsedWeight(for: exercise) ?? 0
            return SetEntry(sortOrder: sortOrder, reps: planned.targetReps, weight: weight)
        case .timed:
            let seconds = planned.targetDurationSeconds > 0
                ? planned.targetDurationSeconds
                : lastUsedDurationSeconds(for: exercise) ?? 60
            return SetEntry(sortOrder: sortOrder, durationSeconds: seconds)
        case .cardio:
            let last = lastUsedCardio(for: exercise)
            let seconds = planned.targetDurationSeconds > 0
                ? planned.targetDurationSeconds
                : last?.durationSeconds ?? 600
            return SetEntry(
                sortOrder: sortOrder,
                durationSeconds: seconds,
                speed: planned.targetSpeed ?? last?.speed ?? SettingsDefaults.walkingSpeedKilometersPerHour,
                incline: planned.targetIncline ?? last?.incline ?? 0,
                distance: planned.targetDistance
            )
        }
    }
}
