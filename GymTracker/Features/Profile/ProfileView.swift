import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    @AppStorage(SettingsKeys.weightUnit) private var weightUnit: WeightUnit = .kilograms
    @AppStorage(SettingsKeys.restDurationSeconds)
    private var restDuration: Int = SettingsDefaults.restDurationSeconds

    @State private var weight: Double = 50
    @State private var heightCentimeters: Int = 160
    @State private var heightFeet = 5
    @State private var heightInches = 3

    private static let restOptions = [30, 60, 90, 120, 180, 240, 300]

    private var profile: UserProfile? { profiles.first }
    private var latestWeight: BodyMeasurement? { measurements.first }

    var body: some View {
        Form {
            Section {
                Text("Height and weight are stored on this phone. Calorie estimates will use these values later.")
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
                Button("Save Height") { saveHeight() }
                    .disabled(resolvedHeightCentimeters <= 0)
            }

            Section("Weight") {
                WeightWheelPicker(weight: $weight, unit: weightUnit)
                Button("Update Weight") { saveWeight() }
                    .disabled(weight <= 0)

                if let latestWeight {
                    LabeledContent("Last logged") {
                        Text(Formatters.weight(latestWeight.weight, unit: weightUnit))
                        + Text("  ·  ").foregroundStyle(.secondary)
                        + Text(latestWeight.date, format: .dateTime.day().month().year())
                    }
                }

                NavigationLink("Weight history") {
                    BodyWeightHistoryList()
                }
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
            if let lastWeight = latestWeight?.weight, lastWeight > 0 {
                weight = lastWeight
            }
            loadHeightFromProfile()
        }
        .onChange(of: weightUnit) { _, _ in loadHeightFromProfile() }
    }

    private var resolvedHeightCentimeters: Double {
        switch weightUnit {
        case .kilograms:
            return Double(heightCentimeters)
        case .pounds:
            return BodyMetrics.centimeters(feet: heightFeet, inches: Double(heightInches))
        }
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
        ProfileService.upsertWeight(weight, in: modelContext)
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
