import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [UserProfile]
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var measurements: [BodyMeasurement]

    @AppStorage(SettingsKeys.unitSystem) private var unitSystem: UnitSystem = .metric
    @AppStorage(SettingsKeys.restDurationSeconds)
    private var restDuration: Int = SettingsDefaults.restDurationSeconds
    @AppStorage(SettingsKeys.appearance) private var appearance: AppearancePreference = .system

    /// Entered in the display unit; converted to kilograms on save.
    @State private var weight: Double = 70
    @State private var heightCentimeters: Int = 170
    @State private var heightFeet = 5
    @State private var heightInches = 7
    @State private var isConfirmingDeleteAll = false

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
            }

            Section {
                Picker("Appearance", selection: $appearance) {
                    ForEach(AppearancePreference.allCases) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("appearancePicker")
            } header: {
                Text("Appearance")
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
                DisclosureGroup("Adjust") {
                    HeightWheelPicker(
                        unit: unitSystem,
                        centimeters: $heightCentimeters,
                        feet: $heightFeet,
                        inches: $heightInches
                    )
                    Button("Save Height") { saveHeight() }
                        .disabled(resolvedHeightCentimeters <= 0)
                }
            } header: {
                Text("Height")
            } footer: {
                Text("Optional. Nothing in the app depends on it today.")
            }

            Section {
                if let latestWeight {
                    LabeledContent("Last logged") {
                        Text(Formatters.weight(latestWeight.weight, unit: unitSystem))
                        + Text("  ·  ").foregroundStyle(.secondary)
                        + Text(latestWeight.date, format: .dateTime.day().month().year())
                    }
                }
                DisclosureGroup("Adjust") {
                    WeightWheelPicker(weight: $weight, unit: unitSystem)
                    Button("Update Weight") { saveWeight() }
                        .disabled(weight <= 0)
                }

                if !measurements.isEmpty {
                    NavigationLink("Weight history") {
                        BodyWeightHistoryList()
                    }
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

            DataAndPrivacySection(isConfirmingDeleteAll: $isConfirmingDeleteAll)
        }
        .navigationTitle("Settings")
        .onAppear {
            loadWeightFromLatestMeasurement()
            loadHeightFromProfile()
        }
        .onChange(of: unitSystem) { oldUnit, newUnit in
            convertWeightInput(from: oldUnit, to: newUnit)
            loadHeightFromProfile()
        }
        .sheet(isPresented: $isConfirmingDeleteAll) {
            ConfirmDestructiveSheet(
                title: "Delete all data?",
                message: "This removes workouts, plans, custom exercises, and body measurements from this iPhone. There is no account to restore from. Export a backup first if you want to keep a copy. This cannot be undone.",
                keepTitle: "Keep Data",
                deleteTitle: "Delete All Data",
                keepIdentifier: "keepAllData",
                deleteIdentifier: "confirmDeleteAllData",
                warningIdentifier: "deleteAllDataWarning",
                onKeep: { isConfirmingDeleteAll = false },
                onDelete: {
                    isConfirmingDeleteAll = false
                    do {
                        try BackupService.deleteAllData(in: modelContext)
                    } catch {
                        // Export errors are surfaced in the data section.
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .interactiveDismissDisabled()
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
            Text("Me")
                .font(GymTheme.navAction)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .accessibilityIdentifier("profileToolbar")
    }
}

private struct DataAndPrivacySection: View {
    @Binding var isConfirmingDeleteAll: Bool
    @Environment(\.modelContext) private var modelContext
    @State private var jsonURL: URL?
    @State private var csvURL: URL?
    @State private var exportErrorMessage: String?

    var body: some View {
        Section {
            if let jsonURL {
                ShareLink(item: jsonURL) {
                    Label("Export JSON backup", systemImage: "square.and.arrow.up")
                }
                .accessibilityIdentifier("exportJSONBackup")
            }
            if let csvURL {
                ShareLink(item: csvURL) {
                    Label("Export workouts CSV", systemImage: "tablecells")
                }
                .accessibilityIdentifier("exportWorkoutsCSV")
            }
            Button("Delete All Data", role: .destructive) {
                isConfirmingDeleteAll = true
            }
            .accessibilityIdentifier("deleteAllData")
        } header: {
            Text("Data & Privacy")
        } footer: {
            Text("There is no account or iCloud sync. Uninstalling or deleting all data removes every workout from this iPhone. Export a backup first if you want a copy.")
        }
        .onAppear(perform: prepareExport)
        .alert("Couldn’t export", isPresented: Binding(
            get: { exportErrorMessage != nil },
            set: { if !$0 { exportErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "Try again.")
        }
    }

    private func prepareExport() {
        do {
            let document = BackupService.makeDocument(in: modelContext)
            let files = try BackupService.writeExportFiles(from: document)
            jsonURL = files.json
            csvURL = files.csv
        } catch {
            exportErrorMessage = error.localizedDescription
        }
    }
}

