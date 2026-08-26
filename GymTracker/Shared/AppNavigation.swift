import SwiftData
import SwiftUI

enum AppTab: Hashable {
    case workout, plans, exercises, history, progress
}

@Observable
final class AppNavigation {
    var selectedTab: AppTab = .workout
    var sessionToReveal: WorkoutSession?
    var planToEdit: WorkoutPlan?

    func openHistory(_ session: WorkoutSession) {
        sessionToReveal = session
        selectedTab = .history
    }

    func openPlanEditor(_ plan: WorkoutPlan) {
        planToEdit = plan
        selectedTab = .plans
    }
}
