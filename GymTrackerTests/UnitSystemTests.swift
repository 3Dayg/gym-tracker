import XCTest
@testable import GymTracker

final class UnitSystemTests: XCTestCase {
    func testImperialWeightRoundTripFromKilograms() {
        let stored = 100.0
        let displayed = UnitSystem.imperial.displayWeight(fromKilograms: stored)
        XCTAssertEqual(displayed, 220.46, accuracy: 0.01)

        let roundedDisplay = displayed.rounded(toDecimalPlaces: 1)
        let restored = UnitSystem.imperial.kilograms(fromDisplayWeight: roundedDisplay)
        XCTAssertEqual(restored, stored, accuracy: 0.05)
        XCTAssertTrue(Formatters.weight(restored, unit: .metric).hasSuffix(" kg"))
        XCTAssertTrue(Formatters.weight(stored, unit: .imperial).hasSuffix(" lb"))
        XCTAssertEqual(
            UnitSystem.imperial.displayWeight(fromKilograms: stored).rounded(toDecimalPlaces: 1),
            220.5,
            accuracy: 0.05
        )
    }

    func testImperialDistanceRoundTripFromKilometers() {
        let stored = 5.0
        let displayed = UnitSystem.imperial.displayDistance(fromKilometers: stored)
        XCTAssertEqual(displayed, 3.11, accuracy: 0.01)

        let roundedDisplay = displayed.rounded(toDecimalPlaces: 2)
        let restored = UnitSystem.imperial.kilometers(fromDisplayDistance: roundedDisplay)
        XCTAssertEqual(restored, stored, accuracy: 0.01)
        XCTAssertTrue(Formatters.distance(stored, unit: .metric).hasSuffix(" km"))
        XCTAssertTrue(Formatters.distance(stored, unit: .imperial).hasSuffix(" mi"))
    }

    func testMetricPassThroughDoesNotChangeValues() {
        XCTAssertEqual(UnitSystem.metric.displayWeight(fromKilograms: 82.5), 82.5)
        XCTAssertEqual(UnitSystem.metric.kilograms(fromDisplayWeight: 82.5), 82.5)
        XCTAssertEqual(UnitSystem.metric.displayDistance(fromKilometers: 1.25), 1.25)
        XCTAssertEqual(UnitSystem.metric.kilometers(fromDisplayDistance: 1.25), 1.25)
        XCTAssertEqual(UnitSystem.metric.displaySpeed(fromKilometersPerHour: 5), 5)
    }

    func testSpeedUsesTheSameFactorAsDistance() {
        let kmh = 5.0
        let mph = UnitSystem.imperial.displaySpeed(fromKilometersPerHour: kmh)
        XCTAssertEqual(mph, 3.11, accuracy: 0.01)
        XCTAssertEqual(
            UnitSystem.imperial.kilometersPerHour(fromDisplaySpeed: mph.rounded(toDecimalPlaces: 2)),
            kmh,
            accuracy: 0.01
        )
        XCTAssertTrue(Formatters.speed(kmh, unit: .imperial).hasSuffix(" mph"))
    }

    func testMigratesLegacyPoundsPreference() {
        let defaults = UserDefaults(suiteName: "UnitSystemTests-\(UUID().uuidString)")!
        defaults.set("lb", forKey: SettingsKeys.legacyWeightUnit)

        AppSettings.migrateUnitPreferenceIfNeeded(defaults: defaults)

        XCTAssertEqual(defaults.string(forKey: SettingsKeys.unitSystem), UnitSystem.imperial.rawValue)
        XCTAssertNil(defaults.object(forKey: SettingsKeys.legacyWeightUnit))
    }

    func testDoesNotOverwriteAnExistingUnitSystem() {
        let defaults = UserDefaults(suiteName: "UnitSystemTests-\(UUID().uuidString)")!
        defaults.set(UnitSystem.metric.rawValue, forKey: SettingsKeys.unitSystem)
        defaults.set("lb", forKey: SettingsKeys.legacyWeightUnit)

        AppSettings.migrateUnitPreferenceIfNeeded(defaults: defaults)

        XCTAssertEqual(defaults.string(forKey: SettingsKeys.unitSystem), UnitSystem.metric.rawValue)
        XCTAssertEqual(defaults.string(forKey: SettingsKeys.legacyWeightUnit), "lb")
    }
}
