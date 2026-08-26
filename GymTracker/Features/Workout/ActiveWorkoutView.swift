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

    private var effectiveRestSeconds: Int {
        session.restSeconds ?? restDuration
    }

    private var hasTimedExercise: Bool {
        session.exercises.contains { $0.kind == .timed }
    }

    private var finishPreview: WorkoutFinishPreview {
        WorkoutSessionService.finishPreview(for: session)
    }

    var body: some View {
        List {
            Section {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    LabeledContent(
                        "Elapsed",
                        value: Formatters.elapsed(context.date.timeIntervalSince(session.startedAt))
                    )
                    .accessibilityIdentifier("elapsedWorkoutTime")
                }
            }

            if session.exercises.isEmpty {
                Section {
                    Text("Quick Start is empty. Add an exercise to log a set. Tick what you did, Skip what you pass on, or Discard to throw this workout away.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("emptyWorkoutHint")
                }
            } else if finishPreview.completedCount == 0 {
                Section {
                    Text("Tick a set you did to save. Skip leaves a marker in History. Incomplete rows are dropped when you finish.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("finishHint")
                }
            }

            if hasTimedExercise {
                Section {
                    LabeledContent("Rest after a round", value: Formatters.countdown(effectiveRestSeconds))
                        .accessibilityIdentifier("timedRestHint")
                    Text("Tap Start on a timed round. When the countdown hits zero, rest begins. You can still tick a round by hand.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(session.orderedExercises) { sessionExercise in
                SessionExerciseSection(
                    sessionExercise: sessionExercise,
                    unitSystem: unitSystem,
                    sessionTimer: sessionTimer,
                    followOnRestSeconds: sessionExercise.kind.startsRestTimer ? effectiveRestSeconds : 0,
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
        .navigationTitle(session.planName ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Discard", role: .destructive) {
                    isConfirmingDiscard = true
                }
                .accessibilityIdentifier("discardWorkout")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { attemptFinish() }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("finishWorkout")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if sessionTimer.phase == .work {
                WorkTimerBar(sessionTimer: sessionTimer)
            } else if sessionTimer.phase == .rest {
                RestTimerBar(sessionTimer: sessionTimer)
            }
        }
        .sheet(isPresented: $isPickingExercise) {
            ExercisePickerView { exercise in
                WorkoutSessionService.addExercise(exercise, to: session, in: modelContext)
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
            Text("Tick a set you did, or Discard this workout. Skip marks a set you passed on; incomplete rows are dropped.")
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
                set.markCompleted()
                sessionTimer.startRest(seconds: effectiveRestSeconds)
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
            .navigationTitle("Save workout?")
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
        parts.append("Missed a target? Lower the reps (or time), tick the set, then mark Failed so it stays out of PRs.")
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
private struct SessionExerciseSection: View {
    let sessionExercise: SessionExercise
    let unitSystem: UnitSystem
    let sessionTimer: SessionTimer
    let followOnRestSeconds: Int
    let onDidWork: () -> Void

    @Environment(\.modelContext) private var modelContext

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
            Text(sessionExercise.exerciseName)
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
    let onDidWork: () -> Void

    @State private var activeMetric: SetMetric?

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
                .foregroundStyle(set.isFailed ? .orange : .secondary)
                .accessibilityIdentifier("markFailed")
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(rowBackground)
        .sheet(item: $activeMetric) { metric in
            pickerSheet(for: metric)
        }
    }

    private var rowBackground: Color? {
        if set.isSkipped { return Color.secondary.opacity(0.08) }
        if set.isFailed { return Color.orange.opacity(0.10) }
        if set.isCompleted { return Color.accentColor.opacity(0.08) }
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
                    .accessibilityIdentifier("workCountdown")
                Text(sessionTimer.isPaused ? "Paused" : "Work")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
            if kind == .timed {
                workControls
            }
            Button("Skip") { skip() }
                .buttonStyle(.bordered)
                .controlSize(kind == .timed ? .large : .regular)
                .accessibilityIdentifier("skipSet")
            Button("Fail") { fail() }
                .buttonStyle(.bordered)
                .controlSize(kind == .timed ? .large : .regular)
                .accessibilityIdentifier("failSet")
            Spacer()
        }
    }

    private var workControls: some View {
        Group {
            if isTimingThisSet && sessionTimer.isPaused {
                Button("Resume") { sessionTimer.resume() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityIdentifier("resumeWork")
            } else if isTimingThisSet {
                Button("Pause") { sessionTimer.pause() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("pauseWork")
            } else {
                Button("Start") {
                    sessionTimer.startWork(
                        seconds: set.durationSeconds,
                        set: set,
                        followOnRestSeconds: followOnRestSeconds
                    )
                }
                .buttonStyle(.borderedProminent)
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
    }

    private var completeButton: some View {
        Button {
            toggleCompleted()
        } label: {
            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(set.isCompleted ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(set.isSkipped)
        .accessibilityIdentifier("completeSet")
        .accessibilityLabel(set.isCompleted ? "Completed" : "Mark complete")
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
        default:
            Button {
                activeMetric = metric
            } label: {
                Text(chipText(for: metric))
                    .font(.subheadline.monospacedDigit())
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
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
        stopTimingIfNeeded()
        set.markSkipped()
    }

    private func fail() {
        stopTimingIfNeeded()
        fillDerivedDistanceIfNeeded()
        set.markCompleted(failed: true)
        onDidWork()
    }

    private func toggleCompleted() {
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

private struct WorkTimerBar: View {
    let sessionTimer: SessionTimer

    var body: some View {
        HStack {
            Image(systemName: "figure.boxing")
            Text(sessionTimer.isPaused ? "Paused" : "Work")
            Text(Formatters.countdown(sessionTimer.remainingSeconds))
                .font(.headline.monospacedDigit())
                .accessibilityIdentifier("workBarCountdown")

            Spacer()

            if sessionTimer.isPaused {
                Button("Resume") { sessionTimer.resume() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Button("Pause") { sessionTimer.pause() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding()
        .background(.bar)
    }
}

private struct RestTimerBar: View {
    let sessionTimer: SessionTimer

    var body: some View {
        HStack {
            Image(systemName: "timer")
            Text("Rest: \(Formatters.countdown(sessionTimer.remainingSeconds))")
                .font(.headline.monospacedDigit())
                .accessibilityIdentifier("restBarCountdown")

            Spacer()

            Button("Skip rest") { sessionTimer.stop() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("skipRest")
        }
        .padding()
        .background(.bar)
    }
}
