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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                switch focus {
                case .rest:
                    restCard
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                LabeledContent(
                    "Elapsed",
                    value: Formatters.elapsed(context.date.timeIntervalSince(session.startedAt))
                )
                .accessibilityIdentifier("elapsedWorkoutTime")
            }
            LabeledContent("Logged", value: progress.caption)
                .accessibilityIdentifier("workoutProgress")
            Text(progress.nextLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("nextSetCue")
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var restCard: some View {
        VStack(spacing: 16) {
            Text("Rest")
                .font(.title2.weight(.semibold))
            Text(Formatters.countdown(sessionTimer.remainingSeconds))
                .font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())
            Text(progress.nextLine)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("followAlongRest")
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add an exercise to follow along.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var finishedCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All rows logged")
                .font(.title2.weight(.semibold))
            Text("Finish from the top-right to save, or open All sets to change a row.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
        .accessibilityIdentifier("followAlongFinished")
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 12) {
            if sessionTimer.phase == .rest {
                restControls
            } else if let set = currentSet, let kind = set.sessionExercise?.kind {
                FollowAlongActions(
                    set: set,
                    kind: kind,
                    sessionTimer: sessionTimer,
                    restSeconds: restSeconds
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

    private var restControls: some View {
        HStack(spacing: 8) {
            Button {
                sessionTimer.adjustRest(by: -15)
            } label: {
                Text("−15")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("decrementRest")
            .accessibilityLabel("Subtract 15 seconds of rest")

            Button {
                sessionTimer.adjustRest(by: 15)
            } label: {
                Text("+15")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("incrementRest")
            .accessibilityLabel("Add 15 seconds of rest")

            Button("Skip") { sessionTimer.stop() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("skipRest")
                .accessibilityLabel("Skip rest")
        }
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
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.exerciseName)
                    .font(.title.weight(.semibold))
                Text("\(exercise.kind.setLabel) \(setNumber) of \(setCount)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                if !formNotes.isEmpty {
                    Text(formNotes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("followAlongSetIndex")
            .accessibilityLabel("\(exercise.exerciseName), \(exercise.kind.setLabel) \(setNumber) of \(setCount)")

            if isTimingThisSet {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Formatters.countdown(sessionTimer.remainingSeconds))
                        .font(.system(size: 64, weight: .semibold, design: .rounded).monospacedDigit())
                        .accessibilityIdentifier("workCountdown")
                    Text(sessionTimer.isPaused ? "Paused" : "Work")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
            HStack {
                Text(metric.fieldTitle)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    set.weight = unitSystem.bumpKilograms(set.weight, byDisplaySteps: -1)
                } label: {
                    Image(systemName: "minus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("decrementWeight")
                .accessibilityLabel("Decrease weight")

                Button {
                    activeMetric = .weight
                } label: {
                    Text(Formatters.weight(set.weight, unit: unitSystem))
                        .font(.title3.monospacedDigit())
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("weightValue")

                Button {
                    set.weight = unitSystem.bumpKilograms(set.weight, byDisplaySteps: 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("incrementWeight")
                .accessibilityLabel("Increase weight")
            }
        case .reps, .duration:
            HStack {
                Text(metric.fieldTitle)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    activeMetric = metric
                } label: {
                    Text(chipText(for: metric))
                        .font(.title3.monospacedDigit())
                }
                .buttonStyle(.bordered)
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
                .foregroundStyle(.secondary)
            Spacer()
            TextField(placeholder, value: value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 72)
            Text(unit)
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

    private var isTimingThisSet: Bool { sessionTimer.isTiming(set) }

    var body: some View {
        VStack(spacing: 12) {
            if kind == .timed {
                timedPrimary
            } else {
                Button("Done") {
                    SetLogging.complete(set, kind: kind, timer: sessionTimer, restSeconds: restSeconds)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("followAlongDone")
            }

            HStack(spacing: 12) {
                if kind == .timed {
                    Button("Done") {
                        SetLogging.complete(set, kind: kind, timer: sessionTimer, restSeconds: restSeconds)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("followAlongDone")
                }
                Button("Skip") {
                    SetLogging.skip(set, timer: sessionTimer)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("skipSet")
                Button("Fail") {
                    SetLogging.fail(set, kind: kind, timer: sessionTimer, restSeconds: restSeconds)
                }
                .buttonStyle(.bordered)
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
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("resumeWork")
        } else if isTimingThisSet {
            Button("Pause") { sessionTimer.pause() }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("pauseWork")
        } else {
            Button("Start") {
                sessionTimer.startWork(
                    seconds: set.durationSeconds,
                    set: set,
                    followOnRestSeconds: restSeconds
                )
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .disabled(set.durationSeconds <= 0)
            .accessibilityIdentifier("startWork")
        }
    }
}
