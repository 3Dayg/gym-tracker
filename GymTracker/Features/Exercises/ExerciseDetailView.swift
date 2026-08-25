import SwiftData
import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise

    @AppStorage(SettingsKeys.weightUnit) private var weightUnit: WeightUnit = .kilograms
    @State private var isEditing = false

    /// Completed sets from finished sessions, most recent session first.
    private var recentHistory: [(date: Date, sets: [SetEntry])] {
        exercise.sessionExercises
            .compactMap { sessionExercise -> (date: Date, sets: [SetEntry])? in
                guard
                    let session = sessionExercise.session,
                    let endedAt = session.endedAt
                else { return nil }
                let completed = sessionExercise.orderedSets.filter(\.isCompleted)
                return completed.isEmpty ? nil : (endedAt, completed)
            }
            .sorted { $0.date > $1.date }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        List {
            Section("Details") {
                LabeledContent("Muscle group", value: exercise.muscleGroup.displayName)
                LabeledContent("Equipment", value: exercise.equipment.displayName)
                LabeledContent("Type", value: exercise.kind.displayName)
                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Recent history") {
                if recentHistory.isEmpty {
                    Text("No logged sets yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(recentHistory, id: \.date) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.date, style: .date)
                                .font(.subheadline.weight(.medium))
                            Text(setsSummary(entry.sets))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if exercise.isCustom {
                Button("Edit") { isEditing = true }
            }
        }
        .sheet(isPresented: $isEditing) {
            ExerciseEditorView(exercise: exercise)
        }
    }

    private func setsSummary(_ sets: [SetEntry]) -> String {
        sets
            .map { Formatters.setSummary($0, kind: exercise.kind, weightUnit: weightUnit) }
            .joined(separator: ", ")
    }
}
