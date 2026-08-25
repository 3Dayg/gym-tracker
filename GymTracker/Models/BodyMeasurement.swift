import Foundation
import SwiftData

@Model
final class BodyMeasurement {
    var date: Date
    var weight: Double

    init(date: Date = .now, weight: Double) {
        self.date = date
        self.weight = weight
    }
}
