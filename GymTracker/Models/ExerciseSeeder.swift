import Foundation
import SwiftData

/// Imports bundled default exercises, and adds any new ones that were
/// missing from an earlier seed (so app updates pick them up).
enum ExerciseSeeder {
    struct SeedExercise: Decodable {
        let name: String
        let muscleGroup: MuscleGroup
        let equipment: Equipment
        let kind: ExerciseKind?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            muscleGroup = try container.decode(MuscleGroup.self, forKey: .muscleGroup)
            equipment = try container.decode(Equipment.self, forKey: .equipment)
            kind = try container.decodeIfPresent(ExerciseKind.self, forKey: .kind)
                ?? container.decodeIfPresent(ExerciseKind.self, forKey: .trackingStyle)
        }

        private enum CodingKeys: String, CodingKey {
            case name, muscleGroup, equipment, kind, trackingStyle
        }
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
                }
            } else {
                context.insert(Exercise(
                    name: seed.name,
                    muscleGroup: seed.muscleGroup,
                    equipment: seed.equipment,
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
