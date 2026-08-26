import SwiftData
import SwiftUI

/// First-launch landing: height and body weight, needed later for calories.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.weightUnit) private var weightUnit: WeightUnit = .kilograms

    @State private var weight: Double = 50
    @State private var heightCentimeters: Int = 160
    @State private var heightFeet: Int = 5
    @State private var heightInches: Int = 3

    private var canContinue: Bool {
        weight > 0 && resolvedHeightCentimeters > 0
    }

    private var resolvedHeightCentimeters: Double {
        switch weightUnit {
        case .kilograms:
            return Double(heightCentimeters)
        case .pounds:
            return BodyMetrics.centimeters(feet: heightFeet, inches: Double(heightInches))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("A few details now, so we can estimate calories later.")
                        .foregroundStyle(.secondary)
                }

                Section("Units") {
                    Picker("Units", selection: $weightUnit) {
                        Text("kg · cm").tag(WeightUnit.kilograms)
                        Text("lb · ft/in").tag(WeightUnit.pounds)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Height") {
                    HeightWheelPicker(
                        unit: weightUnit,
                        centimeters: $heightCentimeters,
                        feet: $heightFeet,
                        inches: $heightInches
                    )
                }

                Section("Weight") {
                    WeightWheelPicker(weight: $weight, unit: weightUnit)
                }
            }
            .navigationTitle("Welcome")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Continue") { save() }
                        .disabled(!canContinue)
                }
            }
        }
    }

    private func save() {
        guard weight > 0, resolvedHeightCentimeters > 0 else { return }
        ProfileService.completeOnboarding(
            heightCentimeters: resolvedHeightCentimeters,
            weight: weight,
            in: modelContext
        )
    }
}
