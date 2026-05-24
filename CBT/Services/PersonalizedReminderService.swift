import Foundation
import SwiftData
import UserNotifications

enum PersonalizedReminderType: String, CaseIterable, Identifiable {
    case dailyMoodCheckIn
    case eveningReflection
    case weeklyReport
    case breathingReset
    case plannedActivity
    case courseContinuation
    case sleepWindDown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dailyMoodCheckIn:
            return String(localized: "Daily Mood Check-In")
        case .eveningReflection:
            return String(localized: "Evening Reflection")
        case .weeklyReport:
            return String(localized: "Weekly Report")
        case .breathingReset:
            return String(localized: "Breathing Reset")
        case .plannedActivity:
            return String(localized: "Planned Activity")
        case .courseContinuation:
            return String(localized: "Course Continuation")
        case .sleepWindDown:
            return String(localized: "Sleep Wind-Down")
        }
    }

    var icon: String {
        switch self {
        case .dailyMoodCheckIn:
            return "face.smiling"
        case .eveningReflection:
            return "moon.stars.fill"
        case .weeklyReport:
            return "chart.line.uptrend.xyaxis"
        case .breathingReset:
            return "wind"
        case .plannedActivity:
            return "calendar.badge.clock"
        case .courseContinuation:
            return "graduationcap.fill"
        case .sleepWindDown:
            return "bed.double.fill"
        }
    }

    var settingsSubtitle: String {
        switch self {
        case .dailyMoodCheckIn:
            return String(localized: "A gentle nudge to notice how you feel")
        case .eveningReflection:
            return String(localized: "A quiet prompt to close the day")
        case .weeklyReport:
            return String(localized: "Once a week, when your insights are ready")
        case .breathingReset:
            return String(localized: "A short pause for your body")
        case .plannedActivity:
            return String(localized: "Uses the time saved on each planned activity")
        case .courseContinuation:
            return String(localized: "Suggests continuing an active course")
        case .sleepWindDown:
            return String(localized: "A calm reminder before your sleep routine")
        }
    }

    var notificationTitle: String {
        switch self {
        case .dailyMoodCheckIn:
            return String(localized: "A gentle check-in")
        case .eveningReflection:
            return String(localized: "A soft place to land")
        case .weeklyReport:
            return String(localized: "Your week, gently summarized")
        case .breathingReset:
            return String(localized: "One steady minute")
        case .plannedActivity:
            return String(localized: "A planned activity is coming up")
        case .courseContinuation:
            return String(localized: "Continue your course")
        case .sleepWindDown:
            return String(localized: "Time to soften the edges")
        }
    }

    var notificationBody: String {
        switch self {
        case .dailyMoodCheckIn:
            return String(localized: "How are you feeling right now? A few taps can help you notice the pattern.")
        case .eveningReflection:
            return String(localized: "When you have a moment, reflect on one thing from today and what you need next.")
        case .weeklyReport:
            return String(localized: "Your insights are ready when you want to look back with curiosity.")
        case .breathingReset:
            return String(localized: "A short breathing reset is here if your body could use a little room.")
        case .plannedActivity:
            return String(localized: "If it still fits, start with one small step.")
        case .courseContinuation:
            return String(localized: "Continue your active course when you have a comfortable pocket of time.")
        case .sleepWindDown:
            return String(localized: "A quiet reflection can help your mind settle before sleep.")
        }
    }

    var defaultHour: Int {
        switch self {
        case .dailyMoodCheckIn:
            return 9
        case .eveningReflection:
            return 20
        case .weeklyReport:
            return 18
        case .breathingReset:
            return 14
        case .plannedActivity:
            return 0
        case .courseContinuation:
            return 16
        case .sleepWindDown:
            return 21
        }
    }

    var defaultMinute: Int {
        switch self {
        case .eveningReflection:
            return 30
        case .sleepWindDown:
            return 30
        default:
            return 0
        }
    }

    var defaultWeekday: Int {
        1
    }

    var showsTimePicker: Bool {
        self != .plannedActivity
    }

    var isWeekly: Bool {
        self == .weeklyReport
    }

    var requiresModelContext: Bool {
        self == .plannedActivity || self == .courseContinuation
    }

    var deepLink: ContextualNotificationDeepLink {
        switch self {
        case .dailyMoodCheckIn:
            return .moodCheckIn
        case .eveningReflection:
            return .eveningReflection
        case .weeklyReport:
            return .weeklyReport
        case .breathingReset:
            return .breathing
        case .plannedActivity:
            return .plannedActivity
        case .courseContinuation:
            return .courseContinuation
        case .sleepWindDown:
            return .sleepWindDown
        }
    }

    var enabledDefaultsKey: String {
        switch self {
        case .dailyMoodCheckIn:
            return "cbt_moodReminderEnabled"
        case .eveningReflection:
            return "cbt_reflectionReminderEnabled"
        case .weeklyReport:
            return "cbt_weeklyReportReminderEnabled"
        case .breathingReset:
            return "cbt_breathingResetReminderEnabled"
        case .plannedActivity:
            return "cbt_plannedActivityReminderEnabled"
        case .courseContinuation:
            return "cbt_courseContinuationReminderEnabled"
        case .sleepWindDown:
            return "cbt_sleepWindDownReminderEnabled"
        }
    }

    var hourDefaultsKey: String? {
        switch self {
        case .dailyMoodCheckIn:
            return "cbt_moodReminderHour"
        case .eveningReflection:
            return "cbt_reflectionReminderHour"
        case .weeklyReport:
            return "cbt_weeklyReportReminderHour"
        case .breathingReset:
            return "cbt_breathingResetReminderHour"
        case .plannedActivity:
            return nil
        case .courseContinuation:
            return "cbt_courseContinuationReminderHour"
        case .sleepWindDown:
            return "cbt_sleepWindDownReminderHour"
        }
    }

    var minuteDefaultsKey: String? {
        switch self {
        case .dailyMoodCheckIn:
            return "cbt_moodReminderMinute"
        case .eveningReflection:
            return "cbt_reflectionReminderMinute"
        case .weeklyReport:
            return "cbt_weeklyReportReminderMinute"
        case .breathingReset:
            return "cbt_breathingResetReminderMinute"
        case .plannedActivity:
            return nil
        case .courseContinuation:
            return "cbt_courseContinuationReminderMinute"
        case .sleepWindDown:
            return "cbt_sleepWindDownReminderMinute"
        }
    }

    var weekdayDefaultsKey: String? {
        self == .weeklyReport ? "cbt_weeklyReportReminderWeekday" : nil
    }
}

final class PersonalizedReminderService {
    static let shared = PersonalizedReminderService()

    static let notificationKindUserInfoKey = "cbt_personalized_notification_kind"
    static let reminderTypeUserInfoKey = "cbt_personalized_reminder_type"
    static let deepLinkUserInfoKey = "cbt_personalized_deep_link"
    static let plannedActivityIDUserInfoKey = "cbt_planned_activity_id"
    static let courseIDUserInfoKey = "cbt_course_id"
    static let notificationKind = "personalized_reminder"

    private let notificationCenter: UNUserNotificationCenter
    private let maxPlannedActivityRequests = 20

    init(notificationCenter: UNUserNotificationCenter = .current()) {
        self.notificationCenter = notificationCenter
    }

    func schedule(
        _ type: PersonalizedReminderType,
        hour: Int? = nil,
        minute: Int? = nil,
        weekday: Int? = nil
    ) async throws {
        guard !type.requiresModelContext else { return }

        try await scheduleRepeatingReminder(
            type,
            body: type.notificationBody,
            hour: hour ?? type.defaultHour,
            minute: minute ?? type.defaultMinute,
            weekday: weekday ?? type.defaultWeekday,
            extraUserInfo: [:]
        )
    }

    @MainActor
    func refreshEnabledReminders(modelContext: ModelContext) async {
        let status = await PermissionManager.shared.status(for: .notifications)
        guard status.isAuthorized else { return }

        let defaults = UserDefaults.standard
        for type in PersonalizedReminderType.allCases where defaults.bool(forKey: type.enabledDefaultsKey) {
            do {
                if type == .plannedActivity {
                    try await schedulePlannedActivityReminders(modelContext: modelContext)
                } else if type == .courseContinuation {
                    try await scheduleCourseContinuationReminder(
                        modelContext: modelContext,
                        hour: storedInt(for: type.hourDefaultsKey, defaultValue: type.defaultHour),
                        minute: storedInt(for: type.minuteDefaultsKey, defaultValue: type.defaultMinute)
                    )
                } else {
                    try await schedule(
                        type,
                        hour: storedInt(for: type.hourDefaultsKey, defaultValue: type.defaultHour),
                        minute: storedInt(for: type.minuteDefaultsKey, defaultValue: type.defaultMinute),
                        weekday: storedInt(for: type.weekdayDefaultsKey, defaultValue: type.defaultWeekday)
                    )
                }
            } catch {
                continue
            }
        }
    }

    @MainActor
    func schedulePlannedActivityReminders(modelContext: ModelContext) async throws {
        await cancelPendingRequests(withPrefix: plannedActivityIdentifierPrefix)

        let now = Date()
        var descriptor = FetchDescriptor<PlannedActivity>(
            predicate: #Predicate<PlannedActivity> {
                $0.isDeleted == false &&
                $0.isCompleted == false &&
                $0.scheduledDate > now
            },
            sortBy: [SortDescriptor(\PlannedActivity.scheduledDate)]
        )
        descriptor.fetchLimit = maxPlannedActivityRequests

        let activities = try modelContext.fetch(descriptor)
        for activity in activities {
            let displayTitle = displayTitle(for: activity)
            let content = notificationContent(
                for: .plannedActivity,
                body: String(localized: "\(displayTitle) is on your plan. If it still fits, start with one small step."),
                extraUserInfo: [
                    Self.plannedActivityIDUserInfoKey: activity.id.uuidString
                ]
            )

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: activity.scheduledDate
            )

            let request = UNNotificationRequest(
                identifier: plannedActivityIdentifier(for: activity),
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )

            try await add(request)
        }
    }

    @MainActor
    func scheduleCourseContinuationReminder(modelContext: ModelContext, hour: Int, minute: Int) async throws {
        guard let course = try activeCourse(in: modelContext) else {
            cancel(.courseContinuation)
            return
        }

        try await scheduleRepeatingReminder(
            .courseContinuation,
            body: String(localized: "Continue \(course.title) when you have a comfortable pocket of time."),
            hour: hour,
            minute: minute,
            weekday: PersonalizedReminderType.courseContinuation.defaultWeekday,
            extraUserInfo: [
                Self.courseIDUserInfoKey: course.id
            ]
        )
    }

    func cancel(_ type: PersonalizedReminderType) {
        switch type {
        case .plannedActivity:
            cancelRequests(withPrefix: plannedActivityIdentifierPrefix)
        default:
            let id = identifier(for: type)
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [id])
            notificationCenter.removeDeliveredNotifications(withIdentifiers: [id])
        }

        cancelLegacyDailyReminder(for: type)
    }

    func cancelAllPersonalizedReminders() {
        PersonalizedReminderType.allCases.forEach(cancel)
    }

    func notificationDeepLink(from userInfo: [AnyHashable: Any]) -> ContextualNotificationDeepLink? {
        guard
            userInfo[Self.notificationKindUserInfoKey] as? String == Self.notificationKind,
            let deepLinkString = userInfo[Self.deepLinkUserInfoKey] as? String,
            let url = URL(string: deepLinkString)
        else {
            return nil
        }

        return ContextualNotificationDeepLink(url: url)
    }

    private func scheduleRepeatingReminder(
        _ type: PersonalizedReminderType,
        body: String,
        hour: Int,
        minute: Int,
        weekday: Int,
        extraUserInfo: [String: String]
    ) async throws {
        cancel(type)

        var components = DateComponents()
        if type.isWeekly {
            components.weekday = weekday
        }
        components.hour = hour
        components.minute = minute

        let request = UNNotificationRequest(
            identifier: identifier(for: type),
            content: notificationContent(for: type, body: body, extraUserInfo: extraUserInfo),
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )

        try await add(request)
    }

    private func notificationContent(
        for type: PersonalizedReminderType,
        body: String,
        extraUserInfo: [String: String]
    ) -> UNMutableNotificationContent {
        var userInfo: [String: String] = [
            Self.notificationKindUserInfoKey: Self.notificationKind,
            Self.reminderTypeUserInfoKey: type.rawValue,
            Self.deepLinkUserInfoKey: type.deepLink.url.absoluteString
        ]
        extraUserInfo.forEach { key, value in
            userInfo[key] = value
        }

        let content = UNMutableNotificationContent()
        content.title = type.notificationTitle
        content.body = body
        content.sound = .default
        content.userInfo = userInfo
        return content
    }

    private func activeCourse(in modelContext: ModelContext) throws -> Course? {
        let courses = try modelContext.fetch(FetchDescriptor<Course>(sortBy: [SortDescriptor(\Course.title)]))
        return courses.first { course in
            !course.isCompleted &&
            !course.completedItemIDs.isEmpty
        }
    }

    private func storedInt(for key: String?, defaultValue: Int) -> Int {
        guard let key, let value = UserDefaults.standard.object(forKey: key) as? Int else {
            return defaultValue
        }
        return value
    }

    private func identifier(for type: PersonalizedReminderType) -> String {
        "personalized_\(type.rawValue)_reminder"
    }

    private var plannedActivityIdentifierPrefix: String {
        "personalized_plannedActivity_"
    }

    private func plannedActivityIdentifier(for activity: PlannedActivity) -> String {
        "\(plannedActivityIdentifierPrefix)\(activity.id.uuidString)"
    }

    private func displayTitle(for activity: PlannedActivity) -> String {
        let title = activity.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else {
            return String(localized: "Your activity")
        }

        if title.count <= 60 {
            return title
        }

        return "\(title.prefix(60))..."
    }

    private func cancelLegacyDailyReminder(for type: PersonalizedReminderType) {
        switch type {
        case .dailyMoodCheckIn:
            DailyReminderService.shared.cancel(.morningIntentions)
        case .eveningReflection:
            DailyReminderService.shared.cancel(.eveningReflection)
        default:
            break
        }
    }

    private func cancelRequests(withPrefix prefix: String) {
        notificationCenter.getPendingNotificationRequests { [notificationCenter] requests in
            let identifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(prefix) }
            notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        }

        notificationCenter.getDeliveredNotifications { [notificationCenter] notifications in
            let identifiers = notifications
                .map(\.request.identifier)
                .filter { $0.hasPrefix(prefix) }
            notificationCenter.removeDeliveredNotifications(withIdentifiers: identifiers)
        }
    }

    private func cancelPendingRequests(withPrefix prefix: String) async {
        let identifiers = await withCheckedContinuation { continuation in
            notificationCenter.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests.map(\.identifier).filter { $0.hasPrefix(prefix) })
            }
        }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
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
