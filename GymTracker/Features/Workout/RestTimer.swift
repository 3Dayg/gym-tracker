import Foundation
import Observation
import UserNotifications

/// Countdown timer between sets. Tracks a wall-clock end date so the
/// remaining time stays correct if the app is backgrounded, and schedules
/// a local notification so the user is alerted even with the app closed.
@Observable
@MainActor
final class RestTimer {
    private(set) var isRunning = false
    private(set) var totalSeconds = 0
    private(set) var remainingSeconds = 0

    private var endDate: Date?
    private var tickTask: Task<Void, Never>?

    private static let notificationIdentifier = "restTimerFinished"

    func start(seconds: Int) {
        stop()
        totalSeconds = seconds
        remainingSeconds = seconds
        endDate = Date().addingTimeInterval(TimeInterval(seconds))
        isRunning = true

        scheduleNotification(after: seconds)
        tickTask = Task { [weak self] in
            while let self, self.isRunning, !Task.isCancelled {
                self.updateRemaining()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    func stop() {
        isRunning = false
        endDate = nil
        tickTask?.cancel()
        tickTask = nil
        cancelNotification()
    }

    private func updateRemaining() {
        guard let endDate else { return }
        let remaining = Int(endDate.timeIntervalSinceNow.rounded(.up))
        remainingSeconds = max(0, remaining)
        if remaining <= 0 {
            stop()
        }
    }

    private func scheduleNotification(after seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "Rest over"
            content.body = "Time for your next set."
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(seconds),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: Self.notificationIdentifier,
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationIdentifier])
    }
}
