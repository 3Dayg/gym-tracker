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
                Section(sessionExercise.exerciseName) {
                    ForEach(Array(sessionExercise.orderedSets.enumerated()), id: \.element) { index, set in
                        HStack {
                            Text("\(sessionExercise.kind.setLabel) \(index + 1)")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(
                                Formatters.setSummary(
                                    set,
                                    kind: sessionExercise.kind,
                                    unit: unitSystem
                                )
                            )
                            .monospacedDigit()
                            .foregroundStyle(
                                set.isFailed ? GymTheme.failed : (set.isSkipped ? .secondary : .primary)
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(session.planName ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}
