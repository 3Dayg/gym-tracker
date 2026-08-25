import Charts
import SwiftUI

/// Chart of top set weight and estimated 1RM over time, plus PR stats,
/// for a single exercise.
struct ExerciseProgressView: View {
    let exercise: Exercise

    @AppStorage(SettingsKeys.weightUnit) private var weightUnit: WeightUnit = .kilograms

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
                    y: .value("Weight", point.topSetWeight),
                    series: .value("Series", "Top set")
                )
                .symbol(.circle)

                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Weight", point.bestEstimatedOneRepMax),
                    series: .value("Series", "Est. 1RM")
                )
                .foregroundStyle(.orange)
                .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                .symbol(.square)
            }
            .chartYAxisLabel(weightUnit.rawValue)
            .chartLegend(.visible)
            .frame(height: 220)

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
                            value: Formatters.weight(records.heaviestWeight, unit: weightUnit)
                        )
                        recordCell(
                            title: "Best est. 1RM",
                            value: Formatters.weight(records.bestEstimatedOneRepMax, unit: weightUnit)
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

            HStack(spacing: 4) {
                chartLegendSwatch(color: .accentColor, label: "Minutes")
                chartLegendSwatch(color: .green, label: "Avg incline %")
            }
            .font(.caption)

            if hasDistance {
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Distance", point.totalDistance)
                    )
                    .foregroundStyle(.purple)
                    .symbol(.circle)
                }
                .chartYAxisLabel(weightUnit.distanceLabel)
                .frame(height: 160)

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
                        recordCell(title: "Top speed", value: Formatters.speed(records.topSpeed, unit: weightUnit))
                    }
                    if records.longestSessionDistance > 0 {
                        GridRow {
                            recordCell(
                                title: "Longest distance",
                                value: Formatters.distance(records.longestSessionDistance, unit: weightUnit)
                            )
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func chartLegendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
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
