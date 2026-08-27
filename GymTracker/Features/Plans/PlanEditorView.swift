import SwiftData
import SwiftUI

struct PlanEditorView: View {
    @Bindable var plan: WorkoutPlan
    var onCancel: (() -> Void)?
    var onCreate: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(AppNavigation.self) private var navigation
    @AppStorage(SettingsKeys.unitSystem) private var unitSystem: UnitSystem = .metric
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil })
    private var activeSessions: [WorkoutSession]
    @State private var isPickingExercise = false

    private var isCreating: Bool { plan.isDraft }

    private var restSelection: Binding<Int> {
        Binding(
            get: { plan.targetRestSeconds ?? -1 },
            set: { plan.targetRestSeconds = $0 < 0 ? nil : $0 }
        )
    }

    private var startSummary: PlanStartSummary { PlanStartSummary.from(plan) }

    var body: some View {
        Form {
            Section {
                TextField("Plan name", text: $plan.name)
                    .accessibilityIdentifier("planNameField")
                TextField("Notes", text: $plan.notes, axis: .vertical)
                    .lineLimit(2...6)
            } footer: {
                Text(startSummary.listCaption())
            }

            if !startSummary.canStart {
                Section {
                    Text(startSummary.blockedReason)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("planEditorBlockedReason")
                }
            }

            Section {
                Picker("Rest between sets", selection: restSelection) {
                    Text("Use app setting").tag(-1)
                    ForEach([30, 60, 90, 120, 180, 240, 300], id: \.self) { seconds in
                        Text(Formatters.countdown(seconds)).tag(seconds)
                    }
                }
            } footer: {
                Text("Timed rounds start this rest automatically when the work countdown hits zero.")
            }

            Section("Exercises") {
                if plan.exercises.isEmpty {
                    Text("Add the lifts or rounds this plan should include.")
                        .foregroundStyle(.secondary)
                    Button {
                        isPickingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                    .accessibilityIdentifier("emptyPlanAddExercise")
                } else {
                    ForEach(plan.orderedExercises) { plannedExercise in
                        PlannedExerciseRow(plannedExercise: plannedExercise, unitSystem: unitSystem)
                    }
                    .onDelete(perform: deleteExercises)
                    .onMove(perform: moveExercises)

                    Button {
                        isPickingExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                    .accessibilityIdentifier("addExercise")
                }
            }
        }
        .navigationTitle(plan.name.isEmpty ? "Plan" : plan.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isCreating)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if isCreating {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onCancel?() }
                        .accessibilityIdentifier("cancelCreatePlan")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") { onCreate?() }
                        .fontWeight(.semibold)
                        .accessibilityIdentifier("confirmCreatePlan")
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    EditButton()
                }
                if startSummary.canStart {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Start") { startWorkout() }
                            .fontWeight(.semibold)
                            .accessibilityLabel("Start Workout")
                            .accessibilityIdentifier("startPlanFromEditor")
                    }
                }
            }
        }
        .sheet(isPresented: $isPickingExercise) {
            NavigationStack {
                ExercisePickerView(allowsMultipleSelection: true) { exercise in
                    PlanBuilder.addExercise(exercise, to: plan, in: modelContext)
                }
            }
        }
    }

    private func startWorkout() {
        guard startSummary.canStart else { return }
        if activeSessions.isEmpty {
            WorkoutSessionService.startSession(from: plan, in: modelContext)
        }
        navigation.openWorkout()
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
    let unitSystem: UnitSystem

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
                value: unitSystem.speedBinding($plannedExercise.targetSpeed),
                placeholder: "Speed",
                unit: unitSystem.speedLabel
            )
        case .incline:
            numericRow(metric: metric, value: $plannedExercise.targetIncline, placeholder: "Incline", unit: "%")
        case .distance:
            numericRow(
                metric: metric,
                value: unitSystem.distanceBinding($plannedExercise.targetDistance),
                placeholder: "Auto",
                unit: unitSystem.distanceLabel
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
            plannedExercise.targetWeight.map { Formatters.weight($0, unit: unitSystem) } ?? "Last used"
        case .speed:
            plannedExercise.targetSpeed.map { Formatters.speed($0, unit: unitSystem) } ?? "Not set"
        case .incline:
            plannedExercise.targetIncline.map(Formatters.incline) ?? "Not set"
        case .distance:
            plannedExercise.targetDistance.map { Formatters.distance($0, unit: unitSystem) } ?? "Auto"
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
                unit: unitSystem.weightLabel,
                values: metric.wheelValues,
                value: unitSystem.weightBinding($plannedExercise.targetWeight),
                clearLabel: "Last used"
            )
        case .speed, .incline, .distance:
            EmptyView() // Edited inline with the keyboard.
        case .reps:
            EmptyView() // Reps use the stepper above.
        }
    }
}
