import SwiftUI

/// Wheel input for height, matching the selected unit system:
/// a single 0–250 cm wheel, or feet + inches wheels.
struct HeightWheelPicker: View {
    let unit: UnitSystem
    @Binding var centimeters: Int
    @Binding var feet: Int
    @Binding var inches: Int

    var body: some View {
        switch unit {
        case .metric:
            Picker("Height", selection: $centimeters) {
                ForEach(0...250, id: \.self) { value in
                    Text("\(value) cm").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 120)
        case .imperial:
            HStack(spacing: 0) {
                Picker("Feet", selection: $feet) {
                    ForEach(0...8, id: \.self) { value in
                        Text("\(value) ft").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()

                Picker("Inches", selection: $inches) {
                    ForEach(0...11, id: \.self) { value in
                        Text("\(value) in").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .frame(height: 120)
        }
    }
}

/// Weight input as two wheels: whole units and tenths, e.g. 72 | .5, with
/// the unit label alongside.
/// The bound weight is in the display unit; callers convert to and from
/// canonical kilograms.
struct WeightWheelPicker: View {
    @Binding var weight: Double
    let unit: UnitSystem

    private var wholePart: Binding<Int> {
        Binding(
            get: { Int(weight) },
            set: { weight = Double($0) + Double(tenths) / 10 }
        )
    }

    private var tenthsPart: Binding<Int> {
        Binding(
            get: { tenths },
            set: { weight = Double(Int(weight)) + Double($0) / 10 }
        )
    }

    private var tenths: Int {
        Int((weight * 10).rounded()) % 10
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Weight", selection: wholePart) {
                ForEach(0...500, id: \.self) { value in
                    Text("\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("Decimals", selection: tenthsPart) {
                ForEach(0...9, id: \.self) { value in
                    Text(".\(value)").tag(value)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 70)
            .clipped()

            Text(unit.weightLabel)
                .foregroundStyle(.secondary)
                .frame(width: 40)
        }
        .frame(height: 120)
    }
}
