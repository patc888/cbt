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

enum DataResetError: LocalizedError, Equatable {
    case cloudSyncUnavailable
    case iCloudAccountRequired
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .cloudSyncUnavailable:
            return "iCloud reset is currently unavailable because sync is turned off in this build."
        case .iCloudAccountRequired:
            return "Sign in to iCloud before trying to delete cloud data."
        case .networkUnavailable:
            return "A network connection is required to delete cloud data."
        }
    }
}

@Observable
final class DataResetManager {
    nonisolated static let shared = DataResetManager()
    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CBT",
        category: "DataReset"
    )
    nonisolated static let isCloudSyncEnabled = false

    private nonisolated static let _defaultStoreURL: URL = ModelConfiguration().url

    nonisolated static var defaultStoreURL: URL {
        _defaultStoreURL
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

        // Give SwiftData a short teardown window after the app switches back to the
        // loading shell so the old container can release SQLite file handles cleanly.
        try? await Task.sleep(for: .milliseconds(450))

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
        guard Self.isCloudSyncEnabled else {
            throw DataResetError.cloudSyncUnavailable
        }

        let container = CKContainer.default()
        let database = container.privateCloudDatabase

        // The automatic SwiftData CloudKit zone name. 
        // SwiftData typically uses "com.apple.coredata.cloudkit.zone" for the default synced store.
        let zoneID = CKRecordZone.ID(zoneName: "com.apple.coredata.cloudkit.zone", ownerName: CKCurrentUserDefaultName)

        do {
            // This permanently deletes the zone and all records within it in the user's private database.
            try await database.deleteRecordZone(withID: zoneID)
        } catch let error as CKError {
            if let mappedError = Self.mapCloudDeleteError(error) {
                throw mappedError
            }
        } catch {
            if let mappedError = Self.mapCloudDeleteError(error) {
                throw mappedError
            }

            throw error
        }
    }

    @discardableResult
    nonisolated func quarantineDefaultStoreForRepair() throws -> URL? {
        try Self.quarantineDefaultStoreForRepair()
    }

    @discardableResult
    nonisolated static func quarantineDefaultStoreForRepair() throws -> URL? {
        try quarantineStoreForRepair(at: defaultStoreURL)
    }

    nonisolated func removeFallbackStoreFiles() throws {
        try Self.removeFallbackStoreFiles()
    }

    nonisolated static func removeFallbackStoreFiles() throws {
        try removeStoreFiles(at: fallbackStoreURL)
    }

    nonisolated static func ensureStoreParentDirectoryExists(
        for storeURL: URL,
        using fileManager: FileManager = .default
    ) throws {
        let parentDirectory = storeURL.deletingLastPathComponent()

        guard !fileManager.fileExists(atPath: parentDirectory.path) else {
            return
        }

        try fileManager.createDirectory(
            at: parentDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    nonisolated static func removeStoreFiles(at storeURL: URL, using fileManager: FileManager = .default) throws {
        let files = try relatedStoreFiles(for: storeURL, using: fileManager)
        for file in files {
            if fileManager.fileExists(atPath: file.path) {
                try fileManager.removeItem(at: file)
            }
        }
    }

    @discardableResult
    nonisolated static func quarantineStoreForRepair(
        at storeURL: URL,
        using fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> URL? {
        let files = try relatedStoreFiles(for: storeURL, using: fileManager)
        guard !files.isEmpty else { return nil }

        let quarantineDirectory = storeURL
            .deletingLastPathComponent()
            .appendingPathComponent("StoreRecovery", isDirectory: true)
            .appendingPathComponent(Self.recoveryFolderName(from: now), isDirectory: true)

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

    nonisolated static func relatedStoreFiles(for storeURL: URL, using fileManager: FileManager = .default) throws -> [URL] {
        let storeDirectory = storeURL.deletingLastPathComponent()
        guard fileManager.fileExists(atPath: storeDirectory.path) else {
            return []
        }

        let files = try fileManager.contentsOfDirectory(
            at: storeDirectory,
            includingPropertiesForKeys: nil
        )

        let allowedFileNames = storeFileNames(for: storeURL)
        return files.filter { allowedFileNames.contains($0.lastPathComponent) }
    }

    nonisolated static func mapCloudDeleteError(_ error: Error) -> Error? {
        guard let error = error as? CKError else { return error }

        switch error.code {
        case .zoneNotFound:
            return nil
        case .notAuthenticated:
            return DataResetError.iCloudAccountRequired
        case .networkUnavailable, .networkFailure, .serviceUnavailable:
            return DataResetError.networkUnavailable
        default:
            return error
        }
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

    private nonisolated static func storeFileNames(for storeURL: URL) -> Set<String> {
        let storeName = storeURL.lastPathComponent
        return [
            storeName,
            "\(storeName)-shm",
            "\(storeName)-wal"
        ]
    }
}
