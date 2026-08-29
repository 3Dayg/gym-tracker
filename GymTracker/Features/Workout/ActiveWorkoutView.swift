import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession
    let sessionTimer: SessionTimer
    var onWorkoutSaved: (SavedWorkoutNotice) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.unitSystem)
    private var unitSystem: UnitSystem = .metric
    @AppStorage(SettingsKeys.restDurationSeconds)
    private var restDuration: Int = SettingsDefaults.restDurationSeconds

    @State private var isPickingExercise = false
    @State private var isConfirmingDiscard = false
    @State private var isConfirmingFinish = false
    @State private var nothingToSaveAlert = false
    @State private var saveErrorMessage: String?
    @State private var isStalePrompt = false
    @State private var expiredRoundNotice = false

    private var effectiveRestSeconds: Int {
        session.restSeconds ?? restDuration
    }

    private var hasTimedExercise: Bool {
        session.exercises.contains { $0.kind == .timed }
    }

    private var finishPreview: WorkoutFinishPreview {
        WorkoutSessionService.finishPreview(for: session)
    }

    private var liveProgress: LiveWorkoutProgress {
        LiveWorkoutProgress.from(session)
    }

    private var nextPendingSet: SetEntry? {
        LiveWorkoutProgress.nextPendingSet(in: session)
    }

    var body: some View {
        Group {
            if session.isFollowAlong {
                FollowAlongView(
                    session: session,
                    sessionTimer: sessionTimer,
                    unitSystem: unitSystem,
                    restSeconds: effectiveRestSeconds,
                    onAddExercise: { isPickingExercise = true }
                )
            } else if sessionTimer.phase == .rest {
                restTakeover
            } else {
                workoutList
            }
        }
        .id(session.isFollowAlong)
        .navigationTitle(session.planName ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Discard", role: .destructive) {
                    isConfirmingDiscard = true
                }
                .accessibilityIdentifier("discardWorkout")
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    WorkoutSettingsPickers()
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
                Button {
                    isPickingExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
                .accessibilityIdentifier("addExerciseToolbar")
                Button("Finish") { attemptFinish() }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("finishWorkout")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !session.isFollowAlong, sessionTimer.phase == .rest {
                RestAdjustControls(sessionTimer: sessionTimer)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.bar)
            }
        }
        .sheet(isPresented: $isPickingExercise) {
            NavigationStack {
                ExercisePickerView { exercise in
                    WorkoutSessionService.addExercise(exercise, to: session, in: modelContext)
                }
            }
        }
        .sheet(isPresented: $isConfirmingFinish) {
            FinishWorkoutSheet(
                preview: finishPreview,
                planName: session.planName,
                onConfirm: confirmFinish,
                onCancel: { isConfirmingFinish = false }
            )
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $isConfirmingDiscard,
            titleVisibility: .visible
        ) {
            Button("Discard Workout", role: .destructive) { discardWorkout() }
                .accessibilityIdentifier("confirmDiscard")
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("Nothing will be saved.")
        }
        .alert("Nothing to save", isPresented: $nothingToSaveAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Complete at least one set to save. Skip only marks a set you passed on — it is not enough to finish. Discard throws this workout away.")
        }
        .alert("Round finished", isPresented: $expiredRoundNotice) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("That timed round ended while the app was closed. It’s marked complete.")
        }
        .sheet(isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            SaveFailedSheet(
                message: saveErrorMessage ?? "Try Finish again. Your sets are still here.",
                onRetry: confirmFinish,
                onKeepGoing: { saveErrorMessage = nil }
            )
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .sheet(isPresented: $isStalePrompt) {
            StaleWorkoutSheet(
                startedAt: session.startedAt,
                onResume: {
                    session.stalePromptAcknowledged = true
                    isStalePrompt = false
                    try? modelContext.save()
                },
                onDiscard: {
                    isStalePrompt = false
                    discardWorkout()
                }
            )
            .presentationDetents([.medium])
            .interactiveDismissDisabled()
        }
        .onAppear {
            sessionTimer.onWorkFinished = { [weak sessionTimer] set in
                guard let sessionTimer, set.isPending else { return }
                let kind = set.sessionExercise?.kind ?? .timed
                SetLogging.fillDerivedDistanceIfNeeded(set, kind: kind)
                set.markCompleted()
                LiveWorkoutProgress.clearExpiredFocus(in: set.sessionExercise?.session)
                if kind.startsRestTimer {
                    sessionTimer.startRest(seconds: effectiveRestSeconds)
                }
            }
            sessionTimer.onPersist = { [weak sessionTimer] in
                guard let sessionTimer else { return }
                session.liveTimer = sessionTimer.makeSnapshot()
                try? modelContext.save()
            }
            restoreTimerIfNeeded()
            sessionTimer.refresh()
            if !session.stalePromptAcknowledged,
               StaleWorkoutPolicy.isStale(session.startedAt)
            {
                isStalePrompt = true
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                sessionTimer.refresh()
            } else if newPhase == .background {
                persistTimer()
            }
        }
    }

    private func persistTimer() {
        session.liveTimer = sessionTimer.makeSnapshot()
        try? modelContext.save()
    }

    private func restoreTimerIfNeeded() {
        guard sessionTimer.phase == .idle, let state = session.liveTimer else { return }
        let action = LiveTimerRestorer.action(from: state)
        if case .completeSetAndIdle = action {
            expiredRoundNotice = true
        }
        sessionTimer.apply(action) { exercise, set in
            session.setEntry(exerciseOrder: exercise, setOrder: set)
        }
    }

    private func attemptFinish() {
        sessionTimer.refresh()
        if finishPreview.canSave {
            isConfirmingFinish = true
        } else {
            nothingToSaveAlert = true
        }
    }

    private func confirmFinish() {
        sessionTimer.stop()
        let preview = finishPreview
        do {
            try WorkoutSessionService.finish(session, in: modelContext)
            saveErrorMessage = nil
            isConfirmingFinish = false
            onWorkoutSaved(
                SavedWorkoutNotice(
                    session: session,
                    preview: preview,
                    planName: session.planName,
                    duration: session.duration
                )
            )
        } catch {
            isConfirmingFinish = false
            saveErrorMessage = error.localizedDescription
        }
    }

    private func discardWorkout() {
        sessionTimer.stop()
        WorkoutSessionService.cancel(session, in: modelContext)
    }

    private var restTakeover: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                progressHeader
                RestTakeoverCard(
                    remainingSeconds: sessionTimer.remainingSeconds,
                    nextLine: liveProgress.nextLine
                )
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var progressHeader: some View {
        WorkoutProgressHeader(
            startedAt: session.startedAt,
            progress: liveProgress,
            addSetTitle: nextPendingSet.flatMap { set in
                set.sessionExercise.map { "Add \($0.kind.setLabel)" }
            },
            onAddSet: {
                if let exercise = nextPendingSet?.sessionExercise {
                    WorkoutSessionService.addSet(to: exercise)
                }
            },
            onShowExercises: session.exercises.isEmpty ? nil : { session.isFollowAlong = true }
        )
    }

    private var workoutList: some View {
        List {
            Section {
                progressHeader
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            if session.exercises.isEmpty {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quick Start is empty")
                            .font(.headline)
                        Text("Add an exercise to log a set. Tick what you did, Skip what you pass on, or Discard to throw this workout away.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("emptyWorkoutHint")
                    }
                    .accessibilityElement(children: .contain)
                }
            }

            if hasTimedExercise {
                Section {
                    LabeledContent("Rest after a round", value: Formatters.countdown(effectiveRestSeconds))
                        .accessibilityIdentifier("timedRestHint")
                }
            }

            ForEach(session.orderedExercises) { sessionExercise in
                SessionExerciseSection(
                    sessionExercise: sessionExercise,
                    unitSystem: unitSystem,
                    sessionTimer: sessionTimer,
                    followOnRestSeconds: sessionExercise.kind.startsRestTimer ? effectiveRestSeconds : 0,
                    nextPendingSet: nextPendingSet,
                    onDidWork: {
                        if sessionExercise.kind.startsRestTimer, sessionTimer.phase != .work {
                            sessionTimer.startRest(seconds: effectiveRestSeconds)
                        }
                    }
                )
            }

            Section {
                Button {
                    isPickingExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
                .accessibilityIdentifier("addExercise")
            }
        }
    }
}

private struct StaleWorkoutSheet: View {
    let startedAt: Date
    let onResume: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Started \(startedAt.formatted(date: .abbreviated, time: .shortened)). Resume where you left off, or discard it.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("This workout has been open a long time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard Workout", role: .destructive, action: onDiscard)
                        .accessibilityIdentifier("discardStaleWorkout")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Resume", action: onResume)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("resumeStaleWorkout")
                }
            }
        }
    }
}

private struct SaveFailedSheet: View {
    let message: String
    let onRetry: () -> Void
    let onKeepGoing: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(message)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Couldn’t save workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep Going", action: onKeepGoing)
                        .accessibilityIdentifier("keepGoingAfterSaveError")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Retry", action: onRetry)
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("retrySaveWorkout")
                }
            }
        }
    }
}

private struct FinishWorkoutSheet: View {
    let preview: WorkoutFinishPreview
    let planName: String?
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Save this workout?")
                        .font(.title2.weight(.semibold))
                        .accessibilityIdentifier("finishWorkoutTitle")
                    LabeledContent("Completed", value: "\(preview.completedCount)")
                    if preview.failedCount > 0 {
                        LabeledContent("Failed (kept, not in PRs)", value: "\(preview.failedCount)")
                    }
                    LabeledContent("Skipped", value: "\(preview.skippedCount)")
                    LabeledContent("Incomplete", value: "\(preview.incompleteCount)")
                } header: {
                    Text(planName ?? "Workout")
                } footer: {
                    Text(footerCopy)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Keep Going", action: onCancel)
                        .accessibilityIdentifier("keepGoing")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onConfirm() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("confirmFinish")
                }
            }
        }
    }

    private var footerCopy: String {
        var parts: [String] = []
        if preview.incompleteCount > 0 {
            parts.append("Incomplete rows will not be saved.")
        }
        parts.append("Missed a target? Lower the reps or time, then tap Fail — it logs the set and keeps it out of PRs.")
        return parts.joined(separator: " ")
    }
}

struct WorkoutSavedSheet: View {
    let notice: SavedWorkoutNotice
    let onViewHistory: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Completed", value: "\(notice.preview.completedCount)")
                    if notice.preview.failedCount > 0 {
                        LabeledContent("Failed", value: "\(notice.preview.failedCount)")
                    }
                    if notice.preview.skippedCount > 0 {
                        LabeledContent("Skipped", value: "\(notice.preview.skippedCount)")
                    }
                    LabeledContent("Duration", value: Formatters.duration(notice.duration))
                } footer: {
                    Text("Open History to review the breakdown.")
                }
            }
            .navigationTitle("Workout saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("savedDone")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("View in History", action: onViewHistory)
                        .accessibilityIdentifier("viewInHistory")
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// One exercise in the running workout: its sets plus an add-set button.
struct SessionExerciseSection: View {
    let sessionExercise: SessionExercise
    let unitSystem: UnitSystem
    let sessionTimer: SessionTimer
    let followOnRestSeconds: Int
    let nextPendingSet: SetEntry?
    let onDidWork: () -> Void

    @Environment(\.modelContext) private var modelContext

    private var formNotes: String {
        if !sessionExercise.exerciseNotes.isEmpty {
            return sessionExercise.exerciseNotes
        }
        return sessionExercise.exercise?.notes ?? ""
    }

    var body: some View {
        Section {
            ForEach(sessionExercise.orderedSets) { set in
                SetRow(
                    set: set,
                    setNumber: (sessionExercise.orderedSets.firstIndex(where: { $0 === set }) ?? 0) + 1,
                    kind: sessionExercise.kind,
                    unitSystem: unitSystem,
                    sessionTimer: sessionTimer,
                    followOnRestSeconds: followOnRestSeconds,
                    isNext: set === nextPendingSet,
                    onDidWork: onDidWork
                )
            }
            .onDelete(perform: deleteSets)

            Button {
                WorkoutSessionService.addSet(to: sessionExercise)
            } label: {
                Label("Add \(sessionExercise.kind.setLabel)", systemImage: "plus")
                    .font(.subheadline)
            }
            .accessibilityIdentifier("addSet")
        } header: {
            VStack(alignment: .leading, spacing: 4) {
                Text(sessionExercise.exerciseName)
                if !formNotes.isEmpty {
                    Text(formNotes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.none)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("exerciseNotes")
                }
            }
        }
    }

    private func deleteSets(at offsets: IndexSet) {
        let ordered = sessionExercise.orderedSets
        for index in offsets {
            if sessionTimer.isTiming(ordered[index]) {
                sessionTimer.stop()
            }
            modelContext.delete(ordered[index])
        }
        if sessionExercise.sets.count == offsets.count {
            modelContext.delete(sessionExercise)
        }
    }
}

/// Editable metrics with complete / skip / fail, plus a work countdown
/// on timed rows.
private struct SetRow: View {
    @Bindable var set: SetEntry
    let setNumber: Int
    let kind: ExerciseKind
    let unitSystem: UnitSystem
    let sessionTimer: SessionTimer
    let followOnRestSeconds: Int
    let isNext: Bool
    let onDidWork: () -> Void

    @State private var activeMetric: SetMetric?
    @State private var workPrep = WorkPrepCountdown()

    private var isTimingThisSet: Bool { sessionTimer.isTiming(set) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if kind == .timed {
                timedMetrics
            } else {
                standardMetrics
            }

            if set.isPending {
                pendingControls
            } else if set.isSkipped {
                Button("Undo skip") { set.clearOutcome() }
                    .font(.subheadline)
                    .accessibilityIdentifier("undoSkip")
            } else {
                Button(set.isFailed ? "Failed — tap to undo" : "Mark failed") {
                    set.isFailed.toggle()
                }
                .font(.subheadline)
                .foregroundStyle(set.isFailed ? GymTheme.failed : .secondary)
                .accessibilityIdentifier("markFailed")
            }
        }
        .padding(.vertical, 4)
        .opacity(rowOpacity)
        .listRowBackground(rowBackground)
        .sheet(item: $activeMetric) { metric in
            pickerSheet(for: metric)
        }
        .onDisappear { workPrep.cancel() }
    }

    private var rowOpacity: Double {
        if isTimingThisSet || set.isPending { return 1 }
        if set.isFailed { return 0.85 }
        return GymTheme.skippedOpacity + 0.05
    }

    private var rowBackground: Color? {
        if isNext { return GymTheme.red.opacity(GymTheme.nextFillOpacity) }
        if set.isSkipped { return Color.primary.opacity(GymTheme.completeFillOpacity) }
        if set.isFailed { return GymTheme.red.opacity(GymTheme.failedFillOpacity) }
        if set.isCompleted { return Color.primary.opacity(GymTheme.completeFillOpacity) }
        return nil
    }

    private var standardMetrics: some View {
        HStack(alignment: .top, spacing: 12) {
            setIndexLabel
            if kind.metrics.count <= 2 {
                compactFields
            } else {
                labeledFields
            }
            completeButton
        }
        .disabled(set.isSkipped)
    }

    private var timedMetrics: some View {
        HStack(alignment: .center, spacing: 12) {
            setIndexLabel
            if isTimingThisSet {
                Text(Formatters.countdown(sessionTimer.remainingSeconds))
                    .font(.title.monospacedDigit())
                    .foregroundStyle(GymTheme.work)
                    .accessibilityIdentifier("workCountdown")
                Text(sessionTimer.isPaused ? "Paused" : "Work")
                    .font(.subheadline)
                    .foregroundStyle(GymTheme.work)
            } else if let remaining = workPrep.remaining {
                WorkPrepCountdownLabel(remaining: remaining, font: .title.monospacedDigit())
            } else if set.isSkipped {
                Text("Skipped")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("skippedLabel")
            } else {
                chip(for: .duration)
                    .disabled(set.isCompleted)
            }
            Spacer()
            completeButton
        }
    }

    private var pendingControls: some View {
        HStack(spacing: 12) {
            if kind.hasWorkTimer {
                workControls
            }
            Button("Skip") { skip() }
                .gymSecondaryButton()
                .controlSize(.large)
                .accessibilityIdentifier("skipSet")
            Button("Fail") { fail() }
                .gymFailButton()
                .controlSize(.large)
                .accessibilityIdentifier("failSet")
            Spacer()
        }
    }

    private var workControls: some View {
        Group {
            if workPrep.isActive {
                Button("Cancel") { workPrep.cancel() }
                    .gymSecondaryButton()
                    .controlSize(.large)
                    .accessibilityIdentifier("cancelWorkPrep")
            } else if isTimingThisSet && sessionTimer.isPaused {
                Button("Resume") { sessionTimer.resume() }
                    .gymPrimaryButton()
                    .controlSize(.large)
                    .accessibilityIdentifier("resumeWork")
            } else if isTimingThisSet {
                Button("Pause") { sessionTimer.pause() }
                    .gymSecondaryButton()
                    .controlSize(.large)
                    .accessibilityIdentifier("pauseWork")
            } else if kind == .timed {
                Button("Start") {
                    workPrep.start {
                        sessionTimer.startWork(
                            seconds: set.durationSeconds,
                            set: set,
                            followOnRestSeconds: followOnRestSeconds
                        )
                    }
                }
                .gymPrimaryButton()
                .controlSize(.large)
                .disabled(set.durationSeconds <= 0)
                .accessibilityIdentifier("startWork")
            } else {
                Button("Start") {
                    sessionTimer.startWork(
                        seconds: set.durationSeconds,
                        set: set,
                        followOnRestSeconds: followOnRestSeconds
                    )
                }
                .gymPrimaryButton()
                .controlSize(.large)
                .disabled(set.durationSeconds <= 0)
                .accessibilityIdentifier("startWork")
            }
        }
    }

    private var setIndexLabel: some View {
        Text("\(setNumber)")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 24)
            .frame(minHeight: 44)
            .accessibilityLabel("\(kind.setLabel) \(setNumber)")
    }

    private var completeButton: some View {
        Button {
            toggleCompleted()
        } label: {
            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(set.isPending ? .title : .title2)
                .frame(minWidth: set.isPending ? 52 : 44, minHeight: set.isPending ? 52 : 44)
                .contentShape(Rectangle())
                .foregroundStyle(set.isCompleted ? Color.primary : (isNext ? GymTheme.red : .secondary))
        }
        .buttonStyle(.plain)
        .disabled(set.isSkipped)
        .accessibilityIdentifier("completeSet")
        .accessibilityLabel(set.isCompleted ? "Completed" : (isNext ? "Mark complete, up next" : "Mark complete"))
        .accessibilityHint(set.isCompleted ? "Clears the check. Failed sets stay out of personal records." : "Check this row. Skip and Fail are separate.")
        .accessibilityAddTraits(set.isCompleted ? [.isButton, .isSelected] : .isButton)
    }

    private var compactFields: some View {
        HStack(spacing: 12) {
            ForEach(kind.metrics) { metric in
                if metric != kind.metrics.first {
                    Spacer()
                }
                chip(for: metric)
            }
        }
    }

    private var labeledFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(kind.metrics) { metric in
                HStack {
                    Text(metric.fieldTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    chip(for: metric)
                }
            }
        }
    }

    @ViewBuilder
    private func chip(for metric: SetMetric) -> some View {
        switch metric {
        case .speed:
            numericField(
                value: unitSystem.speedBinding($set.speed),
                placeholder: "Speed",
                unit: unitSystem.speedLabel
            )
        case .incline:
            numericField(
                value: Binding(get: { set.incline }, set: { set.incline = $0 ?? 0 }),
                placeholder: "Incline",
                unit: "%"
            )
        case .distance:
            numericField(
                value: unitSystem.distanceBinding($set.distance),
                placeholder: "Auto",
                unit: unitSystem.distanceLabel
            )
        case .weight:
            if set.isPending && isNext {
                HStack(spacing: 4) {
                    Button {
                        set.weight = unitSystem.bumpKilograms(set.weight, byDisplaySteps: -1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .gymSecondaryButton()
                    .accessibilityIdentifier("decrementWeight")
                    .accessibilityLabel("Decrease weight")

                    metricChip(for: .weight)

                    Button {
                        set.weight = unitSystem.bumpKilograms(set.weight, byDisplaySteps: 1)
                    } label: {
                        Image(systemName: "plus")
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .gymSecondaryButton()
                    .accessibilityIdentifier("incrementWeight")
                    .accessibilityLabel("Increase weight")
                }
            } else {
                metricChip(for: .weight)
            }
        case .reps, .duration:
            metricChip(for: metric)
        }
    }

    private func metricChip(for metric: SetMetric) -> some View {
        MetricChip(text: chipText(for: metric)) {
            activeMetric = metric
        }
        .accessibilityIdentifier(metric == .weight ? "weightValue" : "metricChip-\(metric.rawValue)")
        .accessibilityValue(chipText(for: metric))
    }

    private func numericField(value: Binding<Double?>, placeholder: String, unit: String) -> some View {
        HStack(spacing: 6) {
            TextField(placeholder, value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .font(.subheadline.monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chipText(for metric: SetMetric) -> String {
        switch metric {
        case .weight: Formatters.weight(set.weight, unit: unitSystem)
        case .reps: "\(set.reps) reps"
        case .duration: Formatters.durationSeconds(set.durationSeconds)
        case .speed: Formatters.speed(set.speed, unit: unitSystem)
        case .incline: Formatters.incline(set.incline)
        case .distance: set.distance.map { Formatters.distance($0, unit: unitSystem) } ?? "Auto"
        }
    }

    @ViewBuilder
    private func pickerSheet(for metric: SetMetric) -> some View {
        switch metric {
        case .duration:
            DurationPickerSheet(seconds: $set.durationSeconds)
        case .weight:
            NumberPickerSheet(
                title: "Weight",
                unit: unitSystem.weightLabel,
                values: metric.wheelValues,
                value: unitSystem.weightBinding($set.weight)
            )
        case .reps:
            NumberPickerSheet(
                title: "Reps",
                unit: "reps",
                values: metric.wheelValues,
                value: Binding(get: { Double(set.reps) }, set: { set.reps = Int($0 ?? 0) })
            )
        case .speed, .incline, .distance:
            EmptyView()
        }
    }

    private func stopTimingIfNeeded() {
        if sessionTimer.isTiming(set) {
            sessionTimer.stop()
        }
    }

    private func skip() {
        workPrep.cancel()
        stopTimingIfNeeded()
        set.markSkipped()
    }

    private func fail() {
        workPrep.cancel()
        stopTimingIfNeeded()
        fillDerivedDistanceIfNeeded()
        set.markCompleted(failed: true)
        onDidWork()
    }

    private func toggleCompleted() {
        workPrep.cancel()
        stopTimingIfNeeded()
        if set.isCompleted {
            set.clearOutcome()
        } else {
            fillDerivedDistanceIfNeeded()
            set.markCompleted()
            onDidWork()
        }
    }

    private func fillDerivedDistanceIfNeeded() {
        guard
            kind.metrics.contains(.distance),
            set.distance == nil,
            set.speed > 0, set.durationSeconds > 0
        else { return }
        let raw = set.speed * Double(set.durationSeconds) / 3600
        set.distance = (raw * 100).rounded() / 100
    }
}

