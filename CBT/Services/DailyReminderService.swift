import Foundation
import UserNotifications

enum DailyCheckInKind: String, CaseIterable, Identifiable {
    case morningIntentions
    case eveningReflection

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morningIntentions:
            return String(localized: "Morning Intentions")
        case .eveningReflection:
            return String(localized: "Evening Reflection")
        }
    }

    var notificationBody: String {
        switch self {
        case .morningIntentions:
            return String(localized: "Choose one grounded intention for the day before everything gets moving.")
        case .eveningReflection:
            return String(localized: "Close the day with a short guided reflection on what happened, what mattered, and what can rest.")
        }
    }

    var defaultHour: Int {
        switch self {
        case .morningIntentions:
            return 8
        case .eveningReflection:
            return 20
        }
    }

    var defaultMinute: Int {
        switch self {
        case .morningIntentions:
            return 0
        case .eveningReflection:
            return 30
        }
    }

    var deepLink: ContextualNotificationDeepLink {
        switch self {
        case .morningIntentions:
            return .morningIntentions
        case .eveningReflection:
            return .eveningReflection
        }
    }
}

nonisolated struct QuoteOfTheDayNotification {
    static let identifierPrefix = "daily_quote_of_the_day"
    static let defaultHour = 9
    static let defaultMinute = 0

    let identifier: String
    let affirmation: Affirmation
    let date: Date

    var title: String {
        String(localized: "Quote of the Day")
    }

    var body: String {
        affirmation.text
    }

    static func notification(for date: Date, affirmations: [Affirmation]) -> QuoteOfTheDayNotification? {
        guard !affirmations.isEmpty else { return nil }

        let day = Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
        let affirmation = affirmations[abs(day) % affirmations.count]

        return QuoteOfTheDayNotification(
            identifier: "\(identifierPrefix)_\(Self.identifierDateFormatter.string(from: date))",
            affirmation: affirmation,
            date: date
        )
    }

    private static let identifierDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

final class DailyReminderService {
    static let shared = DailyReminderService()

    static let notificationKindUserInfoKey = "cbt_daily_notification_kind"
    static let deepLinkUserInfoKey = "cbt_daily_deep_link"
    static let checkInKindUserInfoKey = "cbt_daily_check_in_kind"
    static let dailyNotificationKind = "daily_loop"
    static let quoteNotificationKind = "quote_of_the_day"

    private let notificationCenter: UNUserNotificationCenter
    private let quoteScheduleWindowDays = 30

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    func schedule(_ kind: DailyCheckInKind, hour: Int? = nil, minute: Int? = nil) async throws {
        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = kind.notificationBody
        content.sound = .default
        content.userInfo = [
            Self.notificationKindUserInfoKey: Self.dailyNotificationKind,
            Self.deepLinkUserInfoKey: kind.deepLink.url.absoluteString,
            Self.checkInKindUserInfoKey: kind.rawValue
        ]

        var components = DateComponents()
        components.hour = hour ?? kind.defaultHour
        components.minute = minute ?? kind.defaultMinute

        let request = UNNotificationRequest(
            identifier: identifier(for: kind),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        cancel(kind)
        try await add(request)
    }

    func scheduleDailyLoop(morningHour: Int, morningMinute: Int, eveningHour: Int, eveningMinute: Int) async throws {
        try await schedule(.morningIntentions, hour: morningHour, minute: morningMinute)
        try await schedule(.eveningReflection, hour: eveningHour, minute: eveningMinute)
    }

    func scheduleQuoteOfTheDay(hour: Int = QuoteOfTheDayNotification.defaultHour, minute: Int = QuoteOfTheDayNotification.defaultMinute) async throws {
        await cancelPendingQuoteOfTheDayRequests()

        let affirmations = AffirmationsLoader.shared.affirmations
        guard !affirmations.isEmpty else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let now = Date()

        for offset in 0..<quoteScheduleWindowDays {
            guard
                let day = calendar.date(byAdding: .day, value: offset, to: today),
                let quote = QuoteOfTheDayNotification.notification(for: day, affirmations: affirmations)
            else {
                continue
            }

            var components = calendar.dateComponents([.year, .month, .day], from: quote.date)
            components.hour = hour
            components.minute = minute
            guard let fireDate = calendar.date(from: components), fireDate > now else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = quote.title
            content.body = quote.body
            content.sound = .default
            content.userInfo = [
                Self.notificationKindUserInfoKey: Self.quoteNotificationKind,
                Self.deepLinkUserInfoKey: ContextualNotificationDeepLink.affirmation.url.absoluteString
            ]

            try await add(UNNotificationRequest(
                identifier: quote.identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            ))
        }
    }

    func refreshQuoteOfTheDayIfEnabled() async {
        guard UserDefaults.standard.bool(forKey: "cbt_quoteOfTheDayEnabled") else { return }
        try? await scheduleQuoteOfTheDay()
    }

    func cancel(_ kind: DailyCheckInKind) {
        let id = identifier(for: kind)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [id])
    }

    func cancelQuoteOfTheDay() {
        notificationCenter.getPendingNotificationRequests { [notificationCenter] requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(QuoteOfTheDayNotification.identifierPrefix) }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
            notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    func cancelAllDailyReminders() {
        DailyCheckInKind.allCases.forEach(cancel)
        cancelQuoteOfTheDay()
    }

    func notificationDeepLink(from userInfo: [AnyHashable: Any]) -> ContextualNotificationDeepLink? {
        guard
            userInfo[Self.notificationKindUserInfoKey] as? String != nil,
            let deepLinkString = userInfo[Self.deepLinkUserInfoKey] as? String,
            let url = URL(string: deepLinkString)
        else {
            return nil
        }

        return ContextualNotificationDeepLink(url: url)
    }

    private func identifier(for kind: DailyCheckInKind) -> String {
        "daily_\(kind.rawValue)_reminder"
    }

    private func cancelPendingQuoteOfTheDayRequests() async {
        let requests = await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }

        let identifiers = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(QuoteOfTheDayNotification.identifierPrefix) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func add(_ request: UNNotificationRequest) async throws {
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
}
