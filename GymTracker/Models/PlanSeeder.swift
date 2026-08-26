import Foundation
import SwiftData

/// Imports bundled default workout plans. Each plan is seeded at most once;
/// deleting a plan does not bring it back. New bundled plans still appear
/// on later app versions.
enum PlanSeeder {
    static let seededNamesKey = "seededDefaultPlanNames"

    struct SeedPlan: Decodable {
        let name: String
        let notes: String
        let targetRestSeconds: Int?
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

            let plan = WorkoutPlan(
                name: seed.name,
                notes: seed.notes,
                targetRestSeconds: seed.targetRestSeconds
            )
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
        applyBoxingRestIfNeeded(in: context, defaults: defaults)
    }

    /// Existing installs seeded Boxing before rest lived on the plan.
    private static let boxingRestUpgradeKey = "upgradedBoxingPlanRest"

    private static func applyBoxingRestIfNeeded(in context: ModelContext, defaults: UserDefaults) {
        guard !defaults.bool(forKey: boxingRestUpgradeKey) else { return }
        let plans = (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []
        if let boxing = plans.first(where: { $0.name == "Boxing Conditioning" }),
           boxing.targetRestSeconds == nil
        {
            boxing.targetRestSeconds = 60
        }
        defaults.set(true, forKey: boxingRestUpgradeKey)
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
