import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case workout, plans, exercises, history, progress
}

@Observable
final class AppNavigation {
    var selectedTab: AppTab = .workout
    var sessionToReveal: WorkoutSession?

    func openHistory(_ session: WorkoutSession) {
        sessionToReveal = session
        selectedTab = .history
    }
}
