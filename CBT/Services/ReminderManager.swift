import Foundation
import UserNotifications

#if canImport(UIKit)
import UIKit
#endif

struct ReminderManager {

    static let shared = ReminderManager()

    private let notificationCenter: UNUserNotificationCenter

    private init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    func getAuthorizationState() async -> PermissionManager.Status {
        await PermissionManager.shared.status(for: .notifications)
    }

    func requestAuthorization() async -> Bool {
        let status = await PermissionManager.shared.request(.notifications)
        return status == .authorized
    }

    func openSystemNotificationSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        Task { @MainActor in
            guard UIApplication.shared.canOpenURL(url) else {
                return
            }
            UIApplication.shared.open(url)
        }
        #endif
    }

    func scheduleDaily(identifier: String, title: String, body: String, hour: Int, minute: Int) async throws {
        cancelPendingAndDelivered(identifier: identifier)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            notificationCenter.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func cancel(_ identifier: String) async {
        cancelPendingAndDelivered(identifier: identifier)
    }

    func cancelAllCBTReminders() async {
        let identifiers = ["daily_mood_reminder", "daily_reflection_reminder"]
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
        ContextualNotificationService.shared.cancelAllContextualNotifications()
        DailyReminderService.shared.cancelAllDailyReminders()
    }

    private func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            notificationCenter.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private func cancelPendingAndDelivered(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}
