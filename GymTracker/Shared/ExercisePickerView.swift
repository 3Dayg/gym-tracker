import SwiftData
import SwiftUI

/// Searchable exercise picker used by the plan builder and the active
/// workout. Calls `onSelect` for each chosen exercise. Multiple selection
/// waits for Add; single selection dismisses on tap.
struct ExercisePickerView: View {
    var allowsMultipleSelection = false
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var muscleGroupFilter: MuscleGroup?
    @State private var selectedIDs: Set<PersistentIdentifier> = []
    @State private var selectionOrder: [PersistentIdentifier] = []

    private var filteredExercises: [Exercise] {
        exercises.filter { exercise in
            let matchesGroup = muscleGroupFilter.map { exercise.muscleGroup == $0 } ?? true
            let matchesSearch = searchText.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(searchText)
            return matchesGroup && matchesSearch
        }
    }

    private var recentExercises: [Exercise] {
        guard searchText.isEmpty, muscleGroupFilter == nil else { return [] }
        return WorkoutSessionService.recentlyLoggedExercises(from: exercises)
    }

    private var remainingExercises: [Exercise] {
        let recentIDs = Set(recentExercises.map(\.persistentModelID))
        return filteredExercises.filter { !recentIDs.contains($0.persistentModelID) }
    }

    var body: some View {
        List(selection: allowsMultipleSelection ? $selectedIDs : nil) {
            Section {
                TextField("Search exercises", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("searchExercises")
            }
            .selectionDisabled()

            if !recentExercises.isEmpty {
                Section("Recent") {
                    ForEach(recentExercises) { exercise in
                        row(for: exercise)
                            .tag(exercise.persistentModelID)
                            .accessibilityIdentifier("recentExercise-\(exercise.name)")
                    }
                }
            }

            Section {
                ForEach(remainingExercises) { exercise in
                    row(for: exercise)
                        .tag(exercise.persistentModelID)
                        .accessibilityIdentifier("toggleExercise-\(exercise.name)")
                }
            }
        }
        .environment(\.editMode, .constant(allowsMultipleSelection ? .active : .inactive))
        .onChange(of: selectedIDs) { _, newValue in
            selectionOrder.removeAll { !newValue.contains($0) }
            for id in newValue where !selectionOrder.contains(id) {
                selectionOrder.append(id)
            }
        }
        .navigationTitle(allowsMultipleSelection ? "Choose Exercises" : "Choose Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { close() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                MuscleGroupFilterMenu(selection: $muscleGroupFilter)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if allowsMultipleSelection {
                Button(action: confirmMultiple) {
                    Text(addButtonTitle)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedIDs.isEmpty)
                .accessibilityIdentifier("confirmAddExercises")
                .padding()
                .background(.bar)
            }
        }
    }

    private var addButtonTitle: String {
        selectedIDs.isEmpty ? "Add" : "Add \(selectedIDs.count)"
    }

    @ViewBuilder
    private func row(for exercise: Exercise) -> some View {
        if allowsMultipleSelection {
            ExerciseRow(exercise: exercise)
        } else {
            Button {
                onSelect(exercise)
                close()
            } label: {
                ExerciseRow(exercise: exercise)
            }
            .buttonStyle(.plain)
        }
    }

    private func confirmMultiple() {
        let byID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.persistentModelID, $0) })
        for id in selectionOrder {
            if let exercise = byID[id] {
                onSelect(exercise)
            }
        }
        close()
    }

    private func close() {
        dismiss()
    }
}

/// Compact one-line summary of an exercise, reused across lists.
struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
            Text("\(exercise.muscleGroup.displayName) · \(exercise.equipment.displayName)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct MuscleGroupFilterMenu: View {
    @Binding var selection: MuscleGroup?

    var body: some View {
        Menu {
            Picker("Muscle Group", selection: $selection) {
                Text("All").tag(MuscleGroup?.none)
                ForEach(MuscleGroup.allCases) { group in
                    Text(group.displayName).tag(MuscleGroup?.some(group))
                }
            }
        } label: {
            Label(
                "Filter",
                systemImage: selection == nil
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }
}
