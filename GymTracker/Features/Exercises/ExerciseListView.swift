import SwiftData
import SwiftUI

struct ExerciseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var searchText = ""
    @State private var muscleGroupFilter: MuscleGroup?
    @State private var isAddingExercise = false
    @State private var exercisePendingDelete: Exercise?

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
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if exercise.isCustom {
                            Button("Delete") {
                                exercisePendingDelete = exercise
                            }
                            .tint(.red)
                            .accessibilityIdentifier("deleteCustomExercise")
                        }
                    }
                }
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
            .sheet(isPresented: Binding(
                get: { exercisePendingDelete != nil },
                set: { if !$0 { exercisePendingDelete = nil } }
            )) {
                if let exercisePendingDelete {
                    DeleteCustomExerciseSheet(
                        exerciseName: exercisePendingDelete.name,
                        planNames: ExerciseService.affectedPlanNames(for: exercisePendingDelete),
                        onDelete: {
                            ExerciseService.deleteCustom(exercisePendingDelete, in: modelContext)
                            try? modelContext.save()
                            self.exercisePendingDelete = nil
                        },
                        onKeep: { self.exercisePendingDelete = nil }
                    )
                    .presentationDetents([.medium])
                    .interactiveDismissDisabled()
                }
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
}

private struct DeleteCustomExerciseSheet: View {
    let exerciseName: String
    let planNames: [String]
    let onDelete: () -> Void
    let onKeep: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(warning)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("deleteExerciseWarning")
                }
            }
            .navigationTitle("Delete \(exerciseName)?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep Exercise", action: onKeep)
                        .accessibilityIdentifier("keepCustomExercise")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete Exercise", role: .destructive, action: onDelete)
                        .accessibilityIdentifier("confirmDeleteCustomExercise")
                }
            }
        }
    }

    private var warning: String {
        var parts = [
            "Past workouts keep this name. It will be removed from any plans that use it."
        ]
        if !planNames.isEmpty {
            parts.append("Used in: \(planNames.joined(separator: ", ")).")
        }
        return parts.joined(separator: " ")
    }
}
