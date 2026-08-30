import SwiftData
import SwiftUI

/// One-card presentation of the live session. `SetEntry` and `SessionTimer`
/// stay authoritative; this view never auto-completes a strength set.
struct FollowAlongView: View {
    @Bindable var session: WorkoutSession
    let sessionTimer: SessionTimer
    let unitSystem: UnitSystem
    let restSeconds: Int
    let onAddExercise: () -> Void

    @State private var restEndedTick = 0
    @State private var isShowingExerciseMap = false
    @State private var editingExerciseSortOrder: Int?
    @State private var workPrep = WorkPrepCountdown()

    private var progress: LiveWorkoutProgress { LiveWorkoutProgress.from(session) }

    private var focus: FollowAlongFocus {
        FollowAlongFocus.current(session: session, timerPhase: sessionTimer.phase)
    }

    private var currentSet: SetEntry? {
        if sessionTimer.phase == .rest { return nil }
        return LiveWorkoutProgress.nextPendingSet(in: session)
    }

    private var focusedSetKey: String {
        guard let set = currentSet, let exercise = set.sessionExercise else { return "" }
        return "\(exercise.sortOrder)-\(set.sortOrder)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: GymTheme.cardGap) {
                if focus != .rest {
                    WorkoutProgressHeader(
                        progress: progress,
                        onShowExercises: session.exercises.isEmpty ? nil : { isShowingExerciseMap = true },
                        cardFill: GymTheme.cardFill
                    )
                }

                switch focus {
                case .rest:
                    RestTakeoverCard(
                        remainingSeconds: sessionTimer.remainingSeconds,
                        nextLine: progress.restNextLine,
                        combinedIdentifier: "followAlongRest"
                    )
                    if !session.exercises.isEmpty {
                        Button {
                            isShowingExerciseMap = true
                        } label: {
                            Label("Exercises", systemImage: "dumbbell")
                        }
                        .gymExercisesButton()
                        .padding(.horizontal, GymTheme.pageGutter)
                        .accessibilityIdentifier("showExerciseMap")
                        .accessibilityHint("Shows every exercise so you can jump or come back later")
                    }
                case .empty:
                    emptyCard
                case .finished:
                    finishedCard
                case .currentSet(let name, let number, let count, _):
                    if let set = currentSet, let exercise = set.sessionExercise {
                        FollowAlongSetCard(
                            set: set,
                            exercise: exercise,
                            setNumber: number,
                            setCount: count,
                            unitSystem: unitSystem,
                            sessionTimer: sessionTimer,
                            restSeconds: restSeconds,
                            prepRemaining: workPrep.remaining
                        )
                    } else {
                        Text(name)
                    }
                }
            }
            .padding(.horizontal, GymTheme.pageGutter)
            .padding(.top, GymTheme.pt(4))
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(GymTheme.pageFill)
        .accessibilityIdentifier("followAlongRoot")
        .sensoryFeedback(.impact(weight: .medium), trigger: restEndedTick)
        .onChange(of: sessionTimer.phase) { oldPhase, newPhase in
            if oldPhase == .rest, newPhase == .idle {
                restEndedTick += 1
            }
        }
        .onChange(of: focusedSetKey) { _, _ in
            workPrep.cancel()
        }
        .onChange(of: isShowingExerciseMap) { _, showing in
            if showing { workPrep.cancel() }
        }
        .onChange(of: editingExerciseSortOrder) { _, order in
            if order != nil { workPrep.cancel() }
        }
        .safeAreaInset(edge: .bottom) {
            bottomBar
        }
        .sheet(isPresented: $isShowingExerciseMap) {
            FollowAlongExerciseMap(
                session: session,
                onJump: { exercise in
                    LiveWorkoutProgress.jump(to: exercise, in: session)
                    isShowingExerciseMap = false
                },
                onEdit: { exercise in
                    isShowingExerciseMap = false
                    editingExerciseSortOrder = exercise.sortOrder
                }
            )
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: Binding(
            get: { editingExerciseSortOrder != nil },
            set: { if !$0 { editingExerciseSortOrder = nil } }
        )) {
            if let order = editingExerciseSortOrder,
               let exercise = session.orderedExercises.first(where: { $0.sortOrder == order }) {
                FollowAlongEditSheet(
                    sessionExercise: exercise,
                    unitSystem: unitSystem,
                    sessionTimer: sessionTimer,
                    restSeconds: restSeconds,
                    nextPendingSet: currentSet,
                    onClose: { editingExerciseSortOrder = nil }
                )
            }
        }
    }

    private var emptyCard: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Start is empty")
                    .font(GymTheme.rowName)
                Text("Add an exercise to log a set. Tick what you did, Skip what you pass on, or Discard to throw this workout away.")
                    .font(GymTheme.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("emptyWorkoutHint")
            }
        }
    }

    private var finishedCard: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("All rows logged")
                    .font(GymTheme.exerciseName)
                Text("Finish from the top-right to save, or open Exercises to change a row.")
                    .font(GymTheme.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityIdentifier("followAlongFinished")
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 12) {
            if sessionTimer.phase == .rest {
                RestAdjustControls(sessionTimer: sessionTimer)
            } else if let set = currentSet, let kind = set.sessionExercise?.kind {
                FollowAlongActions(
                    set: set,
                    kind: kind,
                    sessionTimer: sessionTimer,
                    restSeconds: restSeconds,
                    workPrep: workPrep
                )
            }

        }
        .padding(.horizontal, GymTheme.pageGutter)
        .padding(.bottom, GymTheme.pt(12))
        .background(GymTheme.pageFill)
    }
}

private struct FollowAlongSetCard: View {
    @Bindable var set: SetEntry
    let exercise: SessionExercise
    let setNumber: Int
    let setCount: Int
    let unitSystem: UnitSystem
    let sessionTimer: SessionTimer
    var restSeconds: Int = 0
    var prepRemaining: Int?

    @State private var activeMetric: SetMetric?

    private var isTimingThisSet: Bool { sessionTimer.isTiming(set) }

    var body: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.exerciseName)
                        .font(GymTheme.exerciseName)
                    Text(setIndexLine)
                        .font(GymTheme.setIndex)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifierIfPresent(exercise.kind == .timed ? "timedRestHint" : nil)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("followAlongSetIndex")
                .accessibilityLabel("\(exercise.exerciseName), \(exercise.kind.setLabel) \(setNumber) of \(setCount)")

                if !formNotes.isEmpty {
                    Text(formNotes)
                        .font(GymTheme.meta)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement()
                        .accessibilityIdentifier("exerciseNotes")
                        .accessibilityLabel(formNotes)
                }

                if let prepRemaining {
                    WorkPrepCountdownLabel(remaining: prepRemaining)
                } else if isTimingThisSet {
                    VStack(alignment: .leading, spacing: 4) {
                        CountdownText(
                            seconds: sessionTimer.remainingSeconds,
                            identifier: "workCountdown",
                            color: GymTheme.work
                        )
                        Text(sessionTimer.isPaused ? "Paused" : "Work")
                            .font(GymTheme.workLabel)
                            .foregroundStyle(GymTheme.work)
                    }
                } else {
                    FollowAlongMetrics(
                        set: set,
                        kind: exercise.kind,
                        unitSystem: unitSystem,
                        activeMetric: $activeMetric
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("followAlongCard")
        .sheet(item: $activeMetric) { metric in
            pickerSheet(for: metric)
        }
    }

    private var setIndexLine: String {
        var line = "\(exercise.kind.setLabel) \(setNumber) of \(setCount)"
        if exercise.kind == .timed, restSeconds > 0 {
            line += " · rest after \(Formatters.countdown(restSeconds))"
        }
        return line
    }

    private var formNotes: String {
        if !exercise.exerciseNotes.isEmpty { return exercise.exerciseNotes }
        return exercise.exercise?.notes ?? ""
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
}

private struct FollowAlongMetrics: View {
    @Bindable var set: SetEntry
    let kind: ExerciseKind
    let unitSystem: UnitSystem
    @Binding var activeMetric: SetMetric?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(kind.metrics) { metric in
                metricRow(metric)
            }
        }
    }

    @ViewBuilder
    private func metricRow(_ metric: SetMetric) -> some View {
        switch metric {
        case .speed:
            labeledNumeric(
                title: metric.fieldTitle,
                value: unitSystem.speedBinding($set.speed),
                placeholder: "Speed",
                unit: unitSystem.speedLabel
            )
        case .incline:
            labeledNumeric(
                title: metric.fieldTitle,
                value: Binding(get: { set.incline }, set: { set.incline = $0 ?? 0 }),
                placeholder: "Incline",
                unit: "%"
            )
        case .distance:
            labeledNumeric(
                title: metric.fieldTitle,
                value: unitSystem.distanceBinding($set.distance),
                placeholder: "Auto",
                unit: unitSystem.distanceLabel
            )
        case .weight:
            VStack(alignment: .leading, spacing: 8) {
                Text(metric.fieldTitle)
                    .font(GymTheme.fieldLabel)
                    .foregroundStyle(.secondary)
                HStack(spacing: GymTheme.stepperGap) {
                    GymStepperButton(systemImage: "minus") {
                        set.weight = unitSystem.bumpKilograms(set.weight, byDisplaySteps: -1)
                    }
                    .accessibilityIdentifier("decrementWeight")
                    .accessibilityLabel("Decrease weight")

                    MetricValueButton(
                        value: Formatters.weightNumber(set.weight, unit: unitSystem),
                        unit: unitSystem.weightLabel
                    ) {
                        activeMetric = .weight
                    }
                    .accessibilityIdentifier("weightValue")

                    GymStepperButton(systemImage: "plus") {
                        set.weight = unitSystem.bumpKilograms(set.weight, byDisplaySteps: 1)
                    }
                    .accessibilityIdentifier("incrementWeight")
                    .accessibilityLabel("Increase weight")
                }
            }
        case .reps, .duration:
            VStack(alignment: .leading, spacing: 8) {
                Text(metric.fieldTitle)
                    .font(GymTheme.fieldLabel)
                    .foregroundStyle(.secondary)
                if metric == .reps {
                    MetricValueButton(
                        value: "\(set.reps)",
                        unit: "reps"
                    ) {
                        activeMetric = metric
                    }
                    .accessibilityIdentifier("repsValue")
                } else {
                    MetricChip(
                        text: chipText(for: metric),
                        font: GymTheme.metricValue,
                        controlSize: .regular
                    ) {
                        activeMetric = metric
                    }
                    .accessibilityIdentifier("durationValue")
                }
            }
        }
    }

    private func labeledNumeric(
        title: String,
        value: Binding<Double?>,
        placeholder: String,
        unit: String
    ) -> some View {
        HStack {
            Text(title)
                .font(GymTheme.fieldLabel)
                .foregroundStyle(.secondary)
            Spacer()
            TextField(placeholder, value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .font(GymTheme.metricNumber)
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
            Text(unit)
                .font(GymTheme.metricUnit)
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
}

private struct FollowAlongActions: View {
    let set: SetEntry
    let kind: ExerciseKind
    let sessionTimer: SessionTimer
    let restSeconds: Int
    let workPrep: WorkPrepCountdown

    private var isTimingThisSet: Bool { sessionTimer.isTiming(set) }

    var body: some View {
        VStack(spacing: 8) {
            if kind.hasWorkTimer {
                timedPrimary
            } else {
                actionButton("Done", style: .primary, identifier: "followAlongDone") {
                    workPrep.cancel()
                    SetLogging.complete(set, kind: kind, timer: sessionTimer, restSeconds: restSeconds)
                }
                .accessibilityLabel("Mark set complete")
            }

            HStack(spacing: 8) {
                if kind.hasWorkTimer {
                    actionButton("Done", style: .secondary, identifier: "followAlongDone") {
                        workPrep.cancel()
                        SetLogging.complete(set, kind: kind, timer: sessionTimer, restSeconds: restSeconds)
                    }
                }

                if !kind.hasWorkTimer || !isTimingThisSet {
                    actionButton("Skip", style: .secondary, identifier: "skipSet") {
                        workPrep.cancel()
                        SetLogging.skip(set, timer: sessionTimer)
                    }
                }

                actionButton("Fail", style: .fail, identifier: "failSet") {
                    workPrep.cancel()
                    SetLogging.fail(set, kind: kind, timer: sessionTimer, restSeconds: restSeconds)
                }
            }
        }
    }

    @ViewBuilder
    private var timedPrimary: some View {
        if workPrep.isActive {
            actionButton("Cancel", style: .secondary, identifier: "cancelWorkPrep") {
                workPrep.cancel()
            }
        } else if isTimingThisSet && sessionTimer.isPaused {
            actionButton("Resume", style: .primary, identifier: "resumeWork") {
                sessionTimer.resume()
            }
        } else if isTimingThisSet {
            actionButton("Pause", style: .primary, identifier: "pauseWork") {
                sessionTimer.pause()
            }
        } else if kind == .timed {
            actionButton("Start", style: .primary, identifier: "startWork") {
                workPrep.start {
                    sessionTimer.startWork(
                        seconds: set.durationSeconds,
                        set: set,
                        followOnRestSeconds: kind.startsRestTimer ? restSeconds : 0
                    )
                }
            }
            .disabled(set.durationSeconds <= 0)
        } else {
            actionButton("Start", style: .primary, identifier: "startWork") {
                sessionTimer.startWork(
                    seconds: set.durationSeconds,
                    set: set,
                    followOnRestSeconds: kind.startsRestTimer ? restSeconds : 0
                )
            }
            .disabled(set.durationSeconds <= 0)
        }
    }

    private enum ActionStyle {
        case primary, secondary, fail
    }

    @ViewBuilder
    private func actionButton(
        _ title: String,
        style: ActionStyle,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        switch style {
        case .primary:
            Button(title, action: action)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .gymPrimaryButton()
                .accessibilityIdentifier(identifier)
        case .secondary:
            Button(title, action: action)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .gymGhostButton()
                .accessibilityIdentifier(identifier)
        case .fail:
            Button(title, action: action)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .gymFailButton()
                .accessibilityIdentifier(identifier)
        }
    }
}
