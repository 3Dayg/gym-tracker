import SwiftData
import SwiftUI

/// Shows the active workout if one is running (including after an app
/// relaunch), otherwise offers ways to start one.
struct WorkoutTabView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil })
    private var activeSessions: [WorkoutSession]

    @State private var restTimer = RestTimer()

    var body: some View {
        NavigationStack {
            if let session = activeSessions.first {
                ActiveWorkoutView(session: session, restTimer: restTimer)
            } else {
                StartWorkoutView()
            }
        }
    }
}

/// Start screen: quick start or start from an existing plan.
private struct StartWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutPlan.createdAt, order: .reverse) private var plans: [WorkoutPlan]

    var body: some View {
        List {
            Section {
                Button {
                    WorkoutSessionService.startEmptySession(in: modelContext)
                } label: {
                    Label("Quick Start", systemImage: "bolt.fill")
                        .font(.headline)
                }
            }

            if !plans.isEmpty {
                Section("Start from a plan") {
                    ForEach(plans) { plan in
                        Button {
                            WorkoutSessionService.startSession(from: plan, in: modelContext)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plan.name)
                                    .foregroundStyle(.primary)
                                Text(planSummary(plan))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Workout")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ProfileToolbarButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                WorkoutSettingsMenu()
            }
        }
    }

    private func planSummary(_ plan: WorkoutPlan) -> String {
        let count = plan.exercises.count
        return count == 1 ? "1 exercise" : "\(count) exercises"
    }
}

/// Rest duration and unit system preferences.
struct WorkoutSettingsMenu: View {
    @AppStorage(SettingsKeys.unitSystem)
    private var unitSystem: UnitSystem = .metric
    @AppStorage(SettingsKeys.restDurationSeconds)
    private var restDuration: Int = SettingsDefaults.restDurationSeconds

    private static let restOptions = [30, 60, 90, 120, 180, 240, 300]

    var body: some View {
        Menu {
            Picker("Rest timer", selection: $restDuration) {
                ForEach(Self.restOptions, id: \.self) { seconds in
                    Text(Formatters.countdown(seconds)).tag(seconds)
                }
            }
            .pickerStyle(.menu)

            Picker("Units", selection: $unitSystem) {
                ForEach(UnitSystem.allCases) { unit in
                    Text(unit.displayName).tag(unit)
                }
            }
            .pickerStyle(.menu)
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }
}
