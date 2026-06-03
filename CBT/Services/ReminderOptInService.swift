import Foundation
import SwiftData

enum ReminderOptInMoment: String, CaseIterable, Identifiable {
    case firstMoodCheckIn
    case firstPlannedActivityCompletion
    case firstWeeklyInsightViewed
    case onboardingFirstWin

    var id: String { rawValue }

    var reminderType: PersonalizedReminderType {
        switch self {
        case .firstMoodCheckIn, .onboardingFirstWin:
            return .dailyMoodCheckIn
        case .firstPlannedActivityCompletion:
            return .plannedActivity
        case .firstWeeklyInsightViewed:
            return .weeklyReport
        }
    }

    var promptTitle: String {
        switch self {
        case .firstMoodCheckIn:
            return String(localized: "Want a gentle reminder to check in tomorrow?")
        case .firstPlannedActivityCompletion:
            return String(localized: "Want a reminder when your next activity is coming up?")
        case .firstWeeklyInsightViewed:
            return String(localized: "Want your weekly reflection reminder?")
        case .onboardingFirstWin:
            return String(localized: "Want help keeping this going tomorrow?")
        }
    }

    var promptMessage: String {
        switch self {
        case .firstMoodCheckIn:
            return String(localized: "You can turn this off anytime. CBT will only remind you to take a quick check-in when you choose.")
        case .firstPlannedActivityCompletion:
            return String(localized: "CBT can remind you about activities you have already planned, with room to adjust if the day changes.")
        case .firstWeeklyInsightViewed:
            return String(localized: "A weekly reminder can help you look back when you have space, without pressure to do it perfectly.")
        case .onboardingFirstWin:
            return String(localized: "A small reminder tomorrow can help your new plan stay easy to return to.")
        }
    }

    var acceptTitle: String {
        switch self {
        case .firstMoodCheckIn, .onboardingFirstWin:
            return String(localized: "Remind Me Tomorrow")
        case .firstPlannedActivityCompletion:
            return String(localized: "Remind Me")
        case .firstWeeklyInsightViewed:
            return String(localized: "Set Weekly Reminder")
        }
    }
}

enum ReminderOptInState: String {
    case dismissed
    case accepted
    case permissionDenied
}

@MainActor
final class ReminderOptInService {
    static let shared = ReminderOptInService()

    typealias NotificationStatusProvider = () async -> PermissionManager.Status
    typealias NotificationPermissionRequester = () async -> PermissionManager.Status
    typealias ReminderScheduler = (PersonalizedReminderType) async -> Bool

    private let defaults: UserDefaults
    private let notificationStatusProvider: NotificationStatusProvider
    private let notificationPermissionRequester: NotificationPermissionRequester
    private let reminderScheduler: ReminderScheduler?

    init(
        defaults: UserDefaults = .standard,
        notificationStatusProvider: @escaping NotificationStatusProvider = {
            await PermissionManager.shared.status(for: .notifications)
        },
        notificationPermissionRequester: @escaping NotificationPermissionRequester = {
            await PermissionManager.shared.request(.notifications)
        },
        reminderScheduler: ReminderScheduler? = nil
    ) {
        self.defaults = defaults
        self.notificationStatusProvider = notificationStatusProvider
        self.notificationPermissionRequester = notificationPermissionRequester
        self.reminderScheduler = reminderScheduler
    }

    func state(for moment: ReminderOptInMoment) -> ReminderOptInState? {
        guard let rawValue = defaults.string(forKey: stateKey(for: moment)) else { return nil }
        return ReminderOptInState(rawValue: rawValue)
    }

    func isEligible(
        for moment: ReminderOptInMoment,
        hasReachedMoment: Bool,
        notificationStatus: PermissionManager.Status
    ) -> Bool {
        guard hasReachedMoment else { return false }
        guard state(for: moment) == nil else { return false }
        guard notificationStatus != .denied else { return false }
        return !defaults.bool(forKey: moment.reminderType.enabledDefaultsKey)
    }

    func promptIfEligible(
        for moment: ReminderOptInMoment,
        hasReachedMoment: Bool
    ) async -> ReminderOptInMoment? {
        let status = await notificationStatusProvider()
        return isEligible(for: moment, hasReachedMoment: hasReachedMoment, notificationStatus: status) ? moment : nil
    }

    func dismiss(_ moment: ReminderOptInMoment) {
        setState(.dismissed, for: moment)
    }

    func accept(_ moment: ReminderOptInMoment, modelContext: ModelContext? = nil) async -> Bool {
        let status = await authorizationStatusForOptIn()
        guard status.isAuthorized else {
            defaults.set(false, forKey: moment.reminderType.enabledDefaultsKey)
            setState(.permissionDenied, for: moment)
            return false
        }

        defaults.set(true, forKey: moment.reminderType.enabledDefaultsKey)

        let didSchedule: Bool
        if let reminderScheduler {
            didSchedule = await reminderScheduler(moment.reminderType)
        } else {
            didSchedule = await scheduleExistingReminder(moment.reminderType, modelContext: modelContext)
        }

        if didSchedule {
            setState(.accepted, for: moment)
        }

        return didSchedule
    }

    private func authorizationStatusForOptIn() async -> PermissionManager.Status {
        let currentStatus = await notificationStatusProvider()
        guard currentStatus == .notDetermined else { return currentStatus }
        return await notificationPermissionRequester()
    }

    private func scheduleExistingReminder(_ reminderType: PersonalizedReminderType, modelContext: ModelContext?) async -> Bool {
        do {
            switch reminderType {
            case .plannedActivity:
                guard let modelContext else { return false }
                try await PersonalizedReminderService.shared.schedulePlannedActivityReminders(modelContext: modelContext)
            case .courseContinuation:
                guard let modelContext else { return false }
                try await PersonalizedReminderService.shared.scheduleCourseContinuationReminder(
                    modelContext: modelContext,
                    hour: storedInt(for: reminderType.hourDefaultsKey, defaultValue: reminderType.defaultHour),
                    minute: storedInt(for: reminderType.minuteDefaultsKey, defaultValue: reminderType.defaultMinute)
                )
            case .streakReengagement:
                guard let modelContext else { return false }
                await StreakReengagementNotificationService.shared.refreshReminder(modelContext: modelContext)
            default:
                try await PersonalizedReminderService.shared.schedule(
                    reminderType,
                    hour: storedInt(for: reminderType.hourDefaultsKey, defaultValue: reminderType.defaultHour),
                    minute: storedInt(for: reminderType.minuteDefaultsKey, defaultValue: reminderType.defaultMinute),
                    weekday: storedInt(for: reminderType.weekdayDefaultsKey, defaultValue: reminderType.defaultWeekday)
                )
            }
            return true
        } catch {
            defaults.set(false, forKey: reminderType.enabledDefaultsKey)
            return false
        }
    }

    private func setState(_ state: ReminderOptInState, for moment: ReminderOptInMoment) {
        defaults.set(state.rawValue, forKey: stateKey(for: moment))
    }

    private func stateKey(for moment: ReminderOptInMoment) -> String {
        "cbt_reminderOptIn_\(moment.rawValue)_state"
    }

    private func storedInt(for key: String?, defaultValue: Int) -> Int {
        guard let key, let value = defaults.object(forKey: key) as? Int else {
            return defaultValue
        }
        return value
    }
}
