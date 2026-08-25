import SwiftData
import SwiftUI

@main
struct GymTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [
            Exercise.self,
            WorkoutPlan.self,
            WorkoutSession.self,
            BodyMeasurement.self,
            UserProfile.self,
        ])
    }
}
