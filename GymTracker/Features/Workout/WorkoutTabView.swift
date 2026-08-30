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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GymTheme.cardGap) {
                GymScreenTitle(title: "Workout")

                GymCard(padding: 0) {
                    Button {
                        WorkoutSessionService.startEmptySession(in: modelContext)
                    } label: {
                        HStack(spacing: GymTheme.pt(10)) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: GymTheme.pt(16), weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: GymTheme.boltMark, height: GymTheme.boltMark)
                                .background(GymTheme.sport, in: RoundedRectangle(cornerRadius: GymTheme.pt(10), style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Quick Start")
                                    .font(GymTheme.rowName)
                                    .foregroundStyle(.primary)
                                Text("Add exercises as you go")
                                    .font(GymTheme.caption)
                                    .foregroundStyle(GymTheme.muted)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, GymTheme.rowPadX)
                        .padding(.vertical, GymTheme.rowPadY)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("quickStart")
                }

                if !plans.isEmpty {
                    GymSectionLabel(title: "Start from a plan")
                    GymCard(padding: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(plans.enumerated()), id: \.element.persistentModelID) { index, plan in
                                if index > 0 { GymTheme.hairline.frame(height: 0.5) }
                                PlanStartRow(plan: plan) {
                                    planToPreview = plan
                                }
                                .padding(.horizontal, GymTheme.rowPadX)
                                .padding(.vertical, GymTheme.rowPadY)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, GymTheme.pageGutter)
            .padding(.bottom, GymTheme.pt(12))
        }
        .background(GymTheme.pageFill)
        .gymMockScreenChrome("Workout")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ProfileToolbarButton()
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

private struct PlanStartRow: View {
    let plan: WorkoutPlan
    let action: () -> Void

    private var summary: PlanStartSummary { PlanStartSummary.from(plan) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 2) {
                Text(plan.name)
                    .font(GymTheme.rowName)
                    .foregroundStyle(.primary)
                Text(summary.listCaption())
                    .font(GymTheme.caption)
                    .foregroundStyle(summary.canStart ? GymTheme.muted : GymTheme.red)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
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
            ScrollView {
                VStack(alignment: .leading, spacing: GymTheme.cardGap) {
                    GymCard(padding: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plan.name)
                                .font(GymTheme.sheetTitle)
                                .accessibilityIdentifier("planPreviewTitle")
                            Text(summary.detailBits().joined(separator: " · "))
                                .font(GymTheme.caption)
                                .foregroundStyle(GymTheme.muted)
                                .accessibilityIdentifier("planPreviewSummary")
                            if !summary.canStart {
                                Text(summary.blockedReason)
                                    .font(GymTheme.caption)
                                    .foregroundStyle(GymTheme.muted)
                                    .accessibilityIdentifier("planPreviewBlockedReason")
                            }
                        }
                        .padding(.horizontal, GymTheme.rowPadX)
                        .padding(.vertical, GymTheme.rowPadY)
                    }

                    if !summary.notes.isEmpty {
                        GymSectionLabel(title: "How to follow this plan")
                        GymCard(padding: 0) {
                            Text(summary.notes)
                                .font(GymTheme.caption)
                                .foregroundStyle(GymTheme.muted)
                                .padding(.horizontal, GymTheme.rowPadX)
                                .padding(.vertical, GymTheme.rowPadY)
                                .accessibilityIdentifier("planPreviewNotes")
                        }
                    }

                    if !summary.exerciseNames.isEmpty {
                        GymSectionLabel(title: "Exercises")
                        GymCard(padding: 0) {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(summary.exerciseNames.enumerated()), id: \.offset) { index, name in
                                    if index > 0 { GymTheme.hairline.frame(height: 0.5) }
                                    Text(name)
                                        .font(.system(size: GymTheme.pt(15), weight: .medium))
                                        .padding(.horizontal, GymTheme.rowPadX)
                                        .padding(.vertical, GymTheme.rowPadY)
                                }
                            }
                        }
                    }

                    if summary.canStart {
                        Button("Start Workout", action: onStart)
                            .gymPrimaryButton()
                            .accessibilityIdentifier("startPlanFromPreview")
                    } else {
                        Button("Edit Plan", action: onEdit)
                            .gymGhostButton()
                            .accessibilityIdentifier("editBrokenPlan")
                    }
                }
                .padding(.horizontal, GymTheme.pageGutter)
                .padding(.top, GymTheme.pt(8))
                .padding(.bottom, GymTheme.pt(12))
            }
            .background(GymTheme.pageFill)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .font(GymTheme.navAction)
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cancelPlanPreview")
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
