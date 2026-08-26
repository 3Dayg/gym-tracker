import Foundation
import SwiftData

enum ProfileService {
    static func profile(in context: ModelContext) -> UserProfile? {
        (try? context.fetch(FetchDescriptor<UserProfile>()))?.first
    }

    /// Creates a profile with no height or weight so the user can train
    /// immediately. Units are already stored in settings as they pick them.
    @discardableResult
    static func skipOnboarding(
        in context: ModelContext,
        now: Date = .now
    ) -> UserProfile {
        if let existing = profile(in: context) { return existing }
        let profile = UserProfile(heightCentimeters: nil, createdAt: now)
        context.insert(profile)
        return profile
    }

    @discardableResult
    static func completeOnboarding(
        heightCentimeters: Double,
        weight: Double,
        in context: ModelContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> UserProfile {
        let profile: UserProfile
        if let existing = Self.profile(in: context) {
            profile = existing
            profile.heightCentimeters = heightCentimeters
            profile.updatedAt = now
        } else {
            profile = UserProfile(heightCentimeters: heightCentimeters, createdAt: now)
            context.insert(profile)
        }
        upsertWeight(weight, on: now, in: context, calendar: calendar)
        return profile
    }

    static func updateHeight(_ heightCentimeters: Double, in context: ModelContext, now: Date = .now) {
        guard let profile = profile(in: context) else { return }
        profile.heightCentimeters = heightCentimeters
        profile.updatedAt = now
    }

    /// Writes today's weight. If a measurement already exists for that
    /// calendar day, it is updated instead of adding a duplicate.
    @discardableResult
    static func upsertWeight(
        _ weight: Double,
        on date: Date = .now,
        in context: ModelContext,
        calendar: Calendar = .current
    ) -> BodyMeasurement {
        let day = calendar.startOfDay(for: date)
        let measurements = (try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? []
        if let existing = measurements.first(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            existing.weight = weight
            existing.date = date
            return existing
        }
        let measurement = BodyMeasurement(date: date, weight: weight)
        context.insert(measurement)
        return measurement
    }

    static func latestWeight(in context: ModelContext) -> BodyMeasurement? {
        let measurements = (try? context.fetch(FetchDescriptor<BodyMeasurement>())) ?? []
        return measurements.max(by: { $0.date < $1.date })
    }
}
