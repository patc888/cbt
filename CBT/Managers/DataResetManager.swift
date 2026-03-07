import Foundation
import SwiftData
import CloudKit
import UserNotifications
import SwiftUI
import OSLog

extension Notification.Name {
    static let didResetData = Notification.Name("didResetData")
    static let exerciseFlowDidEnter = Notification.Name("exerciseFlowDidEnter")
    static let exerciseFlowDidExit = Notification.Name("exerciseFlowDidExit")
}

@Observable
final class DataResetManager {
    static let shared = DataResetManager()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CBT",
        category: "DataReset"
    )

    var defaultStoreURL: URL {
        ModelConfiguration().url
    }

    var fallbackStoreURL: URL {
        defaultStoreURL
            .deletingLastPathComponent()
            .appendingPathComponent("local-recovery.store")
    }

    // 1. Clears AppStorage/UserDefaults
    // 2. Cancels scheduled local notifications
    // 3. Wipes SwiftData default.store directly without triggering CloudKit sync closures
    func performLocalWipe() {
        // 1. Clear UserDefaults & AppStorage
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
            UserDefaults.standard.synchronize()
        }
        
        // 2. Clear notifications
        Task {
            await ReminderManager.shared.cancelAllCBTReminders()
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        
        do {
            try removeStoreFiles(at: defaultStoreURL)
            try removeStoreFiles(at: fallbackStoreURL)
        } catch {
            logFileOperationFailure(error, action: "local-wipe")
        }
        
        // 4. Broadcast reset so UI recreates its context
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .didResetData, object: nil)
        }
    }

    // Deletes CloudKit synced database and then wipes local data
    func performGlobalWipe() async throws {
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
        
        // Trigger local wipe after cloud wipe attempt
        await MainActor.run {
            self.performLocalWipe()
        }
    }

    @discardableResult
    func quarantineDefaultStoreForRepair() throws -> URL? {
        let files = try relatedStoreFiles(for: defaultStoreURL)
        guard !files.isEmpty else { return nil }

        let quarantineDirectory = defaultStoreURL
            .deletingLastPathComponent()
            .appendingPathComponent("StoreRecovery", isDirectory: true)
            .appendingPathComponent(Self.recoveryFolderName(from: Date()), isDirectory: true)

        try FileManager.default.createDirectory(
            at: quarantineDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        for file in files {
            try FileManager.default.moveItem(
                at: file,
                to: quarantineDirectory.appendingPathComponent(file.lastPathComponent)
            )
        }

        Self.logger.notice("Quarantined local store files count=\(files.count, privacy: .public)")
        return quarantineDirectory
    }

    func removeFallbackStoreFiles() throws {
        try removeStoreFiles(at: fallbackStoreURL)
    }

    private func removeStoreFiles(at storeURL: URL) throws {
        let files = try relatedStoreFiles(for: storeURL)
        for file in files {
            if FileManager.default.fileExists(atPath: file.path) {
                try FileManager.default.removeItem(at: file)
            }
        }
    }

    private func relatedStoreFiles(for storeURL: URL) throws -> [URL] {
        let storeDirectory = storeURL.deletingLastPathComponent()
        guard FileManager.default.fileExists(atPath: storeDirectory.path) else {
            return []
        }

        let files = try FileManager.default.contentsOfDirectory(
            at: storeDirectory,
            includingPropertiesForKeys: nil
        )

        return files.filter { $0.lastPathComponent.hasPrefix(storeURL.lastPathComponent) }
    }

    private func logFileOperationFailure(_ error: Error, action: String) {
        let nsError = error as NSError
        Self.logger.error(
            "Store file operation failed action=\(action, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
    }

    private static func recoveryFolderName(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        return "repair-\(formatter.string(from: date))"
    }
}
