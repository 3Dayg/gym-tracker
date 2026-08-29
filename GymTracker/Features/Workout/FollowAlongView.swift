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
    @State private var isPlanGuidanceExpanded = false

    private var progress: LiveWorkoutProgress { LiveWorkoutProgress.from(session) }

    private var focus: FollowAlongFocus {
        FollowAlongFocus.current(session: session, timerPhase: sessionTimer.phase)
    }

    private var currentSet: SetEntry? {
        if sessionTimer.phase == .rest { return nil }
        return LiveWorkoutProgress.nextPendingSet(in: session)
    }

    private var addSetExercise: SessionExercise? {
        currentSet?.sessionExercise
            ?? LiveWorkoutProgress.nextPendingSet(in: session)?.sessionExercise
            ?? session.orderedExercises.last
    }

    private var hasTimedExercise: Bool {
        session.exercises.contains { $0.kind == .timed }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                WorkoutProgressHeader(
                    startedAt: session.startedAt,
                    progress: progress,
                    onShowExercises: session.exercises.isEmpty ? nil : { isShowingExerciseMap = true }
                )

                if !session.planNotes.isEmpty {
                    planGuidance
                }

                if hasTimedExercise {
                    LabeledContent("Rest after a round", value: Formatters.countdown(restSeconds))
                        .font(GymTheme.meta)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("timedRestHint")
                }

                switch focus {
                case .rest:
                    RestTakeoverCard(
                        remainingSeconds: sessionTimer.remainingSeconds,
                        nextLine: progress.nextLine,
                        combinedIdentifier: "followAlongRest"
                    )
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
                            sessionTimer: sessionTimer
                        )
                    } else {
                        Text(name)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .accessibilityIdentifier("followAlongRoot")
        .sensoryFeedback(.impact(weight: .medium), trigger: restEndedTick)
        .onChange(of: sessionTimer.phase) { oldPhase, newPhase in
            if oldPhase == .rest, newPhase == .idle {
                restEndedTick += 1
            }
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

    private var planGuidance: some View {
        DisclosureGroup("Plan guidance", isExpanded: $isPlanGuidanceExpanded) {
            Text(session.planNotes)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GymTheme.cardFill, in: RoundedRectangle(cornerRadius: GymTheme.cardRadius))
        .accessibilityIdentifier("planGuidance")
    }

    private var emptyCard: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Start is empty")
                    .font(.headline)
                Text("Add an exercise to log a set. Tick what you did, Skip what you pass on, or Discard to throw this workout away.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("emptyWorkoutHint")
            }
        }
    }

    private var finishedCard: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("All rows logged")
                    .font(.title2.weight(.semibold))
                Text("Finish from the top-right to save, or open Exercises to change a row.")
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
                    canDefer: LiveWorkoutProgress.canDefer(in: session),
                    onLater: deferCurrentExercise
                )
            }

            HStack(spacing: 12) {
                if let exercise = addSetExercise {
                    Button {
                        WorkoutSessionService.addSet(to: exercise)
                    } label: {
                        Label("Add \(exercise.kind.setLabel)", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addSetToCurrent")
                }
                Button("Add Exercise", action: onAddExercise)
                    .accessibilityIdentifier("addExercise")
                Spacer()
            }
            .font(.subheadline)
        }
        .padding()
        .background(.bar)
    }

    private func deferCurrentExercise() {
        if let set = currentSet, sessionTimer.isTiming(set) {
            sessionTimer.stop()
        }
        _ = LiveWorkoutProgress.deferCurrentExercise(in: session)
    }
}

private struct FollowAlongSetCard: View {
    @Bindable var set: SetEntry
    let exercise: SessionExercise
    let setNumber: Int
    let setCount: Int
    let unitSystem: UnitSystem
    let sessionTimer: SessionTimer

    @State private var activeMetric: SetMetric?

    private var isTimingThisSet: Bool { sessionTimer.isTiming(set) }

    var body: some View {
        GymCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.exerciseName)
                        .font(GymTheme.exerciseName)
                    Text("\(exercise.kind.setLabel) \(setNumber) of \(setCount)")
                        .font(GymTheme.setIndex)
                        .foregroundStyle(.secondary)
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

                if isTimingThisSet {
                    VStack(alignment: .leading, spacing: 4) {
                        CountdownText(
                            seconds: sessionTimer.remainingSeconds,
                            identifier: "workCountdown",
                            color: GymTheme.work
                        )
                        Text(sessionTimer.isPaused ? "Paused" : "Work")
                            .font(GymTheme.meta)
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
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.fieldTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button {
                        set.weight = unitSystem.bumpKilograms(set.weight, byDisplaySteps: -1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .gymSecondaryButton()
                    .accessibilityIdentifier("decrementWeight")
                    .accessibilityLabel("Decrease weight")

                    MetricChip(
                        text: Formatters.weight(set.weight, unit: unitSystem),
                        font: GymTheme.metricValue,
                        controlSize: .regular
                    ) {
                        activeMetric = .weight
                    }
                    .accessibilityIdentifier("weightValue")

                    Button {
                        set.weight = unitSystem.bumpKilograms(set.weight, byDisplaySteps: 1)
                    } label: {
                        Image(systemName: "plus")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .gymSecondaryButton()
                    .accessibilityIdentifier("incrementWeight")
                    .accessibilityLabel("Increase weight")
                    Spacer()
                }
            }
        case .reps, .duration:
            HStack {
                Text(metric.fieldTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                MetricChip(
                    text: chipText(for: metric),
                    font: GymTheme.metricValue,
                    controlSize: .regular
                ) {
                    activeMetric = metric
                }
                .accessibilityIdentifier(metric == .duration ? "durationValue" : "repsValue")
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
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
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
}

private struct FollowAlongActions: View {
    let set: SetEntry
    let kind: ExerciseKind
    let sessionTimer: SessionTimer
    let restSeconds: Int
    let canDefer: Bool
    let onLater: () -> Void

    private var isTimingThisSet: Bool { sessionTimer.isTiming(set) }

    var body: some View {
        VStack(spacing: 12) {
            if kind.hasWorkTimer {
                timedPrimary
            } else {
                Button("Done") {
                    SetLogging.complete(set, kind: kind, timer: sessionTimer, restSeconds: restSeconds)
                }
                .gymPrimaryButton()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("followAlongDone")
                .accessibilityLabel("Mark set complete")
            }

            HStack(spacing: 12) {
                if kind.hasWorkTimer {
                    Button("Done") {
                        SetLogging.complete(set, kind: kind, timer: sessionTimer, restSeconds: restSeconds)
                    }
                    .gymSecondaryButton()
                    .controlSize(.large)
                    .accessibilityIdentifier("followAlongDone")
                }
                Button("Later") { onLater() }
                    .gymSecondaryButton()
                    .controlSize(.large)
                    .disabled(!canDefer)
                    .accessibilityIdentifier("deferExercise")
                    .accessibilityHint("Leaves this exercise unfinished and shows the next one")
                Button("Skip") {
                    SetLogging.skip(set, timer: sessionTimer)
                }
                .gymSecondaryButton()
                .controlSize(.large)
                .accessibilityIdentifier("skipSet")
                Button("Fail") {
                    SetLogging.fail(set, kind: kind, timer: sessionTimer, restSeconds: restSeconds)
                }
                .gymFailButton()
                .controlSize(.large)
                .accessibilityIdentifier("failSet")
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var timedPrimary: some View {
        if isTimingThisSet && sessionTimer.isPaused {
            Button("Resume") { sessionTimer.resume() }
                .gymPrimaryButton()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("resumeWork")
        } else if isTimingThisSet {
            Button("Pause") { sessionTimer.pause() }
                .gymSecondaryButton()
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("pauseWork")
        } else {
            Button("Start") {
                sessionTimer.startWork(
                    seconds: set.durationSeconds,
                    set: set,
                    followOnRestSeconds: kind.startsRestTimer ? restSeconds : 0
                )
            }
            .gymPrimaryButton()
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(set.durationSeconds <= 0)
            .accessibilityIdentifier("startWork")
        }
    }
}
