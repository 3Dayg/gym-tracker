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
/// target fields come from the kind's metric list.
private struct PlannedExerciseRow: View {
    @Bindable var plannedExercise: PlannedExercise
    let weightUnit: WeightUnit

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
    }

    @ViewBuilder
    private func targetField(for metric: SetMetric) -> some View {
        switch metric {
        case .reps:
            Stepper(value: $plannedExercise.targetReps, in: 1...50) {
                Text("\(plannedExercise.targetReps) reps")
                    .font(.subheadline)
            }
        case .duration:
            HStack {
                Text("Time")
                Spacer()
                DurationField(seconds: $plannedExercise.targetDurationSeconds)
            }
            .font(.subheadline)
        case .weight:
            targetRow(
                title: "Weight",
                value: $plannedExercise.targetWeight,
                placeholder: "Last used",
                unit: weightUnit.rawValue
            )
        case .speed:
            targetRow(title: "Speed", value: $plannedExercise.targetSpeed, unit: weightUnit.speedLabel)
        case .incline:
            targetRow(title: "Incline", value: $plannedExercise.targetIncline, unit: "%")
        case .distance:
            targetRow(
                title: "Distance",
                value: $plannedExercise.targetDistance,
                placeholder: "Optional",
                unit: weightUnit.distanceLabel
            )
        }
    }

    private func targetRow(
        title: String,
        value: Binding<Double?>,
        placeholder: String? = nil,
        unit: String
    ) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            TextField(
                placeholder ?? title,
                value: value,
                format: .number.precision(.fractionLength(0...2))
            )
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(width: 90)
            Text(unit)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}
