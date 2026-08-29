import SwiftData
import SwiftUI

/// Shows the active workout if one is running (including after an app
/// relaunch), otherwise offers ways to start one.
struct WorkoutTabView: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil })
    private var activeSessions: [WorkoutSession]

    @State private var sessionTimer = SessionTimer()
    @State private var savedNotice: SavedWorkoutNotice?

    @Environment(AppNavigation.self) private var navigation

    var body: some View {
        NavigationStack {
            if let session = activeSessions.first {
                ActiveWorkoutView(
                    session: session,
                    sessionTimer: sessionTimer,
                    onWorkoutSaved: { savedNotice = $0 }
                )
            } else {
                StartWorkoutView()
            }
        }
        .sheet(item: $savedNotice) { notice in
            WorkoutSavedSheet(notice: notice) {
                savedNotice = nil
                navigation.openHistory(notice.session)
            }
        }
    }
}

/// Start screen: quick start or start from an existing plan.
private struct StartWorkoutView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation
    @Query(
        filter: #Predicate<WorkoutPlan> { $0.isDraft == false },
        sort: \WorkoutPlan.createdAt,
        order: .reverse
    )
    private var plans: [WorkoutPlan]

    @State private var planToPreview: WorkoutPlan?
    @AppStorage(SettingsKeys.hasDismissedWorkoutOrientation)
    private var hasDismissedOrientation = false

    var body: some View {
        List {
            if !hasDismissedOrientation {
                Section {
                    FirstWorkoutOrientationCard {
                        hasDismissedOrientation = true
                    }
                }
            }

            Section {
                Button {
                    WorkoutSessionService.startEmptySession(in: modelContext)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(GymTheme.red)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quick Start")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("Add exercises as you go")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .accessibilityIdentifier("quickStart")
            }

            if !plans.isEmpty {
                Section("Start from a plan") {
                    ForEach(plans) { plan in
                        PlanStartRow(plan: plan) {
                            planToPreview = plan
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
        .sheet(isPresented: Binding(
            get: { planToPreview != nil },
            set: { if !$0 { planToPreview = nil } }
        )) {
            if let planToPreview {
                PlanPreviewSheet(
                    plan: planToPreview,
                    onStart: {
                        startPlan(planToPreview)
                    },
                    onEdit: {
                        let plan = planToPreview
                        self.planToPreview = nil
                        navigation.openPlanEditor(plan)
                    },
                    onCancel: { self.planToPreview = nil }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func startPlan(_ plan: WorkoutPlan) {
        let session = WorkoutSessionService.startSession(from: plan, in: modelContext)
        session.isFollowAlong = true
        planToPreview = nil
    }
}

private struct FirstWorkoutOrientationCard: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your first workout")
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                Label("Pick Quick Start or a plan below.", systemImage: "1.circle.fill")
                Label("Tick what you did, or Start a timed round.", systemImage: "2.circle.fill")
                Label("Finish, then open History and Progress.", systemImage: "3.circle.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            Button("Got it", action: onDismiss)
                .accessibilityIdentifier("dismissOrientation")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("firstWorkoutOrientation")
    }
}

private struct PlanStartRow: View {
    let plan: WorkoutPlan
    let action: () -> Void

    private var summary: PlanStartSummary { PlanStartSummary.from(plan) }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: summary.modalitySymbol)
                    .foregroundStyle(summary.canStart ? Color.primary : GymTheme.red)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plan.name)
                        .foregroundStyle(.primary)
                    Text(summary.listCaption())
                        .font(.caption)
                        .foregroundStyle(summary.canStart ? Color.secondary : GymTheme.red)
                        .lineLimit(2)
                }
                Spacer()
            }
        }
        .accessibilityIdentifier("startPlan-\(plan.name)")
    }
}

private struct PlanPreviewSheet: View {
    let plan: WorkoutPlan
    let onStart: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void

    private var summary: PlanStartSummary { PlanStartSummary.from(plan) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(plan.name)
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("planPreviewTitle")
                    Text(summary.detailBits().joined(separator: " · "))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("planPreviewSummary")
                    if !summary.canStart {
                        Text(summary.blockedReason)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("planPreviewBlockedReason")
                    }
                }

                if !summary.notes.isEmpty {
                    Section("How to follow this plan") {
                        Text(summary.notes)
                            .accessibilityIdentifier("planPreviewNotes")
                    }
                }

                if !summary.exerciseNames.isEmpty {
                    Section("Exercises") {
                        ForEach(Array(summary.exerciseNames.enumerated()), id: \.offset) { _, name in
                            Text(name)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .accessibilityIdentifier("cancelPlanPreview")
                }
                ToolbarItem(placement: .confirmationAction) {
                    if summary.canStart {
                        Button("Start Workout", action: onStart)
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("startPlanFromPreview")
                    } else {
                        Button("Edit Plan", action: onEdit)
                            .fontWeight(.semibold)
                            .accessibilityIdentifier("editBrokenPlan")
                    }
                }
            }
        }
    }
}

/// Rest duration and unit system preferences.
struct WorkoutSettingsPickers: View {
    @AppStorage(SettingsKeys.unitSystem)
    private var unitSystem: UnitSystem = .metric
    @AppStorage(SettingsKeys.restDurationSeconds)
    private var restDuration: Int = SettingsDefaults.restDurationSeconds

    private static let restOptions = [30, 60, 90, 120, 180, 240, 300]

    var body: some View {
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
    }
}

struct WorkoutSettingsMenu: View {
    var body: some View {
        Menu {
            WorkoutSettingsPickers()
        } label: {
            Label("Settings", systemImage: "gearshape")
        }
    }
}
