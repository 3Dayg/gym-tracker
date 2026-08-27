import Charts
import SwiftUI

/// Chart of top set weight and estimated 1RM over time, plus PR stats,
/// for a single exercise.
struct ExerciseProgressView: View {
    let exercise: Exercise

    @AppStorage(SettingsKeys.unitSystem) private var unitSystem: UnitSystem = .metric

    private var points: [ExerciseProgressPoint] {
        ProgressMath.progressPoints(from: exercise.completedSetSamples)
    }

    private var records: PersonalRecords? {
        ProgressMath.personalRecords(from: exercise.completedSetSamples)
    }

    var body: some View {
        switch exercise.kind {
        case .strength:
            strengthProgress
        case .timed:
            timedProgress
        case .cardio:
            cardioProgress
        }
    }

    private var strengthProgress: some View {
        VStack(alignment: .leading, spacing: 16) {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", unitSystem.displayWeight(fromKilograms: point.topSetWeight)),
                    series: .value("Series", "Top set")
                )
                .symbol(.circle)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", unitSystem.displayWeight(fromKilograms: point.bestEstimatedOneRepMax)),
                    series: .value("Series", "Est. 1RM")
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                .symbol(.square)
            }
            .chartYAxisLabel(unitSystem.weightLabel)
            .chartLegend(.visible)
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Top set and estimated one-rep max")
            .accessibilityValue(strengthChartSummary)

            HStack(spacing: 4) {
                chartLegendSwatch(color: .accentColor, label: "Top set")
                chartLegendSwatch(color: .orange, label: "Est. 1RM")
            }
            .font(.caption)

            if let records {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        recordCell(
                            title: "Heaviest set",
                            value: Formatters.weight(records.heaviestWeight, unit: unitSystem)
                        )
                        recordCell(
                            title: "Best est. 1RM",
                            value: Formatters.weight(records.bestEstimatedOneRepMax, unit: unitSystem)
                        )
                        recordCell(
                            title: "Most reps",
                            value: "\(records.mostRepsInASet)"
                        )
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var timedProgress: some View {
        let samples = exercise.completedDurationSamples
        let points = ProgressMath.cardioPoints(from: samples)
        let records = ProgressMath.timedRecords(from: samples)

        return VStack(alignment: .leading, spacing: 16) {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Minutes", point.totalMinutes),
                    series: .value("Series", "Time")
                )
                .symbol(.circle)
            }
            .chartYAxisLabel("min")
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Minutes per day")
            .accessibilityValue(timedChartSummary(points))

            HStack(spacing: 4) {
                chartLegendSwatch(color: .accentColor, label: "Total minutes per day")
            }
            .font(.caption)

            if let records {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        recordCell(
                            title: "Longest round",
                            value: Formatters.durationSeconds(records.longestBlockSeconds)
                        )
                        recordCell(
                            title: "Longest session",
                            value: Formatters.durationSeconds(records.longestSessionSeconds)
                        )
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var cardioProgress: some View {
        let samples = exercise.completedDurationSamples
        let points = ProgressMath.cardioPoints(from: samples)
        let records = ProgressMath.cardioRecords(from: samples)
        let hasDistance = points.contains { $0.totalDistance > 0 }

        return VStack(alignment: .leading, spacing: 16) {
            Chart(points) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Minutes", point.totalMinutes),
                    series: .value("Series", "Time")
                )
                .symbol(.circle)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Incline", point.averageIncline),
                    series: .value("Series", "Incline")
                )
                .foregroundStyle(.green)
                .symbol(.square)
            }
            .frame(height: 220)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Cardio minutes and incline")
            .accessibilityValue(cardioTimeChartSummary(points))

            HStack(spacing: 4) {
                chartLegendSwatch(color: .accentColor, label: "Minutes")
                chartLegendSwatch(color: .green, label: "Avg incline %")
            }
            .font(.caption)

            if hasDistance {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Distance", unitSystem.displayDistance(fromKilometers: point.totalDistance))
                    )
                    .foregroundStyle(.purple)
                    .symbol(.circle)
                }
                .chartYAxisLabel(unitSystem.distanceLabel)
                .frame(height: 160)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Distance per day")
                .accessibilityValue(cardioDistanceChartSummary(points))

                HStack(spacing: 4) {
                    chartLegendSwatch(color: .purple, label: "Distance per day")
                }
                .font(.caption)
            }

            if let records {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                    GridRow {
                        recordCell(
                            title: "Longest session",
                            value: Formatters.durationSeconds(records.longestSessionSeconds)
                        )
                        recordCell(title: "Steepest incline", value: Formatters.incline(records.steepestIncline))
                        recordCell(title: "Top speed", value: Formatters.speed(records.topSpeed, unit: unitSystem))
                    }
                    if records.longestSessionDistance > 0 {
                        GridRow {
                            recordCell(
                                title: "Longest distance",
                                value: Formatters.distance(records.longestSessionDistance, unit: unitSystem)
                            )
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var strengthChartSummary: String {
        guard let latest = points.last else { return "No logged sets yet" }
        let top = Formatters.weight(latest.topSetWeight, unit: unitSystem)
        if points.count == 1 {
            return "One workout. Top set \(top)."
        }
        return "\(points.count) workouts. Latest top set \(top)."
    }

    private func timedChartSummary(_ points: [CardioProgressPoint]) -> String {
        guard let latest = points.last else { return "No logged time yet" }
        let minutes = Formatters.durationSeconds(latest.totalSeconds)
        if points.count == 1 {
            return "One day. \(minutes) of work."
        }
        return "\(points.count) days. Latest \(minutes)."
    }

    private func cardioTimeChartSummary(_ points: [CardioProgressPoint]) -> String {
        guard let latest = points.last else { return "No logged cardio yet" }
        return "\(points.count) days. Latest \(Formatters.durationSeconds(latest.totalSeconds)), incline \(Formatters.incline(latest.averageIncline))."
    }

    private func cardioDistanceChartSummary(_ points: [CardioProgressPoint]) -> String {
        guard let latest = points.last else { return "No distance yet" }
        return "Latest \(Formatters.distance(latest.totalDistance, unit: unitSystem))."
    }

    private func chartLegendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8).accessibilityHidden(true)
            Text(label).foregroundStyle(.secondary)
        }
        .padding(.trailing, 8)
    }

    private func recordCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }
}
