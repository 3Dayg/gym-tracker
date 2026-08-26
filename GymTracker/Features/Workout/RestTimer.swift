import Foundation
import Observation
import UserNotifications

enum SessionTimerPhase: Equatable {
    case idle
    case work
    case rest
}

/// Work-round and rest countdown. Uses a wall-clock end date so remaining
/// time stays correct while the phone is locked or the app is backgrounded.
/// The snapshot is persisted on the session so a kill/relaunch can restore it.
@Observable
@MainActor
final class SessionTimer {
    private(set) var phase: SessionTimerPhase = .idle
    private(set) var isPaused = false
    private(set) var totalSeconds = 0
    private(set) var remainingSeconds = 0
    private(set) weak var activeSet: SetEntry?

    /// Called when a work round reaches zero. Rest is started by the view.
    var onWorkFinished: ((SetEntry) -> Void)?
    /// Called after any state change so the session can persist a snapshot.
    var onPersist: (() -> Void)?

    private var endDate: Date?
    private var tickTask: Task<Void, Never>?
    private var followOnRestSeconds = 0

    private static let workNotificationID = "workTimerFinished"
    private static let restNotificationID = "restTimerFinished"

    var isActive: Bool { phase != .idle }

    func isTiming(_ set: SetEntry) -> Bool {
        phase == .work && activeSet === set
    }

    func startWork(seconds: Int, set: SetEntry, followOnRestSeconds: Int = 0) {
        guard seconds > 0, set.isPending else { return }
        self.followOnRestSeconds = followOnRestSeconds
        begin(phase: .work, seconds: seconds, set: set)
        scheduleNotification(
            identifier: Self.workNotificationID,
            after: seconds,
            title: "Round over",
            body: "Time to rest."
        )
        onPersist?()
    }

    func startRest(seconds: Int) {
        guard seconds > 0 else { return }
        followOnRestSeconds = 0
        begin(phase: .rest, seconds: seconds, set: nil)
        scheduleNotification(
            identifier: Self.restNotificationID,
            after: seconds,
            title: "Rest over",
            body: "Time for your next set."
        )
        onPersist?()
    }

    func pause() {
        guard phase == .work, !isPaused else { return }
        updateRemaining()
        isPaused = true
        endDate = nil
        tickTask?.cancel()
        tickTask = nil
        cancelNotification(Self.workNotificationID)
        onPersist?()
    }

    func resume() {
        guard phase == .work, isPaused, remainingSeconds > 0, let set = activeSet else { return }
        let remaining = remainingSeconds
        let total = totalSeconds
        isPaused = false
        begin(phase: .work, seconds: remaining, set: set, totalSeconds: total)
        scheduleNotification(
            identifier: Self.workNotificationID,
            after: remaining,
            title: "Round over",
            body: "Time to rest."
        )
        onPersist?()
    }

    func stop() {
        resetToIdle()
        onPersist?()
    }

    /// Catch up after the app was locked or backgrounded. The tick loop
    /// may not have run, but `endDate` is wall-clock so remaining time
    /// is still correct.
    func refresh() {
        updateRemaining()
    }

    func makeSnapshot() -> LiveTimerState? {
        switch phase {
        case .idle:
            return nil
        case .work:
            return LiveTimerState(
                phase: isPaused ? .pausedWork : .work,
                endAt: isPaused ? nil : endDate,
                totalSeconds: totalSeconds,
                remainingSeconds: remainingSeconds,
                exerciseSortOrder: activeSet?.sessionExercise?.sortOrder,
                setSortOrder: activeSet?.sortOrder,
                followOnRestSeconds: followOnRestSeconds
            )
        case .rest:
            return LiveTimerState(
                phase: .rest,
                endAt: endDate,
                totalSeconds: totalSeconds,
                remainingSeconds: remainingSeconds,
                exerciseSortOrder: nil,
                setSortOrder: nil,
                followOnRestSeconds: 0
            )
        }
    }

    func apply(
        _ action: LiveTimerRestoreAction,
        setLookup: (Int, Int) -> SetEntry?
    ) {
        switch action {
        case .idle:
            resetToIdle()

        case .completeSetAndIdle(let exercise, let set):
            setLookup(exercise, set)?.markCompleted()
            resetToIdle()

        case .work(let endAt, let total, let exercise, let set, let followOnRest):
            guard let set = setLookup(exercise, set), set.isPending else {
                resetToIdle()
                return
            }
            followOnRestSeconds = followOnRest
            restoreRunning(phase: .work, endAt: endAt, total: total, set: set)
            scheduleNotification(
                identifier: Self.workNotificationID,
                after: remainingSeconds,
                title: "Round over",
                body: "Time to rest."
            )

        case .pausedWork(let remaining, let total, let exercise, let set, let followOnRest):
            guard let set = setLookup(exercise, set), set.isPending, remaining > 0 else {
                resetToIdle()
                return
            }
            cancelTicksAndNotifications()
            phase = .work
            isPaused = true
            totalSeconds = total
            remainingSeconds = remaining
            endDate = nil
            activeSet = set
            followOnRestSeconds = followOnRest

        case .rest(let endAt, let total, let completeExercise, let completeSet):
            if let completeExercise, let completeSet {
                setLookup(completeExercise, completeSet)?.markCompleted()
            }
            restoreRunning(phase: .rest, endAt: endAt, total: total, set: nil)
            scheduleNotification(
                identifier: Self.restNotificationID,
                after: remainingSeconds,
                title: "Rest over",
                body: "Time for your next set."
            )
        }
        onPersist?()
    }

    private func begin(
        phase: SessionTimerPhase,
        seconds: Int,
        set: SetEntry?,
        totalSeconds: Int? = nil
    ) {
        cancelTicksAndNotifications()
        self.phase = phase
        isPaused = false
        self.totalSeconds = totalSeconds ?? seconds
        remainingSeconds = seconds
        activeSet = set
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
        startTickLoop()
    }

    private func restoreRunning(
        phase: SessionTimerPhase,
        endAt: Date,
        total: Int,
        set: SetEntry?
    ) {
        cancelTicksAndNotifications()
        self.phase = phase
        isPaused = false
        totalSeconds = total
        activeSet = set
        endDate = endAt
        remainingSeconds = max(0, Int(endAt.timeIntervalSinceNow.rounded(.up)))
        startTickLoop()
    }

    private func startTickLoop() {
        tickTask = Task { [weak self] in
            while let self, self.phase != .idle, !self.isPaused, !Task.isCancelled {
                self.updateRemaining()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    private func resetToIdle() {
        cancelTicksAndNotifications()
        phase = .idle
        isPaused = false
        endDate = nil
        remainingSeconds = 0
        totalSeconds = 0
        activeSet = nil
        followOnRestSeconds = 0
    }

    private func cancelTicksAndNotifications() {
        tickTask?.cancel()
        tickTask = nil
        cancelNotification(Self.workNotificationID)
        cancelNotification(Self.restNotificationID)
    }

    private func updateRemaining() {
        guard let endDate, !isPaused else { return }
        let remaining = Int(endDate.timeIntervalSinceNow.rounded(.up))
        remainingSeconds = max(0, remaining)
        if remaining <= 0 {
            finishNaturally()
        }
    }

    private func finishNaturally() {
        let finishedPhase = phase
        let finishedSet = activeSet
        resetToIdle()
        onPersist?()
        if finishedPhase == .work, let finishedSet {
            onWorkFinished?(finishedSet)
        }
    }

    private func scheduleNotification(
        identifier: String,
        after seconds: Int,
        title: String,
        body: String
    ) {
        let interval = max(1, seconds)
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(interval),
                repeats: false
            )
            center.add(
                UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            )
        }
    }

    private func cancelNotification(_ identifier: String) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
