import Charts
import SwiftData
import SwiftUI

/// Body weight trend chart plus entry management, embedded in the
/// Progress tab.
struct BodyWeightView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.weightUnit) private var weightUnit: WeightUnit = .kilograms

    @Query(sort: \BodyMeasurement.date) private var measurements: [BodyMeasurement]

    @State private var isAddingEntry = false

    var body: some View {
        if measurements.count >= 2 {
            Chart(measurements) { measurement in
                LineMark(
                    x: .value("Date", measurement.date),
                    y: .value("Weight", measurement.weight)
                )
                .symbol(.circle)
                .foregroundStyle(.green)
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxisLabel(weightUnit.rawValue)
            .frame(height: 160)
            .padding(.vertical, 8)
        }

        if let latest = measurements.last {
            LabeledContent("Latest") {
                Text(Formatters.weight(latest.weight, unit: weightUnit))
                + Text("  ·  ").foregroundStyle(.secondary)
                + Text(latest.date, format: .dateTime.day().month())
            }
        }

        Button {
            isAddingEntry = true
        } label: {
            Label("Log Body Weight", systemImage: "plus")
        }
        .sheet(isPresented: $isAddingEntry) {
            BodyWeightEntrySheet()
        }

        if !measurements.isEmpty {
            NavigationLink("All entries") {
                BodyWeightHistoryList()
            }
        }
    }
}

private struct BodyWeightEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKeys.weightUnit) private var weightUnit: WeightUnit = .kilograms

    @State private var date: Date = .now
    @State private var weight: Double?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $date, displayedComponents: .date)
                HStack {
                    TextField("Weight", value: $weight, format: .number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                    Text(weightUnit.rawValue)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Log Body Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled((weight ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let weight, weight > 0 else { return }
        ProfileService.upsertWeight(weight, on: date, in: modelContext)
        dismiss()
    }
}

struct BodyWeightHistoryList: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKeys.weightUnit) private var weightUnit: WeightUnit = .kilograms

    @Query(sort: \BodyMeasurement.date, order: .reverse)
    private var measurements: [BodyMeasurement]

    var body: some View {
        List {
            ForEach(measurements) { measurement in
                LabeledContent {
                    Text(Formatters.weight(measurement.weight, unit: weightUnit))
                } label: {
                    Text(measurement.date, format: .dateTime.day().month().year())
                }
            }
            .onDelete { offsets in
                for index in offsets {
                    modelContext.delete(measurements[index])
                }
            }
        }
        .navigationTitle("Body Weight")
        .navigationBarTitleDisplayMode(.inline)
    }
}
