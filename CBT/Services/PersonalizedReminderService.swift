import Foundation
import SwiftData
import UserNotifications

enum PersonalizedReminderType: String, CaseIterable, Identifiable {
    case dailyMoodCheckIn
    case streakReengagement
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
        case .streakReengagement:
            return String(localized: "Streak Re-Engagement")
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
        case .streakReengagement:
            return "flame.fill"
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
            return String(localized: "Track mood, body signals, and context at the time you choose")
        case .streakReengagement:
            return String(localized: "Return to a quick mood check-in after two days away")
        case .eveningReflection:
            return String(localized: "Review what stood out today and what you may need next")
        case .weeklyReport:
            return String(localized: "Look back at trends, streaks, entries, and progress once a week")
        case .breathingReset:
            return String(localized: "Create a brief pause when your body could use more room")
        case .plannedActivity:
            return String(localized: "Uses each saved activity time and only reminds you about upcoming plans")
        case .courseContinuation:
            return String(localized: "Return to an active course when you have space to continue")
        case .sleepWindDown:
            return String(localized: "Begin a quieter routine before bed with reflection and closure")
        }
    }

    var notificationTitle: String {
        switch self {
        case .dailyMoodCheckIn:
            return String(localized: "Check in with yourself")
        case .streakReengagement:
            return String(localized: "Check in with yourself")
        case .eveningReflection:
            return String(localized: "Reflect before the day closes")
        case .weeklyReport:
            return String(localized: "Your weekly insight is ready")
        case .breathingReset:
            return String(localized: "Make room for one steady minute")
        case .plannedActivity:
            return String(localized: "Your planned activity is coming up")
        case .courseContinuation:
            return String(localized: "Continue your CBT course")
        case .sleepWindDown:
            return String(localized: "Begin your sleep wind-down")
        }
    }

    var notificationBody: String {
        switch self {
        case .dailyMoodCheckIn:
            return String(localized: "Take a moment to name your mood, intensity, and context. A quick check-in can make patterns easier to see over time.")
        case .streakReengagement:
            return String(localized: "A 30-second mood check-in can keep your pattern visible when you are ready to return.")
        case .eveningReflection:
            return String(localized: "Look back with care: what stood out, what felt hard, and what would help you tomorrow?")
        case .weeklyReport:
            return String(localized: "Review mood trends, entries, achievements, and patterns from the week when you are ready to reflect.")
        case .breathingReset:
            return String(localized: "Pause for a guided breathing reset to help your body settle before you continue.")
        case .plannedActivity:
            return String(localized: "If this still fits your day, begin with the first small step and adjust as needed.")
        case .courseContinuation:
            return String(localized: "Pick up the next lesson or exercise when you have a comfortable pocket of time.")
        case .sleepWindDown:
            return String(localized: "A quiet reflection can help your mind review the day, set down loose ends, and move toward rest.")
        }
    }

    var defaultHour: Int {
        switch self {
        case .dailyMoodCheckIn, .streakReengagement:
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
        self != .plannedActivity && self != .streakReengagement
    }

    var isWeekly: Bool {
        self == .weeklyReport
    }

    var requiresModelContext: Bool {
        self == .plannedActivity || self == .courseContinuation || self == .streakReengagement
    }

    var deepLink: ContextualNotificationDeepLink {
        switch self {
        case .dailyMoodCheckIn, .streakReengagement:
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
        case .streakReengagement:
            return "cbt_streakReengagementReminderEnabled"
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
        case .streakReengagement:
            return nil
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
        case .streakReengagement:
            return nil
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
                } else if type == .streakReengagement {
                    await StreakReengagementNotificationService.shared.refreshReminder(modelContext: modelContext)
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
                body: String(localized: "\(displayTitle) is on your plan. If it still fits your day, begin with the first small step and adjust as needed."),
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
            body: String(localized: "Continue \(course.title) when you have a comfortable pocket of time for the next lesson or exercise."),
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
        case .streakReengagement:
            StreakReengagementNotificationService.shared.cancel()
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

final class StreakReengagementNotificationService {
    static let shared = StreakReengagementNotificationService()

    static let lastLoginTimestampKey = "last_login_timestamp"
    static let lastDailyCheckTimestampKey = "cbt_streak_reengagement_last_daily_check_timestamp"
    static let enabledDefaultsKey = "cbt_streakReengagementReminderEnabled"

    private let notificationCenter: UNUserNotificationCenter
    private let defaults: UserDefaults
    private let notificationIdentifier = "streak_reengagement_mood_check_in"
    private let inactivityThreshold: TimeInterval = 48 * 60 * 60

    init(
        notificationCenter: UNUserNotificationCenter = .current(),
        defaults: UserDefaults = .standard
    ) {
        self.notificationCenter = notificationCenter
        self.defaults = defaults
    }

    @MainActor
    func handleAppLogin(
        modelContext: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        defaults.set(now, forKey: Self.lastLoginTimestampKey)
        await refreshReminder(modelContext: modelContext, now: now, calendar: calendar)
    }

    @MainActor
    func refreshReminder(
        modelContext: ModelContext,
        now: Date = Date(),
        calendar: Calendar = .current
    ) async {
        guard defaults.bool(forKey: Self.enabledDefaultsKey) else {
            cancel()
            return
        }

        let status = await PermissionManager.shared.status(for: .notifications)
        guard status.isAuthorized else {
            cancel()
            return
        }

        do {
            let streakCount = try currentMoodStreak(modelContext: modelContext, calendar: calendar, now: now)
            try await scheduleNotification(
                streakCount: streakCount,
                triggerDate: Self.nextReengagementDate(from: now)
            )
        } catch {
            return
        }
    }

    static func shouldRunDailyCheck(lastCheck: Date?, now: Date, calendar: Calendar) -> Bool {
        guard let lastCheck else { return true }
        return !calendar.isDate(lastCheck, inSameDayAs: now)
    }

    static func hasBeenAwayFor48Hours(lastLogin: Date, now: Date) -> Bool {
        now.timeIntervalSince(lastLogin) >= 48 * 60 * 60
    }

    static func nextReengagementDate(from date: Date) -> Date {
        date.addingTimeInterval(48 * 60 * 60)
    }

    static func notificationBody(streakCount: Int) -> String {
        if streakCount > 0 {
            return "Your \(streakCount)-day streak can keep going with one 30-second mood check-in."
        }

        return "A 30-second mood check-in can make it easier to notice your pattern today."
    }

    @MainActor
    private func currentMoodStreak(modelContext: ModelContext, calendar: Calendar, now: Date) throws -> Int {
        let moodEntries = try modelContext.fetch(FetchDescriptor<MoodEntry>())
            .filter { !$0.isDeleted }
            .map(\.createdAt)
        let moodCheckIns = try modelContext.fetch(FetchDescriptor<MoodCheckIn>())
            .filter { !$0.isDeleted }
            .map(\.createdAt)
        let days = Set((moodEntries + moodCheckIns).map { calendar.startOfDay(for: $0) })

        return Self.currentStreak(from: days, calendar: calendar, today: calendar.startOfDay(for: now))
    }

    static func currentStreak(from days: Set<Date>, calendar: Calendar, today: Date) -> Int {
        let sortedDays = days.sorted()
        guard !sortedDays.isEmpty else { return 0 }

        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        guard let lastActiveDay = sortedDays.last, lastActiveDay >= yesterday else {
            return 0
        }

        var currentStreak = 1
        guard sortedDays.count > 1 else { return currentStreak }

        for index in (0..<(sortedDays.count - 1)).reversed() {
            let previous = sortedDays[index]
            let current = sortedDays[index + 1]
            let dayDifference = calendar.dateComponents([.day], from: previous, to: current).day ?? 0

            if dayDifference == 1 {
                currentStreak += 1
            } else {
                break
            }
        }

        return currentStreak
    }

    func cancel() {
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier])
        notificationCenter.removeDeliveredNotifications(withIdentifiers: [notificationIdentifier])
    }

    private func scheduleNotification(streakCount: Int, triggerDate: Date) async throws {
        cancel()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Check in with yourself")
        content.body = Self.notificationBody(streakCount: streakCount)
        content.sound = .default
        content.userInfo = [
            PersonalizedReminderService.notificationKindUserInfoKey: PersonalizedReminderService.notificationKind,
            PersonalizedReminderService.reminderTypeUserInfoKey: "streakReengagement",
            PersonalizedReminderService.deepLinkUserInfoKey: ContextualNotificationDeepLink.moodCheckIn.url.absoluteString
        ]

        let request = UNNotificationRequest(
            identifier: notificationIdentifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate),
                repeats: false
            )
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
}
