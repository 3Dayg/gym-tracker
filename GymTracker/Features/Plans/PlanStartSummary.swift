import Foundation

/// What a trainer needs to see before starting a plan: size, known work
/// time, notes, and whether the plan would produce an empty workout.
struct PlanStartSummary: Equatable {
    var startableExerciseCount: Int = 0
    var missingExerciseCount: Int = 0
    var strengthSets: Int = 0
    var timedRounds: Int = 0
    var cardioBlocks: Int = 0
    var knownWorkSeconds: Int = 0
    var restSeconds: Int? = nil
    var notes: String = ""
    var exerciseNames: [String] = []

    var canStart: Bool { startableExerciseCount > 0 && missingExerciseCount == 0 }

    var rowCount: Int { strengthSets + timedRounds + cardioBlocks }

    static func from(_ plan: WorkoutPlan) -> PlanStartSummary {
        var summary = PlanStartSummary()
        summary.notes = plan.notes
        summary.restSeconds = plan.targetRestSeconds
        for planned in plan.orderedExercises {
            guard planned.exercise != nil else {
                summary.missingExerciseCount += 1
                continue
            }
            summary.startableExerciseCount += 1
            summary.exerciseNames.append(planned.exerciseName)
            switch planned.kind {
            case .strength:
                summary.strengthSets += planned.targetSets
            case .timed:
                summary.timedRounds += planned.targetSets
                summary.knownWorkSeconds += planned.targetSets * planned.targetDurationSeconds
            case .cardio:
                summary.cardioBlocks += planned.targetSets
                summary.knownWorkSeconds += planned.targetSets * planned.targetDurationSeconds
            }
        }
        return summary
    }

    /// Short line for the Workout and Plans lists.
    func listCaption() -> String {
        if missingExerciseCount > 0 {
            return "Can't start — missing exercises"
        }
        if startableExerciseCount == 0 {
            return "Can't start — no exercises"
        }
        var bits: [String] = [
            startableExerciseCount == 1 ? "1 exercise" : "\(startableExerciseCount) exercises"
        ]
        if knownWorkSeconds > 0 {
            bits.append("\(Formatters.durationSeconds(knownWorkSeconds)) work")
        }
        if let restSeconds {
            bits.append("\(Formatters.countdown(restSeconds)) rest")
        }
        return bits.joined(separator: " · ")
    }

    func detailBits() -> [String] {
        var bits: [String] = []
        if startableExerciseCount > 0 {
            bits.append(
                startableExerciseCount == 1 ? "1 exercise" : "\(startableExerciseCount) exercises"
            )
        }
        if strengthSets > 0 {
            bits.append(strengthSets == 1 ? "1 set" : "\(strengthSets) sets")
        }
        if timedRounds > 0 {
            bits.append(timedRounds == 1 ? "1 round" : "\(timedRounds) rounds")
        }
        if cardioBlocks > 0 {
            bits.append(cardioBlocks == 1 ? "1 block" : "\(cardioBlocks) blocks")
        }
        if knownWorkSeconds > 0 {
            bits.append("\(Formatters.durationSeconds(knownWorkSeconds)) work")
        }
        if let restSeconds {
            bits.append("\(Formatters.countdown(restSeconds)) rest")
        }
        if missingExerciseCount > 0 {
            bits.append(
                missingExerciseCount == 1 ? "1 missing exercise" : "\(missingExerciseCount) missing exercises"
            )
        }
        return bits
    }

    var blockedReason: String {
        if missingExerciseCount > 0 && startableExerciseCount == 0 {
            return "Every exercise in this plan was deleted. Edit the plan and add exercises before starting."
        }
        if missingExerciseCount > 0 {
            return "This plan includes deleted exercises. Edit the plan before starting so nothing is skipped."
        }
        return "Add at least one exercise before starting. An empty plan would open a blank workout."
    }
}
