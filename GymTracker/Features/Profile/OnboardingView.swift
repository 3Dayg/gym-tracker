import SwiftData
import SwiftUI

/// First-launch landing: height and body weight, needed later for calories.
struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.weightUnit) private var weightUnit: WeightUnit = .kilograms

    @State private var weight: Double?
    @State private var heightCentimeters: Double?
    @State private var heightFeet: Int = 5
    @State private var heightInches: Double = 7

    private var canContinue: Bool {
        (weight ?? 0) > 0 && resolvedHeightCentimeters > 0
    }

    private var resolvedHeightCentimeters: Double {
        switch weightUnit {
        case .kilograms:
            return heightCentimeters ?? 0
        case .pounds:
            return BodyMetrics.centimeters(feet: heightFeet, inches: heightInches)
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
                    heightFields
                }

                Section("Weight") {
                    HStack {
                        TextField("Weight", value: $weight, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                        Text(weightUnit.rawValue)
                            .foregroundStyle(.secondary)
                    }
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

    @ViewBuilder
    private var heightFields: some View {
        switch weightUnit {
        case .kilograms:
            HStack {
                TextField("Height", value: $heightCentimeters, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                Text("cm")
                    .foregroundStyle(.secondary)
            }
        case .pounds:
            Stepper(value: $heightFeet, in: 3...7) {
                Text("\(heightFeet) ft")
            }
            HStack {
                TextField("Inches", value: $heightInches, format: .number.precision(.fractionLength(0...1)))
                    .keyboardType(.decimalPad)
                Text("in")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func save() {
        guard let weight, weight > 0, resolvedHeightCentimeters > 0 else { return }
        ProfileService.completeOnboarding(
            heightCentimeters: resolvedHeightCentimeters,
            weight: weight,
            in: modelContext
        )
    }
}
