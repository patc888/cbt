import CloudKit

enum AppConfiguration {
    nonisolated static let appGroupIdentifier = "group.com.melichan.CBT"
    nonisolated static let cloudKitContainerIdentifier = "iCloud.com.melichan.CBT"
    nonisolated static let cloudKitEnabledKey = "com.melichan.CBT.cloudKitStoreEnabled"
    nonisolated static let persistenceModeKey = "com.melichan.CBT.persistenceMode"

    static var cloudKitContainer: CKContainer {
        CKContainer(identifier: cloudKitContainerIdentifier)
    }
}
