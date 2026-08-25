import SwiftData
import SwiftUI

struct ActiveWorkoutView: View {
    @Bindable var session: WorkoutSession
    let restTimer: RestTimer

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.weightUnit)
    private var weightUnit: WeightUnit = .kilograms
    @AppStorage(SettingsKeys.restDurationSeconds)
    private var restDuration: Int = SettingsDefaults.restDurationSeconds

    @State private var isPickingExercise = false
    @State private var isConfirmingCancel = false

    var body: some View {
        List {
            ForEach(session.orderedExercises) { sessionExercise in
                SessionExerciseSection(
                    sessionExercise: sessionExercise,
                    weightUnit: weightUnit,
                    onSetCompleted: {
                        if sessionExercise.kind.startsRestTimer {
                            restTimer.start(seconds: restDuration)
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
            if restTimer.isRunning {
                RestTimerBar(restTimer: restTimer)
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
    }

    private func finishWorkout() {
        restTimer.stop()
        WorkoutSessionService.finish(session, in: modelContext)
    }

    private func cancelWorkout() {
        restTimer.stop()
        WorkoutSessionService.cancel(session, in: modelContext)
    }
}

/// One exercise in the running workout: its sets plus an add-set button.
private struct SessionExerciseSection: View {
    let sessionExercise: SessionExercise
    let weightUnit: WeightUnit
    let onSetCompleted: () -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Section {
            ForEach(sessionExercise.orderedSets) { set in
                SetRow(
                    set: set,
                    setNumber: (sessionExercise.orderedSets.firstIndex(where: { $0 === set }) ?? 0) + 1,
                    kind: sessionExercise.kind,
                    weightUnit: weightUnit,
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
            modelContext.delete(ordered[index])
        }
        // Removing the last set removes the whole exercise from the session.
        if sessionExercise.sets.count == offsets.count {
            modelContext.delete(sessionExercise)
        }
    }
}

/// Editable metrics with a completion checkmark. Which fields appear is
/// driven entirely by the kind's metric list.
private struct SetRow: View {
    @Bindable var set: SetEntry
    let setNumber: Int
    let kind: ExerciseKind
    let weightUnit: WeightUnit
    let onCompleted: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(setNumber)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .padding(.top, 6)

            // One or two metrics fit on a single line; more get a labeled
            // row each.
            if kind.metrics.count <= 2 {
                compactFields
            } else {
                labeledFields
            }

            Button {
                toggleCompleted()
            } label: {
                Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(set.isCompleted ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .listRowBackground(set.isCompleted ? Color.accentColor.opacity(0.08) : nil)
    }

    private var compactFields: some View {
        HStack(spacing: 12) {
            ForEach(kind.metrics) { metric in
                if metric != kind.metrics.first {
                    Spacer()
                }
                inlineField(for: metric)
            }
        }
    }

    private var labeledFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(kind.metrics) { metric in
                HStack {
                    Text(metric.fieldTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    inlineField(for: metric)
                }
            }
        }
    }

    @ViewBuilder
    private func inlineField(for metric: SetMetric) -> some View {
        switch metric {
        case .duration:
            DurationField(seconds: $set.durationSeconds)
        case .weight:
            numberField(
                TextField("Weight", value: $set.weight, format: .number.precision(.fractionLength(0...1))),
                unit: weightUnit.rawValue
            )
        case .reps:
            numberField(
                TextField("Reps", value: $set.reps, format: .number).keyboardType(.numberPad),
                unit: "reps",
                width: 50
            )
        case .speed:
            numberField(
                TextField("Speed", value: $set.speed, format: .number.precision(.fractionLength(0...1))),
                unit: weightUnit.speedLabel
            )
        case .incline:
            numberField(
                TextField("Incline", value: $set.incline, format: .number.precision(.fractionLength(0...1))),
                unit: "%"
            )
        case .distance:
            numberField(
                TextField("Auto", value: $set.distance, format: .number.precision(.fractionLength(0...2))),
                unit: weightUnit.distanceLabel
            )
        }
    }

    private func numberField(_ field: some View, unit: String, width: CGFloat = 70) -> some View {
        HStack(spacing: 6) {
            field
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: width)
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func toggleCompleted() {
        set.isCompleted.toggle()
        if set.isCompleted {
            fillDerivedDistanceIfNeeded()
            onCompleted()
        }
    }

    /// A cardio block the user completed without typing a distance gets one
    /// derived from speed and duration; the field stays editable afterwards.
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

/// Bottom bar showing the running rest countdown with a skip button.
private struct RestTimerBar: View {
    let restTimer: RestTimer

    var body: some View {
        HStack {
            Image(systemName: "timer")
            Text("Rest: \(Formatters.countdown(restTimer.remainingSeconds))")
                .font(.headline.monospacedDigit())

            Spacer()

            Button("Skip") { restTimer.stop() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
        .padding()
        .background(.bar)
    }
}
