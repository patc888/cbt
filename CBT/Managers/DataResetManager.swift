import Foundation
import SwiftData
import CloudKit
import UserNotifications
import SwiftUI
import OSLog

extension Notification.Name {
    static let requestDataReset = Notification.Name("requestDataReset")
    static let didResetData = Notification.Name("didResetData")
    static let exerciseFlowDidEnter = Notification.Name("exerciseFlowDidEnter")
    static let exerciseFlowDidExit = Notification.Name("exerciseFlowDidExit")
}

@Observable
final class DataResetManager {
    nonisolated static let shared = DataResetManager()
    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CBT",
        category: "DataReset"
    )

    nonisolated static var defaultStoreURL: URL {
        ModelConfiguration().url
    }

    nonisolated static var fallbackStoreURL: URL {
        defaultStoreURL
            .deletingLastPathComponent()
            .appendingPathComponent("local-recovery.store")
    }

    nonisolated var defaultStoreURL: URL {
        Self.defaultStoreURL
    }

    nonisolated var fallbackStoreURL: URL {
        Self.fallbackStoreURL
    }

    func requestLocalWipe() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .requestDataReset, object: nil)
        }
    }

    // 1. Clears AppStorage/UserDefaults
    // 2. Cancels scheduled local notifications
    // 3. Wipes SwiftData stores after the query-backed UI has been torn down
    func performLocalWipeHousekeeping() async {
        // 1. Clear UserDefaults & AppStorage
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }

        // 2. Clear notifications
        await ReminderManager.shared.cancelAllCBTReminders()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()

        do {
            try Self.removeStoreFiles(at: Self.defaultStoreURL)
            try Self.removeStoreFiles(at: Self.fallbackStoreURL)
        } catch {
            logFileOperationFailure(error, action: "local-wipe")
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .didResetData, object: nil)
        }
    }

    func deleteCloudData() async throws {
        let container = CKContainer.default()
        let database = container.privateCloudDatabase

        // The automatic SwiftData CloudKit zone name. 
        // SwiftData typically uses "com.apple.coredata.cloudkit.zone" for the default synced store.
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)

        do {
            // This permanently deletes the zone and all records within it in the user's private database.
            try await database.deleteRecordZone(withID: zoneID)
        } catch let error as CKError {
            // If the zone doesn't exist, we can't delete it, which is fine for a reset.
            if error.code == .zoneNotFound || error.code == .notAuthenticated || error.code == .networkUnavailable {
                // Not an error we need to stop for
            } else {
                throw error
            }
        } catch {
            throw error
        }
    }

    @discardableResult
    nonisolated func quarantineDefaultStoreForRepair() throws -> URL? {
        try Self.quarantineDefaultStoreForRepair()
    }

    @discardableResult
    nonisolated static func quarantineDefaultStoreForRepair() throws -> URL? {
        let fileManager = FileManager()
        let files = try relatedStoreFiles(for: defaultStoreURL, using: fileManager)
        guard !files.isEmpty else { return nil }

        let quarantineDirectory = defaultStoreURL
            .deletingLastPathComponent()
            .appendingPathComponent("StoreRecovery", isDirectory: true)
            .appendingPathComponent(Self.recoveryFolderName(from: Date()), isDirectory: true)

        try fileManager.createDirectory(
            at: quarantineDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        for file in files {
            try fileManager.moveItem(
                at: file,
                to: quarantineDirectory.appendingPathComponent(file.lastPathComponent)
            )
        }

        Self.logger.notice("Quarantined local store files count=\(files.count, privacy: .public)")
        return quarantineDirectory
    }

    nonisolated func removeFallbackStoreFiles() throws {
        try Self.removeFallbackStoreFiles()
    }

    nonisolated static func removeFallbackStoreFiles() throws {
        try removeStoreFiles(at: fallbackStoreURL)
    }

    private nonisolated static func removeStoreFiles(at storeURL: URL) throws {
        let fileManager = FileManager()
        let files = try relatedStoreFiles(for: storeURL, using: fileManager)
        for file in files {
            if fileManager.fileExists(atPath: file.path) {
                try fileManager.removeItem(at: file)
            }
        }
    }

    private nonisolated static func relatedStoreFiles(for storeURL: URL, using fileManager: FileManager) throws -> [URL] {
        let storeDirectory = storeURL.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: storeDirectory.path) else {
            return []
        }

        let files = try fileManager.contentsOfDirectory(
            at: storeDirectory,
            includingPropertiesForKeys: nil
        )

        return files.filter { $0.lastPathComponent.hasPrefix(storeURL.lastPathComponent) }
    }

    private nonisolated func logFileOperationFailure(_ error: Error, action: String) {
        let nsError = error as NSError
        Self.logger.error(
            "Store file operation failed action=\(action, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
    }

    private nonisolated static func recoveryFolderName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return "repair-\(formatter.string(from: date))"
    }
}
