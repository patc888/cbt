import Foundation
import SwiftData
import CloudKit
import CoreData
import SQLite3
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

struct StoreValidationError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

@Observable
final class DataResetManager {
    nonisolated static let shared = DataResetManager()
    private nonisolated static let logger = AppLogger.make(category: "DataReset")
    private nonisolated static let cloudSyncKey = "com.melichan.CBT.cloudSyncEnabled"
    private nonisolated static let pendingWipeKey = "com.melichan.CBT.pendingWipeOnLaunch"
    
    nonisolated static var isCloudSyncEnabled: Bool {
        get {
            // We default to false unless explicitly enabled
            if UserDefaults.standard.object(forKey: cloudSyncKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: cloudSyncKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: cloudSyncKey)
            logger.notice("Cloud sync preference changed to: \(newValue, privacy: .public)")
        }
    }

    nonisolated static var defaultStoreURL: URL {
        // Robustly define the store path to avoid potential crashes during 
        // early static initialization of ModelConfiguration().url on iOS.
        let fileManager = FileManager.default
        let appSupport: URL
        if let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            appSupport = url
        } else {
            // Fallback to documents directory if app support is missing (highly unlikely but safer than a trap)
            appSupport = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        }
        
        // We use "default.store" to match SwiftData's default naming convention
        // while ensuring the path is explicitly resolved.
        return appSupport.appendingPathComponent("default.store")
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

    nonisolated static func requestHardWipeOnNextLaunch() {
        UserDefaults.standard.set(true, forKey: pendingWipeKey)
        UserDefaults.standard.synchronize()
        logger.notice("Requested hard wipe on next launch.")
    }

    nonisolated static func performHardWipeIfNeeded() {
        guard UserDefaults.standard.bool(forKey: pendingWipeKey) else { return }
        
        logger.notice("Performing emergency hard wipe at launch...")
        
        do {
            try removeStoreFiles(at: defaultStoreURL)
            try removeStoreFiles(at: fallbackStoreURL)
            
            // Clear preferences as well
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
            }
            
            // Re-enable defaults but keep cloud sync disabled for safety
            UserDefaults.standard.set(false, forKey: cloudSyncKey)
            UserDefaults.standard.set(false, forKey: pendingWipeKey)
            UserDefaults.standard.synchronize()
            
            logger.notice("Emergency hard wipe completed successfully.")
        } catch {
            logger.error("Emergency hard wipe failed: \(error.localizedDescription, privacy: .public)")
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

        // Give SwiftData a slightly longer teardown window after the app switches 
        // back to the loading shell so the old container can release SQLite 
        // file handles cleanly. 
        try? await Task.sleep(for: .seconds(1))

        do {
            try Self.removeStoreFiles(at: Self.defaultStoreURL)
            try Self.removeStoreFiles(at: Self.fallbackStoreURL)
            
            // Verify deletion for logging
            let defaultExists = FileManager.default.fileExists(atPath: Self.defaultStoreURL.path)
            let fallbackExists = FileManager.default.fileExists(atPath: Self.fallbackStoreURL.path)
            
            if !defaultExists && !fallbackExists {
                Self.logger.info("Successfully cleared store files during local wipe.")
            } else {
                Self.logger.warning("Local wipe completed but some files may still exist. Default=\(defaultExists), Fallback=\(fallbackExists)")
            }
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

    nonisolated static func preflightStoreForLaunch(
        at storeURL: URL,
        using fileManager: FileManager = .default
    ) throws {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return
        }

        let attributes = try fileManager.attributesOfItem(atPath: storeURL.path)
        let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard fileSize > 0 else {
            throw StoreValidationError(message: "Store file is empty: \(storeURL.lastPathComponent)")
        }

        let sqliteHeader = Data("SQLite format 3\0".utf8)
        let headerData = try Data(contentsOf: storeURL, options: [.mappedIfSafe])
        guard headerData.count >= sqliteHeader.count else {
            throw StoreValidationError(message: "Store file is truncated: \(storeURL.lastPathComponent)")
        }
        guard headerData.prefix(sqliteHeader.count) == sqliteHeader else {
            throw StoreValidationError(message: "Store header is not SQLite: \(storeURL.lastPathComponent)")
        }

        try performSQLiteQuickCheck(at: storeURL)

        do {
            let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(
                ofType: NSSQLiteStoreType,
                at: storeURL,
                options: nil
            )
            guard !metadata.isEmpty else {
                throw StoreValidationError(message: "Store metadata is empty: \(storeURL.lastPathComponent)")
            }
        } catch let error as StoreValidationError {
            throw error
        } catch {
            throw StoreValidationError(
                message: "Core Data metadata check failed for \(storeURL.lastPathComponent): \(error.localizedDescription)"
            )
        }
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

    private nonisolated static func performSQLiteQuickCheck(at storeURL: URL) throws {
        var database: OpaquePointer?
        let openCode = sqlite3_open_v2(
            storeURL.path,
            &database,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX,
            nil
        )

        guard openCode == SQLITE_OK, let database else {
            let message = database.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown sqlite open failure"
            if let database {
                sqlite3_close(database)
            }
            throw StoreValidationError(
                message: "SQLite open failed for \(storeURL.lastPathComponent) code=\(openCode): \(message)"
            )
        }

        defer { sqlite3_close(database) }

        var statement: OpaquePointer?
        let sql = "PRAGMA quick_check(1);"
        let prepareCode = sqlite3_prepare_v2(database, sql, -1, &statement, nil)
        guard prepareCode == SQLITE_OK, let statement else {
            let message = String(cString: sqlite3_errmsg(database))
            if let statement {
                sqlite3_finalize(statement)
            }
            throw StoreValidationError(
                message: "SQLite quick_check prepare failed for \(storeURL.lastPathComponent) code=\(prepareCode): \(message)"
            )
        }

        defer { sqlite3_finalize(statement) }

        let stepCode = sqlite3_step(statement)
        switch stepCode {
        case SQLITE_ROW:
            let result = sqlite3_column_text(statement, 0).map { String(cString: $0) } ?? "unknown"
            guard result.caseInsensitiveCompare("ok") == .orderedSame else {
                throw StoreValidationError(
                    message: "SQLite quick_check failed for \(storeURL.lastPathComponent): \(result)"
                )
            }
        case SQLITE_DONE:
            break
        default:
            let message = String(cString: sqlite3_errmsg(database))
            throw StoreValidationError(
                message: "SQLite quick_check execution failed for \(storeURL.lastPathComponent) code=\(stepCode): \(message)"
            )
        }
    }
}
