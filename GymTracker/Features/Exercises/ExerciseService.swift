import Foundation
import SwiftData

/// Custom-exercise rules: names stay unique, type stays stable after
/// logging, and deleting a custom exercise cannot leave broken plan rows.
enum ExerciseService {
    static func normalizedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isDuplicateName(
        _ name: String,
        excluding exercise: Exercise? = nil,
        in context: ModelContext
    ) -> Bool {
        let trimmed = normalizedName(name)
        guard !trimmed.isEmpty else { return false }
        let all = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        return all.contains { existing in
            if let exercise, existing.persistentModelID == exercise.persistentModelID {
                return false
            }
            return existing.name.compare(
                trimmed,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) == .orderedSame
        }
    }

    /// Any session row counts — even an unfinished workout — so Type cannot
    /// change out from under logged numbers.
    static func hasLoggedHistory(_ exercise: Exercise) -> Bool {
        !exercise.sessionExercises.isEmpty
    }

    static func affectedPlanNames(for exercise: Exercise) -> [String] {
        let names = exercise.plannedExercises.compactMap { planned -> String? in
            guard let name = planned.plan?.name, !name.isEmpty else { return nil }
            return name
        }
        return Array(Set(names)).sorted()
    }

    /// Removes the exercise from every plan, then deletes it. History stays
    /// because session rows keep `exerciseName`.
    static func deleteCustom(_ exercise: Exercise, in context: ModelContext) {
        guard exercise.isCustom else { return }
        for planned in Array(exercise.plannedExercises) {
            context.delete(planned)
        }
        context.delete(exercise)
    }
}
