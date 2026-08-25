import SwiftData
import SwiftUI

/// Searchable exercise picker used by the plan builder and the active
/// workout. Calls `onSelect` for the chosen exercise and dismisses itself.
struct ExercisePickerView: View {
    let onSelect: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var muscleGroupFilter: MuscleGroup?

    private var filteredExercises: [Exercise] {
        exercises.filter { exercise in
            let matchesGroup = muscleGroupFilter.map { exercise.muscleGroup == $0 } ?? true
            let matchesSearch = searchText.isEmpty
                || exercise.name.localizedCaseInsensitiveContains(searchText)
            return matchesGroup && matchesSearch
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredExercises) { exercise in
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    ExerciseRow(exercise: exercise)
                }
                .buttonStyle(.plain)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Choose Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MuscleGroupFilterMenu(selection: $muscleGroupFilter)
                }
            }
        }
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
