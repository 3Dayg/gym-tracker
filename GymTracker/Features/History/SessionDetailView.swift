import SwiftUI

struct SessionDetailView: View {
    let session: WorkoutSession

    @AppStorage(SettingsKeys.unitSystem) private var unitSystem: UnitSystem = .metric

    private var summary: SessionHistorySummary {
        SessionHistorySummary.from(session)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Date") {
                    Text(session.startedAt, format: .dateTime.day().month().year().hour().minute())
                }
                LabeledContent("Duration", value: Formatters.duration(session.duration))
                if summary.strengthSets > 0 {
                    LabeledContent(
                        summary.strengthSets == 1 ? "Set" : "Sets",
                        value: "\(summary.strengthSets)"
                    )
                    .accessibilityIdentifier("historyDetailStrengthSets")
                    if summary.strengthVolumeKilograms > 0 {
                        LabeledContent(
                            "Total volume",
                            value: Formatters.weight(summary.strengthVolumeKilograms, unit: unitSystem)
                        )
                    }
                }
                if summary.timedRounds > 0 {
                    LabeledContent(
                        summary.timedRounds == 1 ? "Round" : "Rounds",
                        value: "\(summary.timedRounds)"
                    )
                    LabeledContent(
                        "Work time",
                        value: Formatters.durationSeconds(summary.timedSeconds)
                    )
                }
                if summary.cardioBlocks > 0 {
                    LabeledContent(
                        summary.cardioBlocks == 1 ? "Cardio set" : "Cardio sets",
                        value: "\(summary.cardioBlocks)"
                    )
                    .accessibilityIdentifier("historyDetailCardioSets")
                    LabeledContent(
                        "Cardio time",
                        value: Formatters.durationSeconds(summary.cardioSeconds)
                    )
                    if summary.cardioDistanceKilometers > 0 {
                        LabeledContent(
                            "Distance",
                            value: Formatters.distance(summary.cardioDistanceKilometers, unit: unitSystem)
                        )
                    }
                }
                if summary.skippedCount > 0 {
                    LabeledContent("Skipped", value: "\(summary.skippedCount)")
                }
            }

            ForEach(session.orderedExercises) { sessionExercise in
                SessionExerciseHistorySection(
                    sessionExercise: sessionExercise,
                    unitSystem: unitSystem
                )
            }
        }
        .navigationTitle(session.planName ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SessionExerciseHistorySection: View {
    let sessionExercise: SessionExercise
    let unitSystem: UnitSystem

    var body: some View {
        Section(sessionExercise.exerciseName) {
            ForEach(Array(sessionExercise.orderedSets.enumerated()), id: \.offset) { index, set in
                HistorySetRow(
                    label: "\(sessionExercise.kind.setLabel) \(index + 1)",
                    summary: Formatters.setSummary(set, kind: sessionExercise.kind, unit: unitSystem),
                    isFailed: set.isFailed,
                    isSkipped: set.isSkipped
                )
            }
        }
    }
}

private struct HistorySetRow: View {
    let label: String
    let summary: String
    let isFailed: Bool
    let isSkipped: Bool

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(summary)
                .monospacedDigit()
                .foregroundStyle(valueColor)
        }
    }

    private var valueColor: Color {
        if isFailed { return GymTheme.failed }
        if isSkipped { return .secondary }
        return .primary
    }
}
