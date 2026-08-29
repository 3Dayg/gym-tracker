import Foundation
import Observation
import SwiftUI

/// In-memory 3-2-1 before a timed Start. Not persisted — killing the app
/// during prep returns to idle Start.
@Observable
@MainActor
final class WorkPrepCountdown {
    private(set) var remaining: Int?
    private var task: Task<Void, Never>?
    private let stepNanoseconds: UInt64

    var isActive: Bool { remaining != nil }

    init(stepNanoseconds: UInt64 = 1_000_000_000) {
        self.stepNanoseconds = stepNanoseconds
    }

    func start(perform: @escaping () -> Void) {
        cancel()
        remaining = 3
        task = Task { @MainActor in
            for value in [3, 2, 1] {
                remaining = value
                try? await Task.sleep(nanoseconds: self.stepNanoseconds)
                if Task.isCancelled { return }
            }
            remaining = nil
            task = nil
            perform()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        remaining = nil
    }
}

struct WorkPrepCountdownLabel: View {
    let remaining: Int
    var font: Font = GymTheme.countdown

    var body: some View {
        Text("\(remaining)")
            .font(font)
            .monospacedDigit()
            .accessibilityIdentifier("workPrepCountdown")
            .accessibilityLabel("Starting in \(remaining)")
            .accessibilityAddTraits(.updatesFrequently)
    }
}
