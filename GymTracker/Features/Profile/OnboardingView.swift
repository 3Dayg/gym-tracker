import SwiftData
import SwiftUI

/// First-launch landing: pick units, optionally save height and weight.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.unitSystem) private var unitSystem: UnitSystem = .metric

    /// Entered in the display unit; converted to kilograms on save.
    @State private var weight: Double = 70
    @State private var heightCentimeters: Int = 170
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 7

    private var resolvedHeightCentimeters: Double {
        switch unitSystem {
        case .metric:
            return Double(heightCentimeters)
        case .imperial:
            return BodyMetrics.centimeters(feet: heightFeet, inches: Double(heightInches))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Your workouts stay on this iPhone — no account or internet needed.")
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("onboardingPrivacyCopy")
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Text("Privacy")
                    }
                    .accessibilityIdentifier("onboardingPrivacyPolicy")
                }

                Section {
                    Picker("Units", selection: $unitSystem) {
                        ForEach(UnitSystem.allCases) { unit in
                            Text(unit.displayName).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("onboardingUnits")
                } header: {
                    Text("Units")
                }

                Section {
                    HeightWheelPicker(
                        unit: unitSystem,
                        centimeters: $heightCentimeters,
                        feet: $heightFeet,
                        inches: $heightInches
                    )
                } header: {
                    Text("Height")
                } footer: {
                    Text("Optional. You can add this later in Settings. Save & Continue stores the numbers on these wheels; Skip for now leaves them unset.")
                }

                Section {
                    WeightWheelPicker(weight: $weight, unit: unitSystem)
                } header: {
                    Text("Body weight")
                } footer: {
                    Text("Optional. Used for the body-weight trend on the Progress tab — not required to start training.")
                        .accessibilityIdentifier("onboardingWeightFooter")
                }
            }
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip for now") { skip() }
                        .accessibilityIdentifier("skipOnboarding")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save & Continue") { save() }
                        .accessibilityIdentifier("continueOnboarding")
                }
            }
            .onChange(of: unitSystem) { oldUnit, newUnit in
                convertInputs(from: oldUnit, to: newUnit)
            }
        }
    }

    /// Keeps the wheels showing the same physical height and weight when
    /// the unit system changes.
    private func convertInputs(from oldUnit: UnitSystem, to newUnit: UnitSystem) {
        let kilograms = oldUnit.kilograms(fromDisplayWeight: weight)
        weight = (newUnit.displayWeight(fromKilograms: kilograms) * 10).rounded() / 10

        switch newUnit {
        case .metric:
            let centimeters = BodyMetrics.centimeters(feet: heightFeet, inches: Double(heightInches))
            heightCentimeters = Int(centimeters.rounded())
        case .imperial:
            let parts = BodyMetrics.feetAndInches(fromCentimeters: Double(heightCentimeters))
            heightFeet = parts.feet
            heightInches = min(11, Int(parts.inches.rounded()))
        }
    }

    private func skip() {
        ProfileService.skipOnboarding(in: modelContext)
    }

    private func save() {
        let height = resolvedHeightCentimeters > 0 ? resolvedHeightCentimeters : nil
        let kilograms = weight > 0 ? unitSystem.kilograms(fromDisplayWeight: weight) : nil
        ProfileService.completeOnboarding(
            heightCentimeters: height,
            weight: kilograms,
            in: modelContext
        )
    }
}
