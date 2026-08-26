import Foundation
import SwiftData

/// One row per install. Marks that first launch is done even if height and
/// weight were skipped. Height is stored in centimeters when provided.
/// Weight lives in `BodyMeasurement` so the Progress chart and Profile stay
/// in sync.
@Model
final class UserProfile {
    /// Nil until the user saves a height.
    var heightCentimeters: Double?
    var createdAt: Date
    var updatedAt: Date

    init(heightCentimeters: Double? = nil, createdAt: Date = .now) {
        self.heightCentimeters = heightCentimeters
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}
