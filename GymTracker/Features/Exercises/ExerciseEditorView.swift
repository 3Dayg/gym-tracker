import SwiftData
import SwiftUI

/// Creates a new custom exercise, or edits an existing one when
/// initialized with an exercise.
struct ExerciseEditorView: View {
    private let existingExercise: Exercise?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var muscleGroup: MuscleGroup
    @State private var equipment: Equipment
    @State private var kind: ExerciseKind
    @State private var notes: String

    init(exercise: Exercise? = nil) {
        existingExercise = exercise
        _name = State(initialValue: exercise?.name ?? "")
        _muscleGroup = State(initialValue: exercise?.muscleGroup ?? .chest)
        _equipment = State(initialValue: exercise?.equipment ?? .barbell)
        _notes = State(initialValue: exercise?.notes ?? "")
        _kind = State(initialValue: exercise?.kind ?? .strength)
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)

                Picker("Muscle group", selection: $muscleGroup) {
                    ForEach(MuscleGroup.allCases) { group in
                        Text(group.displayName).tag(group)
                    }
                }

                Picker("Equipment", selection: $equipment) {
                    ForEach(Equipment.allCases) { equipment in
                        Text(equipment.displayName).tag(equipment)
                    }
                }

                Picker("Type", selection: $kind) {
                    ForEach(ExerciseKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }

                Section("Notes") {
                    TextField("Optional notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existingExercise == nil ? "New Exercise" : "Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        if let exercise = existingExercise {
            exercise.name = trimmedName
            exercise.muscleGroup = muscleGroup
            exercise.equipment = equipment
            exercise.notes = notes
            exercise.kind = kind
        } else {
            modelContext.insert(Exercise(
                name: trimmedName,
                muscleGroup: muscleGroup,
                equipment: equipment,
                notes: notes,
                isCustom: true,
                kind: kind
            ))
        }
        dismiss()
    }
}
