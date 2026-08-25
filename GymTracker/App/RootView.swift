import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]

    var body: some View {
        Group {
            if profiles.isEmpty {
                OnboardingView()
            } else {
                mainTabs
            }
        }
        .task {
            // Order matters: kinds are fixed first, legacy data is converted
            // next, and only then are new (already second-based) plans seeded.
            ExerciseSeeder.seedIfNeeded(in: modelContext)
            PlanSeeder.migrateLegacyDataIfNeeded(in: modelContext)
            PlanSeeder.seedIfNeeded(in: modelContext)
        }
    }

    private var mainTabs: some View {
        TabView {
            WorkoutTabView()
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }

            PlanListView()
                .tabItem { Label("Plans", systemImage: "list.bullet.rectangle") }

            ExerciseListView()
                .tabItem { Label("Exercises", systemImage: "dumbbell") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }

            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: [
            Exercise.self,
            WorkoutPlan.self,
            WorkoutSession.self,
            BodyMeasurement.self,
            UserProfile.self,
        ], inMemory: true)
}
