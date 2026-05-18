import CloudKit

enum AppConfiguration {
    nonisolated static let appGroupIdentifier = "group.com.melichan.CBT"
    nonisolated static let cloudKitContainerIdentifier = "iCloud.com.melichan.CBT"
    nonisolated static let cloudKitEnabledKey = "com.melichan.CBT.cloudKitStoreEnabled"
    nonisolated static let persistenceModeKey = "com.melichan.CBT.persistenceMode"
    nonisolated static let cloudKitRecoveryMessageKey = "com.melichan.CBT.cloudKitRecoveryMessage"
    nonisolated static let cloudKitFailureReasonKey = "com.melichan.CBT.cloudKitFailureReason"

    static var cloudKitContainer: CKContainer {
        CKContainer(identifier: cloudKitContainerIdentifier)
    }
}
