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
            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", unitSystem.displayWeight(fromKilograms: point.topSetWeight)),
                        series: .value("Series", "Top set")
                    )
                    .foregroundStyle(Color.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(.circle)

                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", unitSystem.displayWeight(fromKilograms: point.bestEstimatedOneRepMax)),
                        series: .value("Series", "Est. 1RM")
                    )
                    .foregroundStyle(GymTheme.sport)
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
                    ChartLegendStroke(color: .primary, label: "Top set")
                    ChartLegendStroke(color: GymTheme.sport, dashed: true, label: "Est. 1RM")
                }
                .font(GymTheme.caption)
            }

            if let records, points.count == 1 {
                recordCell(
                    title: "Heaviest set · one session so far",
                    value: Formatters.weight(records.heaviestWeight, unit: unitSystem)
                )
                HStack(alignment: .top, spacing: GymTheme.pt(16)) {
                    recordCell(
                        title: "Est. 1RM",
                        value: Formatters.weight(records.bestEstimatedOneRepMax, unit: unitSystem)
                    )
                    recordCell(
                        title: "Most reps",
                        value: "\(records.mostRepsInASet)"
                    )
                }
            } else if let records {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 6) {
                    GridRow {
                        recordCell(
                            title: "Heaviest set",
                            value: Formatters.weight(records.heaviestWeight, unit: unitSystem)
                        )
                        recordCell(
                            title: "Est. 1RM",
                            value: Formatters.weight(records.bestEstimatedOneRepMax, unit: unitSystem)
                        )
                        recordCell(
                            title: "Most reps",
                            value: "\(records.mostRepsInASet)"
                        )
                    }
                }
            }

            if points.count == 1 {
                Text("Log a second day to see a trend.")
                    .font(GymTheme.caption)
                    .foregroundStyle(GymTheme.muted)
                    .accessibilityIdentifier("onePointGuidance")
            }

            Text("Est. 1RM is an estimated one-rep max using the Epley formula: weight × (1 + reps ÷ 30). Failed sets are left out.")
                .font(GymTheme.caption)
                .foregroundStyle(GymTheme.muted)
                .accessibilityIdentifier("oneRepMaxFootnote")
        }
        .padding(.vertical, 8)
    }

    private var timedProgress: some View {
        let samples = exercise.completedDurationSamples
        let points = ProgressMath.cardioPoints(from: samples)
        let records = ProgressMath.timedRecords(from: samples)

        return VStack(alignment: .leading, spacing: 16) {
            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Minutes", point.totalMinutes),
                        series: .value("Series", "Time")
                    )
                    .foregroundStyle(Color.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(.circle)
                }
                .chartYAxisLabel("min")
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Minutes per day")
                .accessibilityValue(timedChartSummary(points))

                HStack(spacing: 4) {
                    ChartLegendStroke(color: .primary, label: "Total minutes per day")
                }
                .font(GymTheme.caption)
            }

            if points.count == 1 {
                Text("One day so far. Log another session to see a trend.")
                    .font(GymTheme.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onePointGuidance")
            }

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
            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Minutes", point.totalMinutes),
                        series: .value("Series", "Time")
                    )
                    .foregroundStyle(Color.primary)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(.circle)
                }
                .chartYAxisLabel("min")
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Cardio minutes")
                .accessibilityValue(cardioTimeChartSummary(points))

                HStack(spacing: 4) {
                    ChartLegendStroke(color: .primary, label: "Minutes")
                }
                .font(GymTheme.caption)

                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Incline", point.averageIncline)
                    )
                    .foregroundStyle(GymTheme.sport)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    .symbol(.square)
                }
                .chartYAxisLabel("%")
                .frame(height: 160)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Average incline")
                .accessibilityValue(cardioInclineChartSummary(points))

                HStack(spacing: 4) {
                    ChartLegendStroke(color: GymTheme.sport, dashed: true, label: "Avg incline %")
                }
                .font(GymTheme.caption)

                if hasDistance {
                    Chart(points) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Distance", unitSystem.displayDistance(fromKilometers: point.totalDistance))
                        )
                        .foregroundStyle(Color.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [2, 3]))
                        .symbol(.circle)
                    }
                    .chartYAxisLabel(unitSystem.distanceLabel)
                    .frame(height: 160)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Distance per day")
                    .accessibilityValue(cardioDistanceChartSummary(points))

                    HStack(spacing: 4) {
                        ChartLegendStroke(color: .primary, dotted: true, label: "Distance per day")
                    }
                    .font(GymTheme.caption)
                }
            }

            if points.count == 1 {
                Text("One day so far. Log another session to see a trend.")
                    .font(GymTheme.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("onePointGuidance")
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

    private func cardioInclineChartSummary(_ points: [CardioProgressPoint]) -> String {
        guard let latest = points.last else { return "No incline yet" }
        return "Latest \(Formatters.incline(latest.averageIncline))."
    }

    private func cardioDistanceChartSummary(_ points: [CardioProgressPoint]) -> String {
        guard let latest = points.last else { return "No distance yet" }
        return "Latest \(Formatters.distance(latest.totalDistance, unit: unitSystem))."
    }

    private func recordCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(GymTheme.rowName)
            Text(title)
                .font(GymTheme.caption)
                .foregroundStyle(.secondary)
        }
    }
}
