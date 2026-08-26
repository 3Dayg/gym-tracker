import SwiftUI

struct SessionDetailView: View {
    let session: WorkoutSession

    @AppStorage(SettingsKeys.unitSystem) private var unitSystem: UnitSystem = .metric

    var body: some View {
        List {
            Section {
                LabeledContent("Date") {
                    Text(session.startedAt, format: .dateTime.day().month().year().hour().minute())
                }
                LabeledContent("Duration", value: Formatters.duration(session.duration))
                if session.totalVolume > 0 {
                    LabeledContent(
                        "Total volume",
                        value: Formatters.weight(session.totalVolume, unit: unitSystem)
                    )
                }
                if session.completedCardioSeconds > 0 {
                    LabeledContent(
                        "Cardio time",
                        value: Formatters.durationSeconds(session.completedCardioSeconds)
                    )
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
                            .foregroundStyle(set.isSkipped || set.isFailed ? .secondary : .primary)
                        }
                    }
                }
            }
        }
        .navigationTitle(session.planName ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
    }
}
