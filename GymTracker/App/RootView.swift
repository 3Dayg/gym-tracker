import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @State private var navigation = AppNavigation()
    @AppStorage(SettingsKeys.appearance) private var appearance: AppearancePreference = .system

    var body: some View {
        Group {
            if profiles.isEmpty {
                OnboardingView()
            } else {
                MainTabView(navigation: navigation)
            }
        }
        .environment(navigation)
        .preferredColorScheme(preferredColorScheme)
        .task {
            AppSettings.migrateUnitPreferenceIfNeeded()
            if ProcessInfo.processInfo.arguments.contains("-inMemoryStore") {
                // Plan seeds also write UserDefaults; reset so a blank store
                // still gets Boxing Conditioning A–C and Incline Walk.
                PlanSeeder.resetSeedTracking()
                UserDefaults.standard.removeObject(forKey: SettingsKeys.hasDismissedWorkoutOrientation)
                UserDefaults.standard.removeObject(forKey: SettingsKeys.appearance)
            }
            // Exercises first: plan seeds reference them by name.
            ExerciseSeeder.seedIfNeeded(in: modelContext)
            PlanSeeder.seedIfNeeded(in: modelContext)
            UITestFixtures.seedIfNeeded(in: modelContext)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

private struct MainTabView: View {
    @Bindable var navigation: AppNavigation

    var body: some View {
        TabView(selection: $navigation.selectedTab) {
            WorkoutTabView()
                .tabItem { Label("Workout", systemImage: "figure.strengthtraining.traditional") }
                .tag(AppTab.workout)

            PlanListView()
                .tabItem { Label("Plans", systemImage: "list.bullet.rectangle") }
                .tag(AppTab.plans)

            ExerciseListView()
                .tabItem { Label("Exercises", systemImage: "dumbbell") }
                .tag(AppTab.exercises)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(AppTab.history)

            ProgressTabView()
                .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.progress)
        }
        .tint(GymTheme.sport)
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
