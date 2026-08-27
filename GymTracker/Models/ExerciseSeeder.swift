import Foundation
import SwiftData

/// Imports bundled default exercises, and adds any new ones that were
/// missing from an earlier seed (so app updates pick them up).
enum ExerciseSeeder {
    struct SeedExercise: Decodable {
        let name: String
        let muscleGroup: MuscleGroup
        let equipment: Equipment
        /// Defaults to strength when the JSON omits it.
        let kind: ExerciseKind?
        let notes: String?
    }

    static func seedIfNeeded(in context: ModelContext, bundle: Bundle = .main) {
        let existing = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Exercise>())) ?? [])
                .map { ($0.name, $0) }
        )

        for seed in loadSeedExercises(from: bundle) {
            let kind = seed.kind ?? .strength
            if let exercise = existing[seed.name] {
                if !exercise.isCustom {
                    exercise.kind = kind
                    if exercise.notes.isEmpty, let notes = seed.notes, !notes.isEmpty {
                        exercise.notes = notes
                    }
                }
            } else {
                context.insert(Exercise(
                    name: seed.name,
                    muscleGroup: seed.muscleGroup,
                    equipment: seed.equipment,
                    notes: seed.notes ?? "",
                    isCustom: false,
                    kind: kind
                ))
            }
        }
    }

    static func loadSeedExercises(from bundle: Bundle = .main) -> [SeedExercise] {
        guard
            let url = bundle.url(forResource: "DefaultExercises", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let seeds = try? JSONDecoder().decode([SeedExercise].self, from: data)
        else {
            assertionFailure("DefaultExercises.json is missing or malformed")
            return []
        }
        return seeds
    }
}
