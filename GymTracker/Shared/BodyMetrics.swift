import Foundation

enum BodyMetrics {
    private static let centimetersPerInch = 2.54
    private static let inchesPerFoot = 12.0

    static func centimeters(feet: Int, inches: Double) -> Double {
        (Double(feet) * inchesPerFoot + inches) * centimetersPerInch
    }

    static func feetAndInches(fromCentimeters cm: Double) -> (feet: Int, inches: Double) {
        let totalInches = cm / centimetersPerInch
        let feet = Int(totalInches / inchesPerFoot)
        let inches = totalInches - Double(feet) * inchesPerFoot
        return (feet, inches)
    }

    static func formatHeight(_ centimeters: Double, unit: UnitSystem) -> String {
        switch unit {
        case .metric:
            return "\(Int(centimeters.rounded())) cm"
        case .imperial:
            let parts = feetAndInches(fromCentimeters: centimeters)
            let inches = parts.inches.rounded()
            return "\(parts.feet) ft \(Int(inches)) in"
        }
    }
}
