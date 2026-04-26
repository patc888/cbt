import Foundation
import SwiftData
import UserNotifications

final class TimeNotificationManager {
    enum AccessState: Equatable {
        case enabled
        case notDetermined
        case denied
        case unavailable

        var allowsScheduling: Bool {
            self == .enabled
        }

        var requiresSystemSettings: Bool {
            self == .denied || self == .unavailable
        }
    }

    private let center: UNUserNotificationCenter
    private let calendar: Calendar
    private let identifierPrefix = "time-block-reminder-"

    init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current
    ) {
        self.center = center
        self.calendar = calendar
    }

    func accessState() async -> AccessState {
        let settings = await center.notificationSettings()
        return accessState(for: settings)
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()

        switch accessState(for: settings) {
        case .enabled:
            return true
        case .denied, .unavailable:
            return false
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    func scheduleReminder(for block: TimeBlock, preferences: AppPreferences, now: Date = .now) async {
        let isAuthorized = await requestAuthorizationIfNeeded()
        await scheduleReminder(for: block, preferences: preferences, isAuthorized: isAuthorized, now: now)
    }

    private func scheduleReminder(
        for block: TimeBlock,
        preferences: AppPreferences,
        isAuthorized: Bool,
        now: Date
    ) async {
        let identifier = notificationIdentifier(for: block)

        guard isAuthorized, preferences.notificationsEnabled ?? false else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        guard block.status == .planned else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        let trimmedTitle = block.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, block.endDate > block.startDate else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        let leadTimeMinutes = max(preferences.notificationLeadTimeMinutes ?? 0, 0)
        let triggerDate = block.startDate.addingTimeInterval(TimeInterval(leadTimeMinutes * -60))

        guard triggerDate > now else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        let content = UNMutableNotificationContent()
        content.title = trimmedTitle
        content.body = leadTimeMinutes == 0
            ? "Your time block starts now."
            : "Your time block starts in \(leadTimeMinutes) minutes."
        content.sound = .default
        content.userInfo = ["timeBlockID": block.id.uuidString]

        let dateComponents = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: triggerDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        // removePendingNotificationRequests is O(N) where N is number of pending requests in system.
        // We call it once before adding to ensure we replace any existing request for this specific identifier.
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await center.add(request)
    }

    func cancelReminder(for block: TimeBlock) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationIdentifier(for: block)])
    }

    func cancelReminder(forBlockID blockID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: ["\(identifierPrefix)\(blockID.uuidString)"])
    }

    func resyncUpcomingReminders(
        in modelContext: ModelContext,
        preferences: AppPreferences,
        now: Date = .now
    ) async {
        let sevenDaysLater = now.addingTimeInterval(7 * 24 * 60 * 60)
        let descriptor = FetchDescriptor<TimeBlock>(
            predicate: #Predicate<TimeBlock> { block in
                block.endDate >= now && block.startDate <= sevenDaysLater
            },

            sortBy: [
                SortDescriptor(\.startDate),
                SortDescriptor(\.sortOrder)
            ]
        )


        let blocks = (try? modelContext.fetch(descriptor)) ?? []
        let requests = await center.pendingNotificationRequests()
        let managedRequestIDs = requests
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }

        let notificationsEnabled = preferences.notificationsEnabled ?? false
        let isAuthorized = notificationsEnabled ? await requestAuthorizationIfNeeded() : false

        if !isAuthorized || !notificationsEnabled {
            if !managedRequestIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: managedRequestIDs)
            }
            return
        }

        let validRequestIDs = Set(
            blocks
                .filter { block in
                    let leadTimeMinutes = max(preferences.notificationLeadTimeMinutes ?? 0, 0)
                    let triggerDate = block.startDate.addingTimeInterval(TimeInterval(leadTimeMinutes * -60))
                    let trimmedTitle = block.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    return block.status == .planned &&
                        block.endDate > block.startDate &&
                        !trimmedTitle.isEmpty &&
                        triggerDate > now
                }
                .map(notificationIdentifier(for:))
        )

        let staleRequestIDs = managedRequestIDs.filter { !validRequestIDs.contains($0) }
        if !staleRequestIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: staleRequestIDs)
        }

        // Now update/add the valid ones.
        // Note: UNUserNotificationCenter.add is already async and internally handles queues.
        // We optimized by only calling requestAuthorizationIfNeeded once at the start of resync.
        for block in blocks {
            await scheduleReminder(for: block, preferences: preferences, isAuthorized: isAuthorized, now: now)
        }
    }

    private func notificationIdentifier(for block: TimeBlock) -> String {
        "\(identifierPrefix)\(block.id.uuidString)"
    }

    private func accessState(for settings: UNNotificationSettings) -> AccessState {
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            let alertsAvailable = settings.alertSetting == .enabled || settings.notificationCenterSetting == .enabled
            return alertsAvailable ? .enabled : .unavailable
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        @unknown default:
            return .unavailable
        }
    }
}
