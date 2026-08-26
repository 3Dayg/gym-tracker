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

    private var endDate: Date?
    private var tickTask: Task<Void, Never>?

    private static let workNotificationID = "workTimerFinished"
    private static let restNotificationID = "restTimerFinished"

    var isActive: Bool { phase != .idle }

    func isTiming(_ set: SetEntry) -> Bool {
        phase == .work && activeSet === set
    }

    func startWork(seconds: Int, set: SetEntry) {
        guard seconds > 0, set.isPending else { return }
        begin(phase: .work, seconds: seconds, set: set)
        scheduleNotification(
            identifier: Self.workNotificationID,
            after: seconds,
            title: "Round over",
            body: "Time to rest."
        )
    }

    func startRest(seconds: Int) {
        guard seconds > 0 else { return }
        begin(phase: .rest, seconds: seconds, set: nil)
        scheduleNotification(
            identifier: Self.restNotificationID,
            after: seconds,
            title: "Rest over",
            body: "Time for your next set."
        )
    }

    func pause() {
        guard phase == .work, !isPaused else { return }
        updateRemaining()
        isPaused = true
        endDate = nil
        tickTask?.cancel()
        tickTask = nil
        cancelNotification(Self.workNotificationID)
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
    }

    func stop() {
        cancelTicksAndNotifications()
        phase = .idle
        isPaused = false
        endDate = nil
        remainingSeconds = 0
        totalSeconds = 0
        activeSet = nil
    }

    /// Catch up after the app was locked or backgrounded. The tick loop
    /// may not have run, but `endDate` is wall-clock so remaining time
    /// is still correct.
    func refresh() {
        updateRemaining()
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
        tickTask = Task { [weak self] in
            while let self, self.phase != .idle, !self.isPaused, !Task.isCancelled {
                self.updateRemaining()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
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
        stop()
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
