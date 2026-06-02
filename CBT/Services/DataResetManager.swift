import Foundation
import CloudKit
import OSLog

extension Notification.Name {
    static let requestDataReset = Notification.Name("requestDataReset")
    static let didResetData = Notification.Name("didResetData")
    static let exerciseFlowDidEnter = Notification.Name("exerciseFlowDidEnter")
    static let exerciseFlowDidExit = Notification.Name("exerciseFlowDidExit")
    static let quizFlowDidEnter = Notification.Name("quizFlowDidEnter")
    static let quizFlowDidExit = Notification.Name("quizFlowDidExit")
}

@Observable
final class DataResetManager {
    nonisolated static let shared = DataResetManager()
    private nonisolated static let cloudSyncKey = "com.melichan.CBT.cloudSyncEnabled"
    private nonisolated static let localPreferenceKeys = [
        cloudSyncKey,
        "lastCloudSyncDate",
        "cbt_onboardingCompleted",
        "cbt_dailyPlanGoalIDs",
        "cbt_dailyPlanInterestIDs",
        "appColorTheme",
        "userTheme",
        "appThemeImmersive",
        "hapticsEnabled",
        "interactionSoundsEnabled",
        "strongHapticsEnabled",
        AppConfiguration.showStreakInToolbarKey,
        "appLockEnabled",
        "autoLockDelay",
        "hideAppSwitcher",
        "cbt_moodReminderEnabled",
        "cbt_reflectionReminderEnabled",
        "cbt_weeklyReportReminderEnabled",
        "cbt_breathingResetReminderEnabled",
        "cbt_plannedActivityReminderEnabled",
        "cbt_courseContinuationReminderEnabled",
        "cbt_sleepWindDownReminderEnabled",
        "cbt_quoteOfTheDayEnabled",
        "cbt_contextualBeforeWorkEnabled",
        "cbt_contextualDuringCommuteEnabled",
        "cbt_contextualBeforeBedEnabled",
        "cbt_moodReminderHour",
        "cbt_moodReminderMinute",
        "cbt_reflectionReminderHour",
        "cbt_reflectionReminderMinute",
        "cbt_weeklyReportReminderHour",
        "cbt_weeklyReportReminderMinute",
        "cbt_weeklyReportReminderWeekday",
        "cbt_breathingResetReminderHour",
        "cbt_breathingResetReminderMinute",
        "cbt_courseContinuationReminderHour",
        "cbt_courseContinuationReminderMinute",
        "cbt_sleepWindDownReminderHour",
        "cbt_sleepWindDownReminderMinute",
        "cbt_quietHoursEnabled",
        "cbt_quietHoursStartHour",
        "cbt_quietHoursStartMinute",
        "cbt_quietHoursEndHour",
        "cbt_quietHoursEndMinute",
        "cbt_moodGoalValue",
        "cbt_home_lastOpenedAt",
        StreakReengagementNotificationService.lastLoginTimestampKey,
        StreakReengagementNotificationService.lastDailyCheckTimestampKey,
        "cbt.achievements.weeklyReportViewed",
        "affirmation_favorites_v1"
    ]
    
    nonisolated static var isCloudSyncEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: AppConfiguration.cloudKitEnabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: AppConfiguration.cloudKitEnabledKey)
        }
    }
    
    func requestLocalWipe() {
        NotificationCenter.default.post(name: .requestDataReset, object: nil)
    }

    func deleteCloudData() async throws {
        try await purgePrivateCloudKitDatabase()
        clearCloudKeyValueStore()
        requestLocalWipe()
    }

    func deleteCloudDataAndLocalStore() async throws {
        try await purgePrivateCloudKitDatabase()
        clearCloudKeyValueStore()
    }

    func resetLocalPreferences(_ defaults: UserDefaults = .standard) {
        for key in Self.localPreferenceKeys {
            defaults.removeObject(forKey: key)
        }
    }

    private func purgePrivateCloudKitDatabase() async throws {
        let container = AppConfiguration.cloudKitContainer
        let status = try await container.accountStatus()

        guard status == .available else {
            throw DataResetError.cloudAccountUnavailable(statusDescription(for: status))
        }

        let database = container.privateCloudDatabase
        let zones = try await database.allRecordZones()
        let deletableZones = zones.filter { $0.zoneID != CKRecordZone.default().zoneID }

        for zone in deletableZones {
            _ = try await database.deleteRecordZone(withID: zone.zoneID)
        }
    }

    private func clearCloudKeyValueStore() {
        let store = NSUbiquitousKeyValueStore.default
        for key in [
            "hapticsEnabled",
            "appLockEnabled",
            "currentIcon"
        ] {
            store.removeObject(forKey: key)
        }
        store.synchronize()
    }

    private func statusDescription(for status: CKAccountStatus) -> String {
        switch status {
        case .available:
            return "Available"
        case .noAccount:
            return "No iCloud Account"
        case .restricted:
            return "Restricted"
        case .couldNotDetermine:
            return "Could Not Determine"
        case .temporarilyUnavailable:
            return "Temporarily Unavailable"
        @unknown default:
            return "Unknown"
        }
    }
}

enum DataResetError: LocalizedError {
    case cloudAccountUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .cloudAccountUnavailable(let status):
            return "CloudKit data could not be deleted because iCloud is not available. Account status: \(status)."
        }
    }
}

private extension CKDatabase {
    func allRecordZones() async throws -> [CKRecordZone] {
        try await withCheckedThrowingContinuation { continuation in
            fetchAllRecordZones { zones, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: zones ?? [])
                }
            }
        }
    }

    func deleteRecordZone(withID zoneID: CKRecordZone.ID) async throws -> CKRecordZone.ID {
        try await withCheckedThrowingContinuation { continuation in
            delete(withRecordZoneID: zoneID) { deletedZoneID, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let deletedZoneID {
                    continuation.resume(returning: deletedZoneID)
                } else {
                    continuation.resume(returning: zoneID)
                }
            }
        }
    }
}
