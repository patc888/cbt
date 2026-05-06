import CloudKit

enum AppConfiguration {
    static let appGroupIdentifier = "group.com.melichan.CBT"
    static let cloudKitContainerIdentifier = "iCloud.com.melichan.CBT"

    static var cloudKitContainer: CKContainer {
        CKContainer(identifier: cloudKitContainerIdentifier)
    }
}
