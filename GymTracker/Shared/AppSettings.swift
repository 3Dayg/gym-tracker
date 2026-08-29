import Foundation

/// Unit system preference. All values are stored in metric (kg, km/h, km,
/// cm) and converted only for display and entry, so switching the setting
/// back and forth never rewrites or loses data.
enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .metric: "Metric"
        case .imperial: "Imperial"
        }
    }

    var weightLabel: String { self == .metric ? "kg" : "lb" }
    var speedLabel: String { self == .metric ? "km/h" : "mph" }
    var distanceLabel: String { self == .metric ? "km" : "mi" }

    private static let poundsPerKilogram = 2.204_622_621_8
    private static let milesPerKilometer = 0.621_371_192_2

    // MARK: - Weight (canonical: kilograms)

    func displayWeight(fromKilograms kilograms: Double) -> Double {
        self == .metric ? kilograms : kilograms * Self.poundsPerKilogram
    }

    func kilograms(fromDisplayWeight value: Double) -> Double {
        let kilograms = self == .metric ? value : value / Self.poundsPerKilogram
        return kilograms.rounded(toDecimalPlaces: 3)
    }

    // MARK: - Distance (canonical: kilometers)

    func displayDistance(fromKilometers kilometers: Double) -> Double {
        self == .metric ? kilometers : kilometers * Self.milesPerKilometer
    }

    func kilometers(fromDisplayDistance value: Double) -> Double {
        let kilometers = self == .metric ? value : value / Self.milesPerKilometer
        return kilometers.rounded(toDecimalPlaces: 4)
    }

    // MARK: - Speed (canonical: km/h)

    func displaySpeed(fromKilometersPerHour value: Double) -> Double {
        displayDistance(fromKilometers: value)
    }

    func kilometersPerHour(fromDisplaySpeed value: Double) -> Double {
        kilometers(fromDisplayDistance: value)
    }

    /// Plate-style step in the display unit: 2.5 kg or 5 lb.
    var weightStepDisplay: Double { self == .metric ? 2.5 : 5 }

    func bumpKilograms(_ kilograms: Double, byDisplaySteps steps: Int) -> Double {
        let display = displayWeight(fromKilograms: kilograms)
        let next = max(0, display + Double(steps) * weightStepDisplay)
        return self.kilograms(fromDisplayWeight: (next * 10).rounded() / 10)
    }
}

enum AppearancePreference: String, CaseIterable, Identifiable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "Auto"
        }
    }
}

extension Double {
    func rounded(toDecimalPlaces places: Int) -> Double {
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

enum SettingsKeys {
    static let unitSystem = "unitSystem"
    static let restDurationSeconds = "restDurationSeconds"
    static let appearance = "appearance"
    /// Pre-conversion preference: `"kg"` or `"lb"`. Migrated once onto `unitSystem`.
    static let legacyWeightUnit = "weightUnit"
    static let hasDismissedWorkoutOrientation = "hasDismissedWorkoutOrientation"
}

enum SettingsDefaults {
    static let restDurationSeconds = 90
    /// Talking-pace walk, stored as km/h. Imperial users see about 3.1 mph.
    static let walkingSpeedKilometersPerHour = 5.0
}

enum AppSettings {
    /// Maps the old kg/lb toggle onto Metric/Imperial without rewriting stored numbers.
    static func migrateUnitPreferenceIfNeeded(defaults: UserDefaults = .standard) {
        guard defaults.object(forKey: SettingsKeys.unitSystem) == nil else { return }
        if defaults.string(forKey: SettingsKeys.legacyWeightUnit) == "lb" {
            defaults.set(UnitSystem.imperial.rawValue, forKey: SettingsKeys.unitSystem)
        }
        defaults.removeObject(forKey: SettingsKeys.legacyWeightUnit)
    }

    /// Units, rest, appearance, and first-workout card — not the SwiftData store.
    static func resetPreferences(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: SettingsKeys.unitSystem)
        defaults.removeObject(forKey: SettingsKeys.restDurationSeconds)
        defaults.removeObject(forKey: SettingsKeys.appearance)
        defaults.removeObject(forKey: SettingsKeys.legacyWeightUnit)
        defaults.removeObject(forKey: SettingsKeys.hasDismissedWorkoutOrientation)
    }
}
