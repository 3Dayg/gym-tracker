import SwiftUI

/// Bindings that expose canonical metric model values (kg, km/h, km) in
/// the user's display unit, shared by the workout and plan editors.
extension UnitSystem {
    func weightBinding(_ kilograms: Binding<Double?>) -> Binding<Double?> {
        Binding(
            get: {
                kilograms.wrappedValue.map {
                    displayWeight(fromKilograms: $0).rounded(toDecimalPlaces: 1)
                }
            },
            set: { kilograms.wrappedValue = $0.map { self.kilograms(fromDisplayWeight: $0) } }
        )
    }

    func weightBinding(_ kilograms: Binding<Double>) -> Binding<Double?> {
        weightBinding(Binding(
            get: { Optional(kilograms.wrappedValue) },
            set: { kilograms.wrappedValue = $0 ?? 0 }
        ))
    }

    func speedBinding(_ kilometersPerHour: Binding<Double?>) -> Binding<Double?> {
        Binding(
            get: {
                kilometersPerHour.wrappedValue.map {
                    displaySpeed(fromKilometersPerHour: $0).rounded(toDecimalPlaces: 2)
                }
            },
            set: { kilometersPerHour.wrappedValue = $0.map { self.kilometersPerHour(fromDisplaySpeed: $0) } }
        )
    }

    func speedBinding(_ kilometersPerHour: Binding<Double>) -> Binding<Double?> {
        speedBinding(Binding(
            get: { Optional(kilometersPerHour.wrappedValue) },
            set: { kilometersPerHour.wrappedValue = $0 ?? 0 }
        ))
    }

    func distanceBinding(_ kilometers: Binding<Double?>) -> Binding<Double?> {
        Binding(
            get: {
                kilometers.wrappedValue.map {
                    displayDistance(fromKilometers: $0).rounded(toDecimalPlaces: 2)
                }
            },
            set: { kilometers.wrappedValue = $0.map { self.kilometers(fromDisplayDistance: $0) } }
        )
    }
}

/// Wheel options per metric, shared by the workout and plan editors.
/// Values are built from integer grids so wheel tags compare reliably.
extension SetMetric {
    var wheelValues: [Double] {
        switch self {
        case .weight: (0...1000).map { Double($0) / 2 }        // 0–500, step 0.5
        case .reps: (1...100).map(Double.init)                 // 1–100
        case .speed, .incline, .distance: []                   // free numeric keyboard input
        case .duration: []                                     // uses DurationPickerSheet
        }
    }
}

/// Bottom-sheet wheel picker for one numeric value. The wheel edits a local
/// copy and commits on Done; an optional clear action writes nil instead
/// (used by optional plan targets such as "last used" weight).
struct NumberPickerSheet: View {
    let title: String
    let unit: String
    let values: [Double]
    @Binding var value: Double?
    let clearLabel: String?

    @State private var selection: Double
    @Environment(\.dismiss) private var dismiss

    init(
        title: String,
        unit: String,
        values: [Double],
        value: Binding<Double?>,
        initialValue: Double? = nil,
        clearLabel: String? = nil
    ) {
        self.title = title
        self.unit = unit
        self.values = values
        self._value = value
        self.clearLabel = clearLabel
        let target = value.wrappedValue ?? initialValue ?? values.first ?? 0
        let nearest = values.min { abs($0 - target) < abs($1 - target) } ?? 0
        self._selection = State(initialValue: nearest)
    }

    var body: some View {
        NavigationStack {
            Picker(title, selection: $selection) {
                ForEach(values, id: \.self) { option in
                    Text("\(format(option)) \(unit)").tag(option)
                }
            }
            .pickerStyle(.wheel)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let clearLabel {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(clearLabel) {
                            value = nil
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        value = selection
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }

    private func format(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }
}

/// Bottom-sheet minutes + seconds wheels bound to one seconds value.
/// Commits on Done.
struct DurationPickerSheet: View {
    let title: String
    @Binding var seconds: Int

    @State private var minutesPart: Int
    @State private var secondsPart: Int
    @Environment(\.dismiss) private var dismiss

    init(title: String = "Time", seconds: Binding<Int>) {
        self.title = title
        self._seconds = seconds
        self._minutesPart = State(initialValue: seconds.wrappedValue / 60)
        self._secondsPart = State(initialValue: seconds.wrappedValue % 60)
    }

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                Picker("Minutes", selection: $minutesPart) {
                    ForEach(0..<181, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                Text("min")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Seconds", selection: $secondsPart) {
                    ForEach(0..<60, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.wheel)
                Text("sec")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        seconds = minutesPart * 60 + secondsPart
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.height(300)])
    }
}
