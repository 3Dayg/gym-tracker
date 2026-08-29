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
                                    .overlay(Capsule().stroke(Color.primary, lineWidth: 1))
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
                    ProfileToolbarButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    MuscleGroupFilterMenu(selection: $muscleGroupFilter)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
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
                    ConfirmDestructiveSheet(
                        title: "Delete \(exercisePendingDelete.name)?",
                        message: deleteWarning(for: exercisePendingDelete),
                        keepTitle: "Keep Exercise",
                        deleteTitle: "Delete Exercise",
                        keepIdentifier: "keepCustomExercise",
                        deleteIdentifier: "confirmDeleteCustomExercise",
                        warningIdentifier: "deleteExerciseWarning",
                        onKeep: { self.exercisePendingDelete = nil },
                        onDelete: {
                            ExerciseService.deleteCustom(exercisePendingDelete, in: modelContext)
                            try? modelContext.save()
                            self.exercisePendingDelete = nil
                        }
                    )
                    .presentationDetents([.medium])
                    .interactiveDismissDisabled()
                }
            }
            .overlay {
                if filteredExercises.isEmpty {
                    exerciseEmptyState
                }
            }
        }
    }

    private var isFiltered: Bool {
        !searchText.isEmpty || muscleGroupFilter != nil
    }

    private var exerciseEmptyState: some View {
        EmptyStateBlock(
            title: isFiltered ? "No Matching Exercises" : "No Exercises",
            systemImage: "dumbbell",
            description: isFiltered
                ? "Try a different search, or add your own."
                : "Add a custom exercise to get started.",
            actionTitle: "Add Exercise",
            actionIdentifier: "emptyExercisesAddExercise",
            action: { isAddingExercise = true },
            secondaryActionTitle: isFiltered ? "Clear Filters" : nil,
            secondaryActionIdentifier: isFiltered ? "emptyExercisesClearFilters" : nil,
            secondaryAction: isFiltered ? clearFilters : nil
        )
    }

    private func deleteWarning(for exercise: Exercise) -> String {
        var parts = [
            "Past workouts keep this name. It will be removed from any plans that use it."
        ]
        let planNames = ExerciseService.affectedPlanNames(for: exercise)
        if !planNames.isEmpty {
            parts.append("Used in: \(planNames.joined(separator: ", ")).")
        }
        return parts.joined(separator: " ")
    }

    private func clearFilters() {
        searchText = ""
        muscleGroupFilter = nil
    }
}
