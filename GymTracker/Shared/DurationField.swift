import SwiftUI

/// Minutes + seconds text fields bound to one seconds value, used wherever
/// a duration metric is edited (set rows, plan targets).
struct DurationField: View {
    @Binding var seconds: Int

    private var minutesPart: Binding<Int> {
        Binding(
            get: { seconds / 60 },
            set: { seconds = max(0, $0) * 60 + seconds % 60 }
        )
    }

    private var secondsPart: Binding<Int> {
        Binding(
            get: { seconds % 60 },
            set: { seconds = (seconds / 60) * 60 + $0.clamped(to: 0...59) }
        )
    }

    var body: some View {
        HStack(spacing: 6) {
            TextField("Min", value: minutesPart, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
            Text("min")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField("Sec", value: secondsPart, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 40)
            Text("sec")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
