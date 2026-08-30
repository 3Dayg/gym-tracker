import SwiftData
import SwiftUI

struct ProgressTabView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @Environment(AppNavigation.self) private var navigation

    @State private var selectedExercise: Exercise?

    /// Only exercises with logged history are offered for charting.
    private var exercisesWithHistory: [Exercise] {
        exercises.filter {
            switch $0.kind {
            case .strength: !$0.completedSetSamples.isEmpty
            case .timed, .cardio: !$0.completedDurationSamples.isEmpty
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    GymScreenTitle(title: "Progress")
                        .listRowInsets(EdgeInsets(top: GymTheme.titlePadTop, leading: 0, bottom: GymTheme.titlePadBottom, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }

                Section {
                    if exercisesWithHistory.isEmpty {
                        EmptyStateBlock(
                            title: "No progress yet",
                            systemImage: "chart.line.uptrend.xyaxis",
                            description: "Finish a workout to see progress charts.",
                            actionTitle: "Start Workout",
                            actionIdentifier: "emptyProgressStartWorkout",
                            action: { navigation.openWorkout() }
                        )
                        .listRowBackground(Color.clear)
                    } else {
                        NavigationLink {
                            ExerciseProgressPicker(
                                exercises: exercisesWithHistory,
                                selection: $selectedExercise
                            )
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedExercise?.name ?? "Choose…")
                                    .font(GymTheme.rowName)
                                    .foregroundStyle(.primary)
                                Text("Change exercise")
                                    .font(GymTheme.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("chooseProgressExercise")

                        if let exercise = selectedExercise {
                            ExerciseProgressView(exercise: exercise)
                        }
                    }
                } header: {
                    GymSectionLabel(title: "Exercise")
                }

                Section {
                    BodyWeightView()
                } header: {
                    GymSectionLabel(title: "Body weight")
                }
            }
            .font(GymTheme.rowName)
            .scrollContentBackground(.hidden)
            .background(GymTheme.pageFill)
            .gymMockScreenChrome("Progress")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileToolbarButton()
                }
            }
            .onAppear {
                if selectedExercise == nil {
                    selectedExercise = exercisesWithHistory.first
                }
            }
        }
    }
}

private struct ExerciseProgressPicker: View {
    let exercises: [Exercise]
    @Binding var selection: Exercise?
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [Exercise] {
        exercises.filter {
            searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List(filtered) { exercise in
            Button {
                selection = exercise
                dismiss()
            } label: {
                HStack {
                    Text(exercise.name)
                        .font(GymTheme.rowName)
                        .foregroundStyle(.primary)
                    Spacer()
                    if exercise.persistentModelID == selection?.persistentModelID {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.primary)
                    }
                }
            }
            .accessibilityIdentifier("selectProgressExercise-\(exercise.name)")
        }
        .searchable(text: $searchText, prompt: "Search logged exercises")
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }
}
