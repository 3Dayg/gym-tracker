import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    @AppStorage(SettingsKeys.unitSystem) private var unitSystem: UnitSystem = .metric
    @AppStorage(SettingsKeys.restDurationSeconds)
    private var restDuration: Int = SettingsDefaults.restDurationSeconds

    /// Entered in the display unit; converted to kilograms on save.
    @State private var weight: Double = 70
    @State private var heightCentimeters: Int = 170
    @State private var heightFeet = 5
    @State private var heightInches = 7

    private static let restOptions = [30, 60, 90, 120, 180, 240, 300]

    private var profile: UserProfile? { profiles.first }
    private var latestWeight: BodyMeasurement? { measurements.first }

    var body: some View {
        Form {
            Section {
                Text("Your data stays on this iPhone — no account or internet. Height is optional. Body weight is used for the trend chart on Progress.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("profilePrivacyCopy")
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Text("Privacy")
                }
                .accessibilityIdentifier("privacyPolicy")
            }

            Section {
                Picker("Units", selection: $unitSystem) {
                    ForEach(UnitSystem.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Units")
            } footer: {
                Text("Metric shows kg, cm, and km; Imperial shows lb, ft/in, and mi. Switching converts everything automatically — nothing is lost.")
            }

            Section {
                if let cm = profile?.heightCentimeters, cm > 0 {
                    LabeledContent("Saved") {
                        Text(BodyMetrics.formatHeight(cm, unit: unitSystem))
                    }
                } else {
                    Text("Not set yet")
                        .foregroundStyle(.secondary)
                }
                HeightWheelPicker(
                    unit: unitSystem,
                    centimeters: $heightCentimeters,
                    feet: $heightFeet,
                    inches: $heightInches
                )
                Button("Save Height") { saveHeight() }
                    .disabled(resolvedHeightCentimeters <= 0)
            } header: {
                Text("Height")
            } footer: {
                Text("Optional. Nothing in the app depends on it today.")
            }

            Section {
                WeightWheelPicker(weight: $weight, unit: unitSystem)
                Button("Update Weight") { saveWeight() }
                    .disabled(weight <= 0)

                if let latestWeight {
                    LabeledContent("Last logged") {
                        Text(Formatters.weight(latestWeight.weight, unit: unitSystem))
                        + Text("  ·  ").foregroundStyle(.secondary)
                        + Text(latestWeight.date, format: .dateTime.day().month().year())
                    }
                }

                NavigationLink("Weight history") {
                    BodyWeightHistoryList()
                }
            } header: {
                Text("Body weight")
            } footer: {
                Text("Used for the trend chart on the Progress tab. Skip it if you only want to log workouts.")
            }

            Section("Workout") {
                Picker("Rest timer", selection: $restDuration) {
                    ForEach(Self.restOptions, id: \.self) { seconds in
                        Text(Formatters.countdown(seconds)).tag(seconds)
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .onAppear {
            loadWeightFromLatestMeasurement()
            loadHeightFromProfile()
        }
        .onChange(of: unitSystem) { oldUnit, newUnit in
            convertWeightInput(from: oldUnit, to: newUnit)
            loadHeightFromProfile()
        }
    }

    private var resolvedHeightCentimeters: Double {
        switch unitSystem {
        case .metric:
            return Double(heightCentimeters)
        case .imperial:
            return BodyMetrics.centimeters(feet: heightFeet, inches: Double(heightInches))
        }
    }

    private func loadWeightFromLatestMeasurement() {
        guard let kilograms = latestWeight?.weight, kilograms > 0 else { return }
        weight = (unitSystem.displayWeight(fromKilograms: kilograms) * 10).rounded() / 10
    }

    private func convertWeightInput(from oldUnit: UnitSystem, to newUnit: UnitSystem) {
        let kilograms = oldUnit.kilograms(fromDisplayWeight: weight)
        weight = (newUnit.displayWeight(fromKilograms: kilograms) * 10).rounded() / 10
    }

    private func loadHeightFromProfile() {
        guard let cm = profile?.heightCentimeters, cm > 0 else { return }
        heightCentimeters = Int(cm.rounded())
        let parts = BodyMetrics.feetAndInches(fromCentimeters: cm)
        heightFeet = parts.feet
        heightInches = min(11, Int(parts.inches.rounded()))
    }

    private func saveHeight() {
        guard resolvedHeightCentimeters > 0 else { return }
        ProfileService.updateHeight(resolvedHeightCentimeters, in: modelContext)
    }

    private func saveWeight() {
        guard weight > 0 else { return }
        ProfileService.upsertWeight(unitSystem.kilograms(fromDisplayWeight: weight), in: modelContext)
    }
}

/// Opens the profile from any tab that has a navigation bar.
struct ProfileToolbarButton: View {
    var body: some View {
        NavigationLink {
            ProfileView()
        } label: {
            Label("Profile", systemImage: "person.crop.circle")
        }
    }
}
