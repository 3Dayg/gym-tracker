import Foundation

/// Totals for a finished session, split by modality so History never
/// describes boxing as "sets · 0 kg" or hides mixed work.
struct SessionHistorySummary: Equatable {
    var strengthSets: Int = 0
    var strengthVolumeKilograms: Double = 0
    var timedRounds: Int = 0
    var timedSeconds: Int = 0
    var cardioBlocks: Int = 0
    var cardioSeconds: Int = 0
    var cardioDistanceKilometers: Double = 0
    var skippedCount: Int = 0

    static func from(_ session: WorkoutSession) -> SessionHistorySummary {
        var summary = SessionHistorySummary()
        for exercise in session.exercises {
            let completed = exercise.sets.filter(\.isCompleted)
            summary.skippedCount += exercise.sets.filter(\.isSkipped).count
            switch exercise.kind {
            case .strength:
                summary.strengthSets += completed.count
                summary.strengthVolumeKilograms += exercise.completedVolume
            case .timed:
                summary.timedRounds += completed.count
                summary.timedSeconds += completed.reduce(0) { $0 + $1.durationSeconds }
            case .cardio:
                summary.cardioBlocks += completed.count
                summary.cardioSeconds += completed.reduce(0) { $0 + $1.durationSeconds }
                summary.cardioDistanceKilometers += completed.reduce(0) { $0 + ($1.distance ?? 0) }
            }
        }
        return summary
    }

    /// Caption fragments after wall-clock duration, e.g. "3 sets · 1,920 kg".
    func captionBits(unit: UnitSystem) -> [String] {
        var bits: [String] = []
        if strengthSets > 0 {
            bits.append(strengthSets == 1 ? "1 set" : "\(strengthSets) sets")
            if strengthVolumeKilograms > 0 {
                bits.append(Formatters.weight(strengthVolumeKilograms, unit: unit))
            }
        }
        if timedRounds > 0 {
            bits.append(timedRounds == 1 ? "1 round" : "\(timedRounds) rounds")
            bits.append(Formatters.durationSeconds(timedSeconds))
        }
        if cardioBlocks > 0 {
            bits.append(cardioBlocks == 1 ? "1 block" : "\(cardioBlocks) blocks")
            bits.append(Formatters.durationSeconds(cardioSeconds))
            if cardioDistanceKilometers > 0 {
                bits.append(Formatters.distance(cardioDistanceKilometers, unit: unit))
            }
        }
        if skippedCount > 0 {
            bits.append(skippedCount == 1 ? "1 skipped" : "\(skippedCount) skipped")
        }
        return bits
    }

    func caption(duration: TimeInterval, unit: UnitSystem) -> String {
        ([Formatters.duration(duration)] + captionBits(unit: unit)).joined(separator: " · ")
    }
}
