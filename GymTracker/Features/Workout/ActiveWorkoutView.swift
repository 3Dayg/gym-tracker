import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession
    let sessionTimer: SessionTimer

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKeys.unitSystem)
    private var unitSystem: UnitSystem = .metric
    @AppStorage(SettingsKeys.restDurationSeconds)
    private var restDuration: Int = SettingsDefaults.restDurationSeconds

    @State private var isPickingExercise = false
    @State private var isConfirmingCancel = false

    private var effectiveRestSeconds: Int {
        session.restSeconds ?? restDuration
    }

    private var hasTimedExercise: Bool {
        session.exercises.contains { $0.kind == .timed }
    }

    var body: some View {
        List {
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
                    onSetCompleted: {
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
            }
        }
        .navigationTitle(session.planName ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel", role: .destructive) {
                    isConfirmingCancel = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Finish") { finishWorkout() }
                    .fontWeight(.semibold)
                    .disabled(session.completedSetCount == 0)
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
        .confirmationDialog(
            "Discard this workout?",
            isPresented: $isConfirmingCancel,
            titleVisibility: .visible
        ) {
            Button("Discard Workout", role: .destructive) { cancelWorkout() }
            Button("Keep Going", role: .cancel) {}
        }
        .onAppear {
            sessionTimer.onWorkFinished = { [weak sessionTimer] set in
                guard let sessionTimer, !set.isCompleted else { return }
                set.isCompleted = true
                sessionTimer.startRest(seconds: effectiveRestSeconds)
            }
            sessionTimer.refresh()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                sessionTimer.refresh()
            }
        }
    }

    private func finishWorkout() {
        sessionTimer.stop()
        WorkoutSessionService.finish(session, in: modelContext)
    }

    private func cancelWorkout() {
        sessionTimer.stop()
        WorkoutSessionService.cancel(session, in: modelContext)
    }
}

/// One exercise in the running workout: its sets plus an add-set button.
private struct SessionExerciseSection: View {
    let sessionExercise: SessionExercise
    let unitSystem: UnitSystem
    let sessionTimer: SessionTimer
    let onSetCompleted: () -> Void

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
                    onCompleted: onSetCompleted
                )
            }
            .onDelete(perform: deleteSets)

            Button {
                WorkoutSessionService.addSet(to: sessionExercise)
            } label: {
                Label("Add \(sessionExercise.kind.setLabel)", systemImage: "plus")
                    .font(.subheadline)
            }
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

/// Editable metrics with a completion checkmark. Timed rows also get a
/// Start/Pause work countdown.
private struct SetRow: View {
    @Bindable var set: SetEntry
    let setNumber: Int
    let kind: ExerciseKind
    let unitSystem: UnitSystem
    let sessionTimer: SessionTimer
    let onCompleted: () -> Void

    @State private var activeMetric: SetMetric?

    private var isTimingThisSet: Bool { sessionTimer.isTiming(set) }

    var body: some View {
        Group {
            if kind == .timed {
                timedLayout
            } else {
                standardLayout
            }
        }
        .listRowBackground(set.isCompleted ? Color.accentColor.opacity(0.08) : nil)
        .sheet(item: $activeMetric) { metric in
            pickerSheet(for: metric)
        }
    }

    private var standardLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            setIndexLabel
            if kind.metrics.count <= 2 {
                compactFields
            } else {
                labeledFields
            }
            completeButton
        }
    }

    private var timedLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                setIndexLabel
                if isTimingThisSet {
                    Text(Formatters.countdown(sessionTimer.remainingSeconds))
                        .font(.title.monospacedDigit())
                        .accessibilityIdentifier("workCountdown")
                    Text(sessionTimer.isPaused ? "Paused" : "Work")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    chip(for: .duration)
                        .disabled(set.isCompleted)
                }
                Spacer()
                completeButton
            }

            if !set.isCompleted {
                workControls
            }
        }
        .padding(.vertical, 4)
    }

    private var workControls: some View {
        HStack {
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
                    sessionTimer.startWork(seconds: set.durationSeconds, set: set)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(set.durationSeconds <= 0)
                .accessibilityIdentifier("startWork")
            }
            Spacer()
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
        .accessibilityIdentifier("completeSet")
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

    private func toggleCompleted() {
        if sessionTimer.isTiming(set) {
            sessionTimer.stop()
        }
        set.isCompleted.toggle()
        if set.isCompleted {
            fillDerivedDistanceIfNeeded()
            onCompleted()
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
