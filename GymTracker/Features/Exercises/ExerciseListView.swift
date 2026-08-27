import SwiftData
import SwiftUI

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var muscleGroupFilter: MuscleGroup?
    @State private var isAddingExercise = false

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
            List {
                ForEach(filteredExercises) { exercise in
                    NavigationLink(value: exercise) {
                        HStack {
                            ExerciseRow(exercise: exercise)
                            if exercise.isCustom {
                                Spacer()
                                Text("Custom")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.tint.opacity(0.15), in: Capsule())
                            }
                        }
                    }
                }
                .onDelete(perform: deleteExercises)
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Exercises")
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetailView(exercise: exercise)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    MuscleGroupFilterMenu(selection: $muscleGroupFilter)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        ProfileToolbarButton()
                        Button {
                            isAddingExercise = true
                        } label: {
                            Label("Add Exercise", systemImage: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $isAddingExercise) {
                ExerciseEditorView()
            }
            .overlay {
                if filteredExercises.isEmpty {
                    ContentUnavailableView {
                        Label(
                            searchText.isEmpty && muscleGroupFilter == nil
                                ? "No Exercises"
                                : "No Matching Exercises",
                            systemImage: "dumbbell"
                        )
                    } description: {
                        Text(
                            searchText.isEmpty && muscleGroupFilter == nil
                                ? "Add a custom exercise to get started."
                                : "Try a different search, or add your own."
                        )
                    } actions: {
                        if !searchText.isEmpty || muscleGroupFilter != nil {
                            Button("Clear Filters") {
                                searchText = ""
                                muscleGroupFilter = nil
                            }
                            .accessibilityIdentifier("emptyExercisesClearFilters")
                        }
                        Button("Add Exercise") {
                            isAddingExercise = true
                        }
                        .accessibilityIdentifier("emptyExercisesAddExercise")
                    }
                }
            }
        }
    }

    /// Only custom exercises can be deleted; built-in ones are part of the
    /// seeded library. History stays intact because session entries keep
    /// the exercise name.
    private func deleteExercises(at offsets: IndexSet) {
        for index in offsets {
            let exercise = filteredExercises[index]
            guard exercise.isCustom else { continue }
            modelContext.delete(exercise)
        }
    }
}
