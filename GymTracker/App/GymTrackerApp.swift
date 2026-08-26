import SwiftData
import SwiftUI

@main
struct GymTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Self.makeModelContainer())
    }

    /// UI tests pass `-inMemoryStore` so each launch is a clean first run.
    private static func makeModelContainer() -> ModelContainer {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-inMemoryStore")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(
                for: Exercise.self,
                WorkoutPlan.self,
                WorkoutSession.self,
                BodyMeasurement.self,
                UserProfile.self,
                configurations: configuration
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
}
