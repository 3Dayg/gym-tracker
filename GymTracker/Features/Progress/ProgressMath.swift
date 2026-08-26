import Foundation

/// A completed set, flattened to plain values so the math below is easy to
/// unit-test without a model container.
struct SetSample: Equatable {
    let date: Date
    let weight: Double
    let reps: Int
}

/// One point per workout day for the progress chart.
struct ExerciseProgressPoint: Identifiable, Equatable {
    let date: Date
    let topSetWeight: Double
    let bestEstimatedOneRepMax: Double

    var id: Date { date }
}

struct PersonalRecords: Equatable {
    let heaviestWeight: Double
    let bestEstimatedOneRepMax: Double
    let mostRepsInASet: Int
}

/// A completed timed round or cardio block. Timed exercises leave speed,
/// incline, and distance at their empty values.
struct CardioSample: Equatable {
    let date: Date
    let durationSeconds: Int
    let speed: Double
    let incline: Double
    let distance: Double?

    init(date: Date, durationSeconds: Int, speed: Double = 0, incline: Double = 0, distance: Double? = nil) {
        self.date = date
        self.durationSeconds = durationSeconds
        self.speed = speed
        self.incline = incline
        self.distance = distance
    }
}

struct CardioProgressPoint: Identifiable, Equatable {
    let date: Date
    let totalSeconds: Int
    let averageIncline: Double
    let totalDistance: Double

    var id: Date { date }

    var totalMinutes: Double { Double(totalSeconds) / 60 }
}

struct CardioRecords: Equatable {
    let longestSessionSeconds: Int
    let steepestIncline: Double
    let topSpeed: Double
    let longestSessionDistance: Double
}

struct TimedRecords: Equatable {
    let longestBlockSeconds: Int
    let longestSessionSeconds: Int
}

enum ProgressMath {
    /// Epley formula. For a single rep the estimate is the weight itself.
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0, weight > 0 else { return 0 }
        guard reps > 1 else { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    /// Collapses samples into one point per calendar day: the day's top set
    /// weight and best estimated 1RM, sorted by date.
    static func progressPoints(
        from samples: [SetSample],
        calendar: Calendar = .current
    ) -> [ExerciseProgressPoint] {
        let byDay = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }
        return byDay
            .map { day, daySamples in
                ExerciseProgressPoint(
                    date: day,
                    topSetWeight: daySamples.map(\.weight).max() ?? 0,
                    bestEstimatedOneRepMax: daySamples
                        .map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }
                        .max() ?? 0
                )
            }
            .sorted { $0.date < $1.date }
    }

    static func personalRecords(from samples: [SetSample]) -> PersonalRecords? {
        guard !samples.isEmpty else { return nil }
        return PersonalRecords(
            heaviestWeight: samples.map(\.weight).max() ?? 0,
            bestEstimatedOneRepMax: samples
                .map { estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }
                .max() ?? 0,
            mostRepsInASet: samples.map(\.reps).max() ?? 0
        )
    }

    /// One point per day: total time, average incline, and total distance.
    static func cardioPoints(
        from samples: [CardioSample],
        calendar: Calendar = .current
    ) -> [CardioProgressPoint] {
        let byDay = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }
        return byDay
            .map { day, daySamples in
                let totalSeconds = daySamples.reduce(0) { $0 + $1.durationSeconds }
                let averageIncline = daySamples.reduce(0) { $0 + $1.incline } / Double(daySamples.count)
                let totalDistance = daySamples.reduce(0) { $0 + ($1.distance ?? 0) }
                return CardioProgressPoint(
                    date: day,
                    totalSeconds: totalSeconds,
                    averageIncline: averageIncline,
                    totalDistance: totalDistance
                )
            }
            .sorted { $0.date < $1.date }
    }

    static func cardioRecords(from samples: [CardioSample]) -> CardioRecords? {
        guard !samples.isEmpty else { return nil }
        let bySession = Dictionary(grouping: samples, by: \.date)
        let secondsBySession = bySession.mapValues { $0.reduce(0) { $0 + $1.durationSeconds } }
        let distanceBySession = bySession.mapValues { $0.reduce(0) { $0 + ($1.distance ?? 0) } }
        return CardioRecords(
            longestSessionSeconds: secondsBySession.values.max() ?? 0,
            steepestIncline: samples.map(\.incline).max() ?? 0,
            topSpeed: samples.map(\.speed).max() ?? 0,
            longestSessionDistance: distanceBySession.values.max() ?? 0
        )
    }

    static func timedRecords(from samples: [CardioSample]) -> TimedRecords? {
        guard !samples.isEmpty else { return nil }
        let secondsBySession = Dictionary(grouping: samples, by: \.date)
            .mapValues { $0.reduce(0) { $0 + $1.durationSeconds } }
        return TimedRecords(
            longestBlockSeconds: samples.map(\.durationSeconds).max() ?? 0,
            longestSessionSeconds: secondsBySession.values.max() ?? 0
        )
    }
}

extension Exercise {
    /// All completed sets from finished sessions, flattened for charting.
    var completedSetSamples: [SetSample] {
        sessionExercises.flatMap { sessionExercise -> [SetSample] in
            guard let endedAt = sessionExercise.session?.endedAt else { return [] }
            return sessionExercise.sets
                .filter(\.countsTowardRecords)
                .map { SetSample(date: endedAt, weight: $0.weight, reps: $0.reps) }
        }
    }

    /// Completed rows of timed and cardio exercises, flattened for charting.
    var completedDurationSamples: [CardioSample] {
        sessionExercises.flatMap { sessionExercise -> [CardioSample] in
            guard
                sessionExercise.kind != .strength,
                let endedAt = sessionExercise.session?.endedAt
            else { return [] }
            return sessionExercise.sets
                .filter(\.countsTowardRecords)
                .map {
                    CardioSample(
                        date: endedAt,
                        durationSeconds: $0.durationSeconds,
                        speed: $0.speed,
                        incline: $0.incline,
                        distance: $0.distance
                    )
                }
        }
    }
}
