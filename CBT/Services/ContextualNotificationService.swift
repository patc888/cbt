import Foundation
import UserNotifications

extension Notification.Name {
    static let contextualNotificationDeepLinkReceived = Notification.Name("contextualNotificationDeepLinkReceived")
}

enum LifeEvent: String, CaseIterable, Identifiable {
    case beforeWork
    case duringCommute
    case beforeBed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beforeWork:
            return String(localized: "Before Work")
        case .duringCommute:
            return String(localized: "During Commute")
        case .beforeBed:
            return String(localized: "Before Bed")
        }
    }
}

enum ContextualNotificationDeepLink: String, Identifiable {
    case breathing
    case journal
    case affirmation
    case morningIntentions
    case eveningReflection

    var id: String { rawValue }

    var url: URL {
        var components = URLComponents()
        components.scheme = "cbt"
        components.host = rawValue
        return components.url ?? URL(fileURLWithPath: rawValue)
    }

    init?(url: URL) {
        guard url.scheme == "cbt" else { return nil }

        let route = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.init(rawValue: route)
    }
}

struct NotificationTemplate: Identifiable {
    let id: String
    let lifeEvent: LifeEvent
    let title: String
    let body: String
    let trigger: UNNotificationTrigger
    let deepLink: ContextualNotificationDeepLink

    static let notificationKindUserInfoKey = "cbt_notification_kind"
    static let deepLinkUserInfoKey = "cbt_deep_link"
    static let lifeEventUserInfoKey = "cbt_life_event"
    static let contextualNotificationKind = "contextual"
}

final class ContextualNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ContextualNotificationService()

    private let notificationCenter: UNUserNotificationCenter

    private override init() {
        self.notificationCenter = .current()
        super.init()
    }

    init(notificationCenter: UNUserNotificationCenter) {
        self.notificationCenter = notificationCenter
        super.init()
    }

    func configureAsNotificationDelegate() {
        notificationCenter.delegate = self
    }

    var defaultTemplates: [NotificationTemplate] {
        [
            NotificationTemplate(
                id: identifier(for: .beforeWork),
                lifeEvent: .beforeWork,
                title: String(localized: "Take one steady minute"),
                body: String(localized: "A short breathing reset can help you start work grounded."),
                trigger: dailyTrigger(hour: 8, minute: 30),
                deepLink: .breathing
            ),
            NotificationTemplate(
                id: identifier(for: .duringCommute),
                lifeEvent: .duringCommute,
                title: String(localized: "A calm thought for the road"),
                body: String(localized: "Open an affirmation for a quick mental reset."),
                trigger: dailyTrigger(hour: 17, minute: 30),
                deepLink: .affirmation
            ),
            NotificationTemplate(
                id: identifier(for: .beforeBed),
                lifeEvent: .beforeBed,
                title: String(localized: "Close the day gently"),
                body: String(localized: "Capture a quick reflection before bed."),
                trigger: dailyTrigger(hour: 21, minute: 30),
                deepLink: .journal
            )
        ]
    }

    func template(for lifeEvent: LifeEvent) -> NotificationTemplate? {
        defaultTemplates.first { $0.lifeEvent == lifeEvent }
    }

    func schedule(_ template: NotificationTemplate) async throws {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [template.id])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [template.id])

        let content = UNMutableNotificationContent()
        content.title = template.title
        content.body = template.body
        content.sound = .default
        content.userInfo = [
            NotificationTemplate.notificationKindUserInfoKey: NotificationTemplate.contextualNotificationKind,
            NotificationTemplate.deepLinkUserInfoKey: template.deepLink.url.absoluteString,
            NotificationTemplate.lifeEventUserInfoKey: template.lifeEvent.rawValue
        ]

        let request = UNNotificationRequest(
            identifier: template.id,
            content: content,
            trigger: template.trigger
        )

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

    func cancel(lifeEvent: LifeEvent) {
        cancel(identifier: identifier(for: lifeEvent))
    }

    func cancelAllContextualNotifications() {
        let identifiers = LifeEvent.allCases.map(identifier(for:))
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    func notificationDeepLink(from userInfo: [AnyHashable: Any]) -> ContextualNotificationDeepLink? {
        guard userInfo[NotificationTemplate.notificationKindUserInfoKey] as? String == NotificationTemplate.contextualNotificationKind,
              let deepLinkString = userInfo[NotificationTemplate.deepLinkUserInfoKey] as? String,
              let url = URL(string: deepLinkString)
        else {
            return nil
        }

        return ContextualNotificationDeepLink(url: url)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let deepLink = notificationDeepLink(from: userInfo) ?? DailyReminderService.shared.notificationDeepLink(from: userInfo) {
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .contextualNotificationDeepLinkReceived,
                    object: deepLink
                )
            }
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func cancel(identifier: String) {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    private func identifier(for lifeEvent: LifeEvent) -> String {
        "contextual_\(lifeEvent.rawValue)_notification"
    }

    private func dailyTrigger(hour: Int, minute: Int) -> UNNotificationTrigger {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
    }
}
