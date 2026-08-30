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
    @State private var showMeasurements = false

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
            ScrollView {
                VStack(alignment: .leading, spacing: GymTheme.cardGap) {
                    GymScreenTitle(title: "Welcome")

                    GymCard(padding: 0) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Your workouts stay on this iPhone — no account or internet needed.")
                                .font(GymTheme.caption)
                                .foregroundStyle(GymTheme.muted)
                                .padding(.horizontal, GymTheme.rowPadX)
                                .padding(.vertical, GymTheme.rowPadY)
                                .accessibilityIdentifier("onboardingPrivacyCopy")
                            GymTheme.hairline.frame(height: 0.5)
                            NavigationLink {
                                PrivacyPolicyView()
                            } label: {
                                Text("Privacy")
                                    .font(GymTheme.rowName)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, GymTheme.rowPadX)
                                    .padding(.vertical, GymTheme.rowPadY)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("onboardingPrivacyPolicy")
                        }
                    }

                    GymSectionLabel(title: "Units")
                    GymCard {
                        Picker("Units", selection: $unitSystem) {
                            ForEach(UnitSystem.allCases) { unit in
                                Text(unit.displayName).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("onboardingUnits")
                    }

                    GymCard {
                        if showMeasurements {
                            VStack(alignment: .leading, spacing: 12) {
                                HeightWheelPicker(
                                    unit: unitSystem,
                                    centimeters: $heightCentimeters,
                                    feet: $heightFeet,
                                    inches: $heightInches
                                )
                                WeightWheelPicker(weight: $weight, unit: unitSystem)
                                Text("Optional. Used for the body-weight trend on the Progress tab — not required to start training.")
                                    .font(GymTheme.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("onboardingWeightFooter")
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Height & weight")
                                    .font(GymTheme.rowName)
                                Text("Optional. Used only for the Progress trend. Add later in Settings.")
                                    .font(GymTheme.caption)
                                    .foregroundStyle(GymTheme.muted)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }

                    Button("Get started") {
                        if showMeasurements {
                            save()
                        } else {
                            skip()
                        }
                    }
                    .gymPrimaryButton()
                    .accessibilityIdentifier(showMeasurements ? "continueOnboarding" : "skipOnboarding")

                    if !showMeasurements {
                        Button("Add measurements") {
                            showMeasurements = true
                        }
                        .gymGhostButton()
                        .accessibilityIdentifier("addOnboardingMeasurements")
                    }
                }
                .padding(.horizontal, GymTheme.pageGutter)
                .padding(.bottom, GymTheme.pt(12))
            }
            .background(GymTheme.pageFill)
            .gymMockScreenChrome("Welcome")
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
