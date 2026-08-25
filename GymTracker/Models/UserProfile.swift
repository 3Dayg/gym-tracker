import Foundation
import SwiftData

/// One row per install. Height is stored in centimeters so calorie
/// formulas later have a single unit. Weight lives in `BodyMeasurement`
/// so the Progress chart and the profile stay in sync.
@Model
final class UserProfile {
    var heightCentimeters: Double
    var createdAt: Date
    var updatedAt: Date

    init(heightCentimeters: Double, createdAt: Date = .now) {
        self.heightCentimeters = heightCentimeters
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
