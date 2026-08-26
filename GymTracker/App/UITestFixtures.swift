import Foundation
import SwiftData

/// Launch-argument fixtures for UI tests. Only runs with `-inMemoryStore`.
enum UITestFixtures {
    static func seedIfNeeded(in context: ModelContext) {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-inMemoryStore") else { return }

        if args.contains("-seedStaleWorkout") {
            ProfileService.skipOnboarding(in: context)
            let session = WorkoutSession(
                startedAt: Date().addingTimeInterval(-25 * 60 * 60),
                planName: "Push Day"
            )
            context.insert(session)
            try? context.save()
            return
        }

        if let seconds = intArgument("-restoreRest", in: args), seconds > 0 {
            ProfileService.skipOnboarding(in: context)
            let session = WorkoutSession(planName: "Boxing Conditioning")
            context.insert(session)
            session.liveTimer = LiveTimerState(
                phase: .rest,
                endAt: Date().addingTimeInterval(TimeInterval(seconds)),
                totalSeconds: max(seconds, 60),
                remainingSeconds: seconds,
                followOnRestSeconds: 0
            )
            try? context.save()
            return
        }

        if args.contains("-restoreExpiredRest") {
            ProfileService.skipOnboarding(in: context)
            let session = WorkoutSession(planName: "Boxing Conditioning")
            context.insert(session)
            session.liveTimer = LiveTimerState(
                phase: .rest,
                endAt: Date().addingTimeInterval(-5),
                totalSeconds: 60,
                remainingSeconds: 0,
                followOnRestSeconds: 0
            )
            try? context.save()
        }
    }

    private static func intArgument(_ name: String, in args: [String]) -> Int? {
        guard let index = args.firstIndex(of: name), args.indices.contains(index + 1) else {
            return nil
        }
        return Int(args[index + 1])
    }
}
