import SwiftData
import XCTest
@testable import GymTracker

@MainActor
final class ProfileServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(
            for: Exercise.self, WorkoutPlan.self, WorkoutSession.self, BodyMeasurement.self, UserProfile.self,
            configurations: configuration
        )
        context = container.mainContext
    }

    func testOnboardingCreatesProfileAndWeight() throws {
        let profile = ProfileService.completeOnboarding(
            heightCentimeters: 170,
            weight: 72,
            in: context
        )

        XCTAssertEqual(profile.heightCentimeters, 170)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 1)
        XCTAssertEqual(ProfileService.latestWeight(in: context)?.weight, 72)
    }

    func testSkipOnboardingCreatesProfileWithoutMeasurements() throws {
        let profile = ProfileService.skipOnboarding(in: context)

        XCTAssertNil(profile.heightCentimeters)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BodyMeasurement>()), 0)
    }

    func testSkipOnboardingIsIdempotent() throws {
        ProfileService.skipOnboarding(in: context)
        ProfileService.skipOnboarding(in: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 1)
    }

    func testCompleteOnboardingAfterSkipFillsHeightAndWeight() throws {
        ProfileService.skipOnboarding(in: context)
        let profile = ProfileService.completeOnboarding(
            heightCentimeters: 170,
            weight: 72,
            in: context
        )

        XCTAssertEqual(profile.heightCentimeters, 170)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<UserProfile>()), 1)
        XCTAssertEqual(ProfileService.latestWeight(in: context)?.weight, 72)
    }

    func testUpdateWeightOnTheSameDayDoesNotDuplicate() throws {
        let calendar = Calendar(identifier: .gregorian)
        let morning = calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 8))!
        let evening = calendar.date(from: DateComponents(year: 2026, month: 8, day: 25, hour: 20))!

        ProfileService.completeOnboarding(
            heightCentimeters: 170,
            weight: 72,
            in: context,
            now: morning,
            calendar: calendar
        )
        ProfileService.upsertWeight(71.5, on: evening, in: context, calendar: calendar)

        let measurements = try context.fetch(FetchDescriptor<BodyMeasurement>())
        XCTAssertEqual(measurements.count, 1)
        XCTAssertEqual(measurements.first?.weight, 71.5)
    }

    func testUpdateHeight() throws {
        ProfileService.completeOnboarding(heightCentimeters: 170, weight: 72, in: context)
        ProfileService.updateHeight(172, in: context)

        XCTAssertEqual(ProfileService.profile(in: context)?.heightCentimeters, 172)
    }
}
