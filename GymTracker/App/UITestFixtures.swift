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
            return
        }

        if args.contains("-seedHistorySummaries") {
            ProfileService.skipOnboarding(in: context)
            seedHistorySummaries(in: context)
            try? context.save()
            return
        }

        if args.contains("-seedFinishableWorkout") {
            ProfileService.skipOnboarding(in: context)
            seedFinishableWorkout(in: context)
            try? context.save()
            return
        }

        if args.contains("-seedUnstartablePlans") {
            ProfileService.skipOnboarding(in: context)
            seedUnstartablePlans(in: context)
            try? context.save()
        }
    }

    private static func exerciseNamed(_ name: String, in context: ModelContext) -> Exercise? {
        ((try? context.fetch(FetchDescriptor<Exercise>())) ?? []).first { $0.name == name }
    }

    private static func seedFinishableWorkout(in context: ModelContext) {
        guard let bench = exerciseNamed("Barbell Bench Press", in: context) else { return }
        let session = WorkoutSessionService.startEmptySession(in: context)
        session.planName = "Push Day"
        let entry = WorkoutSessionService.addExercise(bench, to: session, in: context)
        entry.sets.first?.weight = 80
        entry.sets.first?.reps = 8
        entry.sets.first?.markCompleted()
    }

    private static func seedUnstartablePlans(in context: ModelContext) {
        context.insert(WorkoutPlan(name: "Empty Template"))

        let gone = Exercise(
            name: "Deleted Lift",
            muscleGroup: .chest,
            equipment: .barbell,
            isCustom: true
        )
        context.insert(gone)
        let broken = WorkoutPlan(name: "Broken Plan")
        context.insert(broken)
        let planned = PlannedExercise(exercise: gone, sortOrder: 0)
        planned.plan = broken
        context.delete(gone)
    }

    private static func seedHistorySummaries(in context: ModelContext) {
        guard
            let bench = exerciseNamed("Barbell Bench Press", in: context),
            let jumpRope = exerciseNamed("Jump Rope", in: context),
            let walk = exerciseNamed("Treadmill Walk", in: context)
        else { return }

        let strength = WorkoutSessionService.startEmptySession(in: context)
        strength.planName = "Push Day"
        strength.startedAt = Date().addingTimeInterval(-3600)
        let benchEntry = WorkoutSessionService.addExercise(bench, to: strength, in: context)
        for _ in 0..<2 { WorkoutSessionService.addSet(to: benchEntry) }
        for set in benchEntry.sets {
            set.weight = 80
            set.reps = 8
            set.markCompleted()
        }
        try? WorkoutSessionService.finish(strength, in: context)

        let timed = WorkoutSessionService.startEmptySession(in: context)
        timed.planName = "Boxing Conditioning"
        timed.startedAt = Date().addingTimeInterval(-7200)
        let rope = WorkoutSessionService.addExercise(jumpRope, to: timed, in: context)
        WorkoutSessionService.addSet(to: rope)
        for set in rope.sets {
            set.durationSeconds = 180
            set.markCompleted()
        }
        try? WorkoutSessionService.finish(timed, in: context)

        let cardio = WorkoutSessionService.startEmptySession(in: context)
        cardio.planName = "Incline Walk"
        cardio.startedAt = Date().addingTimeInterval(-10_800)
        let walkEntry = WorkoutSessionService.addExercise(walk, to: cardio, in: context)
        for set in walkEntry.sets {
            set.durationSeconds = 600
            set.distance = 1
            set.markCompleted()
        }
        try? WorkoutSessionService.finish(cardio, in: context)

        let mixed = WorkoutSessionService.startEmptySession(in: context)
        mixed.planName = "Mixed Day"
        mixed.startedAt = Date().addingTimeInterval(-14_400)
        let mixedBench = WorkoutSessionService.addExercise(bench, to: mixed, in: context)
        mixedBench.sets.first?.weight = 60
        mixedBench.sets.first?.reps = 5
        mixedBench.sets.first?.markCompleted()
        let mixedRope = WorkoutSessionService.addExercise(jumpRope, to: mixed, in: context)
        mixedRope.sets.first?.durationSeconds = 180
        mixedRope.sets.first?.markCompleted()
        let mixedWalk = WorkoutSessionService.addExercise(walk, to: mixed, in: context)
        mixedWalk.sets.first?.durationSeconds = 300
        mixedWalk.sets.first?.distance = 0.5
        mixedWalk.sets.first?.markCompleted()
        try? WorkoutSessionService.finish(mixed, in: context)
    }

    private static func intArgument(_ name: String, in args: [String]) -> Int? {
        guard let index = args.firstIndex(of: name), args.indices.contains(index + 1) else {
            return nil
        }
        return Int(args[index + 1])
    }
}
