import Foundation
import CloudKit

enum AppConfiguration {
    nonisolated static let appGroupIdentifier = "group.com.melichan.CBT"
    nonisolated static let cloudKitContainerIdentifier = "iCloud.com.melichan.CBT"
    nonisolated static let cloudKitEnabledKey = "com.melichan.CBT.cloudKitStoreEnabled"
    nonisolated static let persistenceModeKey = "com.melichan.CBT.persistenceMode"
    nonisolated static let cloudKitRecoveryMessageKey = "com.melichan.CBT.cloudKitRecoveryMessage"
    nonisolated static let cloudKitFailureReasonKey = "com.melichan.CBT.cloudKitFailureReason"
    nonisolated static let showStreakInToolbarKey = "cbt_showStreakInToolbar"
    nonisolated static let inMemoryStoreEnvironmentKey = "CBT_USE_IN_MEMORY_STORE"
    nonisolated static let defaultCloudKitFallbackReason = "CloudKit storage could not start. CBT is using local storage for this launch."
    nonisolated static let cloudKitFallbackRecoveryMessage = "CBT couldn't start iCloud sync and is temporarily using local storage. Your data will stay on this device until iCloud storage opens successfully."

    static var cloudKitContainer: CKContainer {
        CKContainer(identifier: cloudKitContainerIdentifier)
    }

    nonisolated static var shouldUseInMemoryStoreForThisProcess: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment[inMemoryStoreEnvironmentKey] == "1"
            || environment["XCTestConfigurationFilePath"] != nil
    }

    nonisolated static func registerUserDefaults(_ defaults: UserDefaults = .standard) {
        defaults.register(defaults: [
            showStreakInToolbarKey: true
        ])
    }
}
