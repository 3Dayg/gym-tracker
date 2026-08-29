import Foundation
import SwiftData

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest, back, shoulders, biceps, triceps, legs, glutes, core, cardio, other

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case barbell, dumbbell, machine, cable, bodyweight, kettlebell, band, other

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

/// One value a user can log for a set. An exercise kind declares which
/// metrics it uses, and all logging/plan UIs render from that list.
enum SetMetric: String, Identifiable {
    case weight, reps, duration, speed, incline, distance

    var id: String { rawValue }

    var fieldTitle: String {
        switch self {
        case .weight: "Weight"
        case .reps: "Reps"
        case .duration: "Time"
        case .speed: "Speed"
        case .incline: "Incline"
        case .distance: "Distance"
        }
    }
}

/// How an exercise is logged. Strength uses sets/reps/weight; timed work is
/// duration only (jump rope, plank, bag rounds); cardio adds machine
/// settings and distance (treadmill, bike, rower).
enum ExerciseKind: String, CaseIterable, Identifiable, Codable {
    case strength
    case timed
    case cardio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .strength: "Strength (reps & weight)"
        case .timed: "Timed (duration)"
        case .cardio: "Cardio (time, speed, incline, distance)"
        }
    }

    /// Metrics rendered when logging a set of this kind, in display order.
    var metrics: [SetMetric] {
        switch self {
        case .strength: [.weight, .reps]
        case .timed: [.duration]
        case .cardio: [.duration, .speed, .incline, .distance]
        }
    }

    /// Cardio rows are continuous, so completing one starts no rest timer.
    /// Timed rounds (bag work, planks) have real rests between them.
    var startsRestTimer: Bool { self != .cardio }

    /// Timed rounds and cardio both offer a Start/Pause work countdown.
    /// Strength is logged with Done; rest is separate.
    var hasWorkTimer: Bool { self != .strength }

    /// What one logged row is called in the UI.
    var setLabel: String {
        switch self {
        case .strength, .cardio: "Set"
        case .timed: "Round"
        }
    }

}

@Model
final class Exercise {
    var name: String
    var notes: String
    var isCustom: Bool
    var createdAt: Date

    // Enums are stored as raw strings so they stay usable in queries and
    // resilient to future case additions.
    private var muscleGroupRaw: String
    private var equipmentRaw: String
    private var kindRaw: String

    @Relationship(deleteRule: .nullify, inverse: \PlannedExercise.exercise)
    var plannedExercises: [PlannedExercise] = []

    @Relationship(deleteRule: .nullify, inverse: \SessionExercise.exercise)
    var sessionExercises: [SessionExercise] = []

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .other }
        set { muscleGroupRaw = newValue.rawValue }
    }

    var equipment: Equipment {
        get { Equipment(rawValue: equipmentRaw) ?? .other }
        set { equipmentRaw = newValue.rawValue }
    }

    var kind: ExerciseKind {
        get { ExerciseKind(rawValue: kindRaw) ?? .strength }
        set { kindRaw = newValue.rawValue }
    }

    init(
        name: String,
        muscleGroup: MuscleGroup,
        equipment: Equipment,
        notes: String = "",
        isCustom: Bool = false,
        kind: ExerciseKind = .strength,
        createdAt: Date = .now
    ) {
        self.name = name
        self.muscleGroupRaw = muscleGroup.rawValue
        self.equipmentRaw = equipment.rawValue
        self.notes = notes
        self.isCustom = isCustom
        self.kindRaw = kind.rawValue
        self.createdAt = createdAt
    }
}
