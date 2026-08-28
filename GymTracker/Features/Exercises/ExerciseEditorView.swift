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
    @State private var duplicateNameAlert = false

    init(exercise: Exercise? = nil) {
        existingExercise = exercise
        _name = State(initialValue: exercise?.name ?? "")
        _muscleGroup = State(initialValue: exercise?.muscleGroup ?? .chest)
        _equipment = State(initialValue: exercise?.equipment ?? .barbell)
        _notes = State(initialValue: exercise?.notes ?? "")
        _kind = State(initialValue: exercise?.kind ?? .strength)
    }

    private var trimmedName: String {
        ExerciseService.normalizedName(name)
    }

    private var typeIsLocked: Bool {
        existingExercise.map(ExerciseService.hasLoggedHistory) ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .accessibilityIdentifier("exerciseNameField")

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

                Section {
                    Picker("Type", selection: $kind) {
                        ForEach(ExerciseKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .disabled(typeIsLocked)
                    .accessibilityIdentifier("exerciseTypePicker")
                } footer: {
                    if typeIsLocked {
                        Text("Type is locked because this exercise has been logged. History stays readable.")
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
                        .accessibilityIdentifier("saveExercise")
                }
            }
            .alert("Name already used", isPresented: $duplicateNameAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Choose a different name. Built-in and custom exercises must not share a name.")
            }
        }
    }

    private func save() {
        if ExerciseService.isDuplicateName(
            trimmedName,
            excluding: existingExercise,
            in: modelContext
        ) {
            duplicateNameAlert = true
            return
        }

        if let exercise = existingExercise {
            exercise.name = trimmedName
            exercise.muscleGroup = muscleGroup
            exercise.equipment = equipment
            exercise.notes = notes
            if !typeIsLocked {
                exercise.kind = kind
            }
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
