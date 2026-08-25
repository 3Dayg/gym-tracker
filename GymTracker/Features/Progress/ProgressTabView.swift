import SwiftData
import SwiftUI

struct ProgressTabView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

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
                    NavigationLink {
                        ProfileView()
                    } label: {
                        Label("Profile", systemImage: "person.crop.circle")
                    }
                }

                Section("Exercise progress") {
                    if exercisesWithHistory.isEmpty {
                        Text("Finish a workout to see progress charts.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Exercise", selection: $selectedExercise) {
                            Text("Choose…").tag(Exercise?.none)
                            ForEach(exercisesWithHistory) { exercise in
                                Text(exercise.name).tag(Exercise?.some(exercise))
                            }
                        }

                        if let exercise = selectedExercise {
                            ExerciseProgressView(exercise: exercise)
                        }
                    }
                }

                Section("Body weight") {
                    BodyWeightView()
                }
            }
            .navigationTitle("Progress")
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
