import Foundation
import SwiftData

/// What Finish will persist versus drop. Failed sets are a subset of completed.
struct WorkoutFinishPreview: Equatable {
    let completedCount: Int
    let failedCount: Int
    let skippedCount: Int
    let incompleteCount: Int

    var canSave: Bool { completedCount > 0 }
}

struct SavedWorkoutNotice: Identifiable {
    let id = UUID()
    let session: WorkoutSession
    let preview: WorkoutFinishPreview
    let planName: String?
    let duration: TimeInterval
}
