import SwiftData
import SwiftUI

struct PlanEditorView: View {
    @Bindable var plan: WorkoutPlan

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.weightUnit) private var weightUnit: WeightUnit = .kilograms
    @State private var isPickingExercise = false

    var body: some View {
        Form {
            Section {
                TextField("Plan name", text: $plan.name)
                TextField("Notes", text: $plan.notes, axis: .vertical)
                    .lineLimit(2...4)
            }

            Section("Exercises") {
                ForEach(plan.orderedExercises) { plannedExercise in
                    PlannedExerciseRow(plannedExercise: plannedExercise, weightUnit: weightUnit)
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)

                Button {
                    isPickingExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
            }
        }
        .navigationTitle(plan.name.isEmpty ? "Plan" : plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $isPickingExercise) {
            ExercisePickerView { exercise in
                addExercise(exercise)
            }
        }
    }

    private func addExercise(_ exercise: Exercise) {
        let nextOrder = (plan.exercises.map(\.sortOrder).max() ?? -1) + 1
        let planned: PlannedExercise
        switch exercise.kind {
        case .strength:
            planned = PlannedExercise(exercise: exercise, sortOrder: nextOrder)
        case .timed:
            planned = PlannedExercise(
                exercise: exercise,
                sortOrder: nextOrder,
                targetSets: 3,
                targetDurationSeconds: 60
            )
        case .cardio:
            planned = PlannedExercise(
                exercise: exercise,
                sortOrder: nextOrder,
                targetSets: 1,
                targetDurationSeconds: 600,
                targetSpeed: 5,
                targetIncline: 0
            )
        }
        planned.plan = plan
        modelContext.insert(planned)
    }

    private func deleteExercises(at offsets: IndexSet) {
        let ordered = plan.orderedExercises
        for index in offsets {
            modelContext.delete(ordered[index])
        }
        normalizeSortOrder()
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var ordered = plan.orderedExercises
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, item) in ordered.enumerated() {
            item.sortOrder = index
        }
    }

    private func normalizeSortOrder() {
        for (index, item) in plan.orderedExercises.enumerated() {
            item.sortOrder = index
        }
    }
}

/// One planned exercise. The sets stepper is always shown; the remaining
/// target fields come from the kind's metric list. Values are tappable
/// chips that open native wheel pickers.
private struct PlannedExerciseRow: View {
    @Bindable var plannedExercise: PlannedExercise
    let weightUnit: WeightUnit

    @State private var activeMetric: SetMetric?

    private var kind: ExerciseKind { plannedExercise.kind }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plannedExercise.exerciseName)
                .font(.headline)

            Stepper(value: $plannedExercise.targetSets, in: 1...10) {
                Text("\(plannedExercise.targetSets) \(kind.setLabel.lowercased())s")
                    .font(.subheadline)
            }

            ForEach(kind.metrics) { metric in
                targetField(for: metric)
            }
        }
        .padding(.vertical, 4)
        .sheet(item: $activeMetric) { metric in
            pickerSheet(for: metric)
        }
    }

    /// Weight and time open wheel pickers; reps use a stepper; machine
    /// settings (speed, incline, distance) are free keyboard input.
    @ViewBuilder
    private func targetField(for metric: SetMetric) -> some View {
        switch metric {
        case .reps:
            Stepper(value: $plannedExercise.targetReps, in: 1...50) {
                Text("\(plannedExercise.targetReps) reps")
                    .font(.subheadline)
            }
        case .speed:
            numericRow(
                metric: metric,
                value: $plannedExercise.targetSpeed,
                placeholder: "Speed",
                unit: weightUnit.speedLabel
            )
        case .incline:
            numericRow(metric: metric, value: $plannedExercise.targetIncline, placeholder: "Incline", unit: "%")
        case .distance:
            numericRow(
                metric: metric,
                value: $plannedExercise.targetDistance,
                placeholder: "Auto",
                unit: weightUnit.distanceLabel
            )
        default:
            HStack {
                Text(metric.fieldTitle)
                    .font(.subheadline)
                Spacer()
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
    }

    private func numericRow(
        metric: SetMetric,
        value: Binding<Double?>,
        placeholder: String,
        unit: String
    ) -> some View {
        HStack {
            Text(metric.fieldTitle)
                .font(.subheadline)
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
        case .reps: "\(plannedExercise.targetReps) reps"
        case .duration: Formatters.durationSeconds(plannedExercise.targetDurationSeconds)
        case .weight:
            plannedExercise.targetWeight.map { Formatters.weight($0, unit: weightUnit) } ?? "Last used"
        case .speed:
            plannedExercise.targetSpeed.map { Formatters.speed($0, unit: weightUnit) } ?? "Not set"
        case .incline:
            plannedExercise.targetIncline.map(Formatters.incline) ?? "Not set"
        case .distance:
            plannedExercise.targetDistance.map { Formatters.distance($0, unit: weightUnit) } ?? "Auto"
        }
    }

    @ViewBuilder
    private func pickerSheet(for metric: SetMetric) -> some View {
        switch metric {
        case .duration:
            DurationPickerSheet(seconds: $plannedExercise.targetDurationSeconds)
        case .weight:
            NumberPickerSheet(
                title: "Weight",
                unit: weightUnit.rawValue,
                values: metric.wheelValues,
                value: $plannedExercise.targetWeight,
                clearLabel: "Last used"
            )
        case .speed, .incline, .distance:
            EmptyView() // Edited inline with the keyboard.
        case .reps:
            EmptyView() // Reps use the stepper above.
        }
    }
}
