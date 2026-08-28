import Foundation
import SwiftData
import UserNotifications

/// On-device export and reset. Nothing is uploaded — files are written
/// locally and the share sheet lets the user keep a copy.
enum BackupService {
    struct Document: Codable, Equatable {
        var exportedAt: Date
        var unitSystem: String
        var restDurationSeconds: Int
        var profile: ProfileSnapshot?
        var bodyMeasurements: [MeasurementSnapshot]
        var customExercises: [ExerciseSnapshot]
        var plans: [PlanSnapshot]
        var sessions: [SessionSnapshot]
    }

    struct ProfileSnapshot: Codable, Equatable {
        var heightCentimeters: Double?
        var createdAt: Date
        var updatedAt: Date
    }

    struct MeasurementSnapshot: Codable, Equatable {
        var date: Date
        var weightKilograms: Double
    }

    struct ExerciseSnapshot: Codable, Equatable {
        var name: String
        var muscleGroup: String
        var equipment: String
        var kind: String
        var notes: String
        var createdAt: Date
    }

    struct PlanSnapshot: Codable, Equatable {
        var name: String
        var notes: String
        var createdAt: Date
        var targetRestSeconds: Int?
        var isDraft: Bool
        var exercises: [PlannedExerciseSnapshot]
    }

    struct PlannedExerciseSnapshot: Codable, Equatable {
        var name: String
        var sortOrder: Int
        var targetSets: Int
        var targetReps: Int
        var targetWeightKilograms: Double?
        var targetDurationSeconds: Int
        var targetSpeedKilometersPerHour: Double?
        var targetInclinePercent: Double?
        var targetDistanceKilometers: Double?
    }

    struct SessionSnapshot: Codable, Equatable {
        var startedAt: Date
        var endedAt: Date?
        var planName: String?
        var restSeconds: Int?
        var planNotes: String
        var exercises: [SessionExerciseSnapshot]
    }

    struct SessionExerciseSnapshot: Codable, Equatable {
        var name: String
        var kind: String
        var sortOrder: Int
        var notes: String
        var sets: [SetSnapshot]
    }

    struct SetSnapshot: Codable, Equatable {
        var sortOrder: Int
        var reps: Int
        var weightKilograms: Double
        var durationSeconds: Int
        var speedKilometersPerHour: Double
        var inclinePercent: Double
        var distanceKilometers: Double?
        /// completed, skipped, failed, or pending
        var outcome: String
    }

    static func makeDocument(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) -> Document {
        let unit = defaults.string(forKey: SettingsKeys.unitSystem) ?? UnitSystem.metric.rawValue
        let rest = defaults.object(forKey: SettingsKeys.restDurationSeconds) as? Int
            ?? SettingsDefaults.restDurationSeconds

        let profile = ProfileService.profile(in: context).map {
            ProfileSnapshot(
                heightCentimeters: $0.heightCentimeters,
                createdAt: $0.createdAt,
                updatedAt: $0.updatedAt
            )
        }

        let measurements = ((try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? [])
            .sorted { $0.date < $1.date }
            .map { MeasurementSnapshot(date: $0.date, weightKilograms: $0.weight) }

        let customExercises = ((try? context.fetch(FetchDescriptor<Exercise>())) ?? [])
            .filter(\.isCustom)
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            .map {
                ExerciseSnapshot(
                    name: $0.name,
                    muscleGroup: $0.muscleGroup.rawValue,
                    equipment: $0.equipment.rawValue,
                    kind: $0.kind.rawValue,
                    notes: $0.notes,
                    createdAt: $0.createdAt
                )
            }

        let plans = ((try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? [])
            .filter { !$0.isDraft }
            .sorted { $0.createdAt > $1.createdAt }
            .map { plan in
                PlanSnapshot(
                    name: plan.name,
                    notes: plan.notes,
                    createdAt: plan.createdAt,
                    targetRestSeconds: plan.targetRestSeconds,
                    isDraft: plan.isDraft,
                    exercises: plan.orderedExercises.map { planned in
                        PlannedExerciseSnapshot(
                            name: planned.exerciseName,
                            sortOrder: planned.sortOrder,
                            targetSets: planned.targetSets,
                            targetReps: planned.targetReps,
                            targetWeightKilograms: planned.targetWeight,
                            targetDurationSeconds: planned.targetDurationSeconds,
                            targetSpeedKilometersPerHour: planned.targetSpeed,
                            targetInclinePercent: planned.targetIncline,
                            targetDistanceKilometers: planned.targetDistance
                        )
                    }
                )
            }

        let sessions = ((try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? [])
            .sorted { $0.startedAt > $1.startedAt }
            .map { session in
                SessionSnapshot(
                    startedAt: session.startedAt,
                    endedAt: session.endedAt,
                    planName: session.planName,
                    restSeconds: session.restSeconds,
                    planNotes: session.planNotes,
                    exercises: session.orderedExercises.map { exercise in
                        SessionExerciseSnapshot(
                            name: exercise.exerciseName,
                            kind: exercise.kind.rawValue,
                            sortOrder: exercise.sortOrder,
                            notes: exercise.exerciseNotes,
                            sets: exercise.orderedSets.map { set in
                                SetSnapshot(
                                    sortOrder: set.sortOrder,
                                    reps: set.reps,
                                    weightKilograms: set.weight,
                                    durationSeconds: set.durationSeconds,
                                    speedKilometersPerHour: set.speed,
                                    inclinePercent: set.incline,
                                    distanceKilometers: set.distance,
                                    outcome: outcome(for: set)
                                )
                            }
                        )
                    }
                )
            }

        return Document(
            exportedAt: now,
            unitSystem: unit,
            restDurationSeconds: rest,
            profile: profile,
            bodyMeasurements: measurements,
            customExercises: customExercises,
            plans: plans,
            sessions: sessions
        )
    }

    enum BackupError: Error {
        case csvEncodingFailed
    }

    static func jsonData(from document: Document) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    /// Spreadsheet-friendly log of finished workout rows (not pending).
    static func csvString(from document: Document) -> String {
        var lines = [
            "date,plan,exercise,kind,set,reps,weight_kg,duration_seconds,speed_kmh,incline_percent,distance_km,outcome"
        ]
        let finished = document.sessions.filter { $0.endedAt != nil }
        for session in finished {
            let date = isoDate.string(from: session.startedAt)
            let plan = csvField(session.planName ?? "Workout")
            for exercise in session.exercises {
                for set in exercise.sets where set.outcome != "pending" {
                    let distance = set.distanceKilometers.map { formatNumber($0) } ?? ""
                    lines.append([
                        date,
                        plan,
                        csvField(exercise.name),
                        exercise.kind,
                        "\(set.sortOrder + 1)",
                        "\(set.reps)",
                        formatNumber(set.weightKilograms),
                        "\(set.durationSeconds)",
                        formatNumber(set.speedKilometersPerHour),
                        formatNumber(set.inclinePercent),
                        distance,
                        set.outcome,
                    ].joined(separator: ","))
                }
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func writeExportFiles(
        from document: Document,
        now: Date = .now,
        fileManager: FileManager = .default
    ) throws -> (json: URL, csv: URL) {
        let stamp = filenameDate.string(from: now)
        let directory = fileManager.temporaryDirectory
        let jsonURL = directory.appendingPathComponent("gym-tracker-backup-\(stamp).json")
        let csvURL = directory.appendingPathComponent("gym-tracker-workouts-\(stamp).csv")
        try jsonData(from: document).write(to: jsonURL, options: .atomic)
        guard let csvData = csvString(from: document).data(using: .utf8) else {
            throw BackupError.csvEncodingFailed
        }
        try csvData.write(to: csvURL, options: .atomic)
        return (jsonURL, csvURL)
    }

    /// Wipes user data, preferences, and notifications, then re-seeds the
    /// bundled exercise library and default plans so Welcome is a clean start.
    static func deleteAllData(
        in context: ModelContext,
        defaults: UserDefaults = .standard,
        bundle: Bundle = .main,
        notificationCenter: UNUserNotificationCenter = .current()
    ) throws {
        let sessions = (try? context.fetch(FetchDescriptor<WorkoutSession>())) ?? []
        for session in sessions { context.delete(session) }

        let plans = (try? context.fetch(FetchDescriptor<WorkoutPlan>())) ?? []
        for plan in plans { context.delete(plan) }

        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        for exercise in exercises { context.delete(exercise) }

        let measurements = (try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? []
        for measurement in measurements { context.delete(measurement) }

        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        for profile in profiles { context.delete(profile) }

        AppSettings.resetPreferences(defaults: defaults)
        PlanSeeder.resetSeedTracking(defaults: defaults)
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()

        try context.save()

        ExerciseSeeder.seedIfNeeded(in: context, bundle: bundle)
        PlanSeeder.seedIfNeeded(in: context, bundle: bundle, defaults: defaults)
        try context.save()
    }

    private static func outcome(for set: SetEntry) -> String {
        if set.isSkipped { return "skipped" }
        if set.isFailed { return "failed" }
        if set.isCompleted { return "completed" }
        return "pending"
    }

    private static func csvField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    private static func formatNumber(_ value: Double) -> String {
        if value == value.rounded() {
            return String(Int(value.rounded()))
        }
        return String(format: "%g", value)
    }

    private static let isoDate: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let filenameDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
