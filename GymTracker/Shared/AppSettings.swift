import Foundation

/// Weight unit used as a display label. Values are stored as entered,
/// without conversion, so switching the unit never rewrites data.
enum WeightUnit: String, CaseIterable, Identifiable {
    case kilograms = "kg"
    case pounds = "lb"

    var id: String { rawValue }

    /// Speed is stored as entered. The label follows the weight unit so
    /// a kg user sees km/h and a lb user sees mph.
    var speedLabel: String { self == .kilograms ? "km/h" : "mph" }

    /// Distance follows the speed unit: km/h pairs with km, mph with mi.
    var distanceLabel: String { self == .kilograms ? "km" : "mi" }
}

enum SettingsKeys {
    static let weightUnit = "weightUnit"
    static let restDurationSeconds = "restDurationSeconds"
}

enum SettingsDefaults {
    static let restDurationSeconds = 90
}
