import Foundation

/// Display formatting. Weight, speed, and distance take canonical metric
/// values (kg, km/h, km) and convert to the given unit system.
enum Formatters {
    /// "82.5" — up to one decimal, no trailing ".0".
    private static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// "82.5 kg" / "181.9 lb" — from canonical kilograms.
    static func weight(_ kilograms: Double, unit: UnitSystem) -> String {
        "\(number(unit.displayWeight(fromKilograms: kilograms))) \(unit.weightLabel)"
    }

    /// "1h 12m" / "45m" / "0m"
    static func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    /// "45 sec" / "3 min" / "1:30 min"
    static func durationSeconds(_ value: Int) -> String {
        let seconds = max(0, value)
        if seconds < 60 { return "\(seconds) sec" }
        if seconds.isMultiple(of: 60) { return "\(seconds / 60) min" }
        return String(format: "%d:%02d min", seconds / 60, seconds % 60)
    }

    /// "5 km/h" / "3.1 mph" — from canonical km/h.
    static func speed(_ kilometersPerHour: Double, unit: UnitSystem) -> String {
        "\(number(unit.displaySpeed(fromKilometersPerHour: kilometersPerHour))) \(unit.speedLabel)"
    }

    /// "12%"
    static func incline(_ value: Double) -> String {
        "\(number(value))%"
    }

    /// "2.5 km" / "1.55 mi" — from canonical kilometers.
    static func distance(_ kilometers: Double, unit: UnitSystem) -> String {
        let value = unit.displayDistance(fromKilometers: kilometers)
        return "\(value.formatted(.number.precision(.fractionLength(0...2)))) \(unit.distanceLabel)"
    }

    /// One line for a logged row, built from the metrics of its kind,
    /// e.g. "10 × 80 kg" or "10 min · 5 km/h · 12% · 0.83 km".
    static func setSummary(_ set: SetEntry, kind: ExerciseKind, unit: UnitSystem) -> String {
        if set.isSkipped { return "Skipped" }
        let summary = kind.metrics.compactMap { metric -> String? in
            switch metric {
            case .weight: "\(set.reps) × \(weight(set.weight, unit: unit))"
            case .reps: nil // Shown together with the weight.
            case .duration: durationSeconds(set.durationSeconds)
            case .speed: speed(set.speed, unit: unit)
            case .incline: incline(set.incline)
            case .distance: set.distance.map { distance($0, unit: unit) }
            }
        }
        .joined(separator: " · ")
        return set.isFailed ? "\(summary) · Failed" : summary
    }

    /// "1:30" — minutes:seconds countdown display.
    static func countdown(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        return String(format: "%d:%02d", clamped / 60, clamped % 60)
    }

    /// Live elapsed workout time: "4:12" or "1:02:08".
    static func elapsed(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
