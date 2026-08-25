import Foundation
import SwiftData

/// Imports bundled default workout plans. Each plan is seeded at most once;
/// deleting a plan does not bring it back. New bundled plans still appear
/// on later app versions.
enum PlanSeeder {
    static let seededFlagKey = "didSeedDefaultPlans"
    static let seededNamesKey = "seededDefaultPlanNames"

    /// Plans that shipped before per-name tracking. Used only to migrate
    /// the old single boolean flag so those plans stay unrecreated.
    private static let plansSeededUnderLegacyFlag = ["Boxing Conditioning"]

    struct SeedPlan: Decodable {
        let name: String
        let notes: String
        let exercises: [SeedPlannedExercise]
    }

    struct SeedPlannedExercise: Decodable {
        let name: String
        let targetSets: Int
        let targetReps: Int
        let targetWeight: Double?
        let targetDurationSeconds: Int
        let targetSpeed: Double?
        let targetIncline: Double?
        let targetDistance: Double?

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            targetSets = try container.decode(Int.self, forKey: .targetSets)
            targetReps = try container.decodeIfPresent(Int.self, forKey: .targetReps) ?? 0
            targetWeight = try container.decodeIfPresent(Double.self, forKey: .targetWeight)
            targetDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .targetDurationSeconds) ?? 0
            targetSpeed = try container.decodeIfPresent(Double.self, forKey: .targetSpeed)
            targetIncline = try container.decodeIfPresent(Double.self, forKey: .targetIncline)
            targetDistance = try container.decodeIfPresent(Double.self, forKey: .targetDistance)
        }

        private enum CodingKeys: String, CodingKey {
            case name, targetSets, targetReps, targetWeight
            case targetDurationSeconds, targetSpeed, targetIncline, targetDistance
        }
    }

    static func seedIfNeeded(
        in context: ModelContext,
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard
    ) {
        var alreadySeeded = Set(defaults.stringArray(forKey: seededNamesKey) ?? [])
        if defaults.bool(forKey: seededFlagKey) {
            alreadySeeded.formUnion(plansSeededUnderLegacyFlag)
            defaults.removeObject(forKey: seededFlagKey)
        }

        let exercisesByName = Dictionary(
            uniqueKeysWithValues: ((try? context.fetch(FetchDescriptor<Exercise>())) ?? [])
                .map { ($0.name, $0) }
        )
        let existingPlanNames = Set(
            ((try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []).map(\.name)
        )

        for seed in loadSeedPlans(from: bundle) {
            defer { alreadySeeded.insert(seed.name) }
            guard !alreadySeeded.contains(seed.name) else { continue }
            guard !existingPlanNames.contains(seed.name) else { continue }

            let plan = WorkoutPlan(name: seed.name, notes: seed.notes)
            context.insert(plan)

            for (index, item) in seed.exercises.enumerated() {
                guard let exercise = exercisesByName[item.name] else {
                    assertionFailure("Seed plan '\(seed.name)' references unknown exercise '\(item.name)'")
                    continue
                }
                let planned = PlannedExercise(
                    exercise: exercise,
                    sortOrder: index,
                    targetSets: item.targetSets,
                    targetReps: item.targetReps,
                    targetWeight: item.targetWeight,
                    targetDurationSeconds: item.targetDurationSeconds,
                    targetSpeed: item.targetSpeed,
                    targetIncline: item.targetIncline,
                    targetDistance: item.targetDistance
                )
                planned.plan = plan
            }
        }

        defaults.set(Array(alreadySeeded).sorted(), forKey: seededNamesKey)
    }

    static let secondsMigrationKey = "didConvertDurationsToSeconds"

    /// One-time upgrade of data written by older versions. Must run after
    /// `ExerciseSeeder.seedIfNeeded` (which fixes exercise kinds) and before
    /// `seedIfNeeded` (so freshly seeded second-based targets are untouched).
    ///
    /// - Cardio targets/sets stored minutes; both become seconds.
    /// - The bundled Boxing plan abused reps as round minutes (and, for the
    ///   Plank, as seconds); timed targets become real durations.
    /// - The bundled Incline Walk plan predates speed/incline targets.
    static func migrateLegacyDataIfNeeded(
        in context: ModelContext,
        defaults: UserDefaults = .standard
    ) {
        let inclineDefaultsKey = "didFillInclineWalkTreadmillSettings"

        if !defaults.bool(forKey: secondsMigrationKey) {
            for item in (try? context.fetch(FetchDescriptor<PlannedExercise>())) ?? [] {
                switch item.exercise?.kind {
                case .cardio:
                    if item.targetDurationSeconds == 0, item.targetReps > 0 {
                        item.targetDurationSeconds = item.targetReps
                    }
                    item.targetDurationSeconds *= 60
                case .timed:
                    if item.targetDurationSeconds == 0, item.targetReps > 0 {
                        item.targetDurationSeconds = item.exerciseName == "Plank"
                            ? item.targetReps
                            : item.targetReps * 60
                    } else {
                        item.targetDurationSeconds *= 60
                    }
                default:
                    break
                }
            }

            for set in (try? context.fetch(FetchDescriptor<SetEntry>())) ?? []
            where set.sessionExercise?.kind == .cardio {
                set.durationSeconds *= 60
            }

            defaults.set(true, forKey: secondsMigrationKey)
        }

        if !defaults.bool(forKey: inclineDefaultsKey) {
            let plans = (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []
            if let walk = plans.first(where: { $0.name == "Incline Walk" }) {
                for item in walk.orderedExercises {
                    if item.exerciseName == "Incline Treadmill Walk" {
                        if item.targetSpeed == nil { item.targetSpeed = 5 }
                        if item.targetIncline == nil { item.targetIncline = 12 }
                    } else if item.exerciseName == "Treadmill Walk" {
                        if item.targetSpeed == nil { item.targetSpeed = 4.5 }
                        if item.targetIncline == nil { item.targetIncline = 1 }
                    }
                }
            }
            defaults.set(true, forKey: inclineDefaultsKey)
        }

        try? context.save()
    }

    static func loadSeedPlans(from bundle: Bundle = .main) -> [SeedPlan] {
        guard
            let url = bundle.url(forResource: "DefaultPlans", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let seeds = try? JSONDecoder().decode([SeedPlan].self, from: data)
        else {
            assertionFailure("DefaultPlans.json is missing or malformed")
            return []
        }
        return seeds
    }
}
