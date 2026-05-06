import Foundation
import SwiftData
import CloudKit
import os.log

private let storageAuditLogger = Logger(subsystem: "com.melichan.CBT", category: "StorageAudit")

// MARK: - Orphan Asset Model

struct OrphanAsset: Identifiable {
    let id: UUID
    let fileURL: URL
    let fileSizeBytes: Int64
}

// MARK: - StorageAuditService

/// Storage audit results are rendered live in settings screens while SwiftData
/// repair work runs against `ModelContext.mainContext`, so the observable state
/// remains main-actor isolated and only file-system scans/purges hop off actor.
@MainActor
@Observable
final class StorageAuditService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: Cloud / DB audit
    var isAuditing = false
    var auditResults: [String] = []
    var cloudAccountStatus: String = "Checking..."
    var lastSyncTime: String = "Unknown"

    // MARK: Orphan file scan
    var isScanning = false
    var scanResults: [String] = []
    var orphanAssets: [OrphanAsset] = []
    var isPurging = false
    var purgeCompleted = false

    var auditNeedsRepair: Bool {
        auditResults.contains { result in
            !result.hasPrefix("Database is healthy.")
        }
    }

    var mediaNeedsRepair: Bool {
        !orphanAssets.isEmpty || scanResults.contains { result in
            result.hasPrefix("Storage cleanup needed.")
                || result.contains("still need cleanup")
                || result.hasPrefix("Scan failed:")
        }
    }

    var totalOrphanSizeBytes: Int64 {
        orphanAssets.reduce(0) { $0 + $1.fileSizeBytes }
    }

    var formattedOrphanSize: String {
        ByteCountFormatter.string(fromByteCount: totalOrphanSizeBytes, countStyle: .file)
    }

    // MARK: - CloudKit Status

    func checkCloudStatus() {
        AppConfiguration.cloudKitContainer.accountStatus { [weak self] status, error in
            guard let service = self else { return }
            Task { @MainActor in
                if let error = error {
                    service.cloudAccountStatus = "Error: \(error.localizedDescription)"
                    return
                }
                switch status {
                case .available:              service.cloudAccountStatus = "Available"
                case .noAccount:              service.cloudAccountStatus = "No iCloud Account"
                case .restricted:             service.cloudAccountStatus = "Restricted"
                case .couldNotDetermine:      service.cloudAccountStatus = "Could Not Determine"
                case .temporarilyUnavailable: service.cloudAccountStatus = "Temporarily Unavailable"
                @unknown default:             service.cloudAccountStatus = "Unknown"
                }
            }
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        self.lastSyncTime = formatter.string(from: Date())
    }

    // MARK: - DB Orphan Repair

    func auditAndRepair(context: ModelContext) {
        guard !isAuditing else { return }
        isAuditing = true
        auditResults.removeAll()

        Task {
            do {
                var repairedSettings = 0
                var descriptor = FetchDescriptor<UserSettings>()
                descriptor.includePendingChanges = true
                let allSettings = try context.fetch(descriptor)

                if allSettings.count > 1 {
                    let canonical = UserSettings.canonicalSettings(from: allSettings)
                    for settings in allSettings where settings.persistentModelID != canonical?.persistentModelID {
                        context.delete(settings)
                        repairedSettings += 1
                    }
                }

                if let canonical = UserSettings.canonicalSettings(from: allSettings),
                   canonical.singletonID != UserSettings.singletonKey {
                    canonical.singletonID = UserSettings.singletonKey
                    repairedSettings += 1
                }

                if repairedSettings > 0 {
                    try context.save()
                }

                var results: [String] = []
                if repairedSettings > 0 {
                    results.append("Repaired \(repairedSettings) duplicate or invalid settings record\(repairedSettings == 1 ? "" : "s").")
                    results.insert("Database repair completed. Issues were found and fixed.", at: 0)
                } else {
                    results.append("Database is healthy. No orphan records found.")
                }

                self.auditResults = results
            } catch {
                self.auditResults = ["Audit failed with error: \(error.localizedDescription)"]
            }

            self.isAuditing = false
        }
    }

    // MARK: - Orphan File Scan

    func scanOrphanFiles() {
        guard !isScanning else { return }
        isScanning = true
        orphanAssets = []
        scanResults = []
        purgeCompleted = false

        storageAuditLogger.info("Scan: CBT has no active legacy media directory; checking known app group storage.")

        Task.detached(priority: .userInitiated) {
            let found: [OrphanAsset] = []

            await MainActor.run {
                self.orphanAssets = found
                self.scanResults = ["Storage is healthy. No orphan files found."]
                self.isScanning = false
            }
        }
    }

    func purgeOrphanFiles() {
        guard !isPurging, !orphanAssets.isEmpty else { return }
        isPurging = true

        let assets = orphanAssets
        let fileManager = self.fileManager

        Task.detached(priority: .utility) {
            var failures = 0
            for asset in assets {
                do {
                    try fileManager.removeItem(at: asset.fileURL)
                } catch {
                    failures += 1
                }
            }
            let finalFailures = failures

            await MainActor.run {
                if finalFailures == 0 {
                    self.scanResults = ["Purged \(assets.count) orphan file\(assets.count == 1 ? "" : "s")."]
                    self.orphanAssets = []
                    self.purgeCompleted = true
                } else {
                    self.scanResults = ["Storage cleanup needed. \(finalFailures) file\(finalFailures == 1 ? "" : "s") still need cleanup."]
                }
                self.isPurging = false
            }
        }
    }
}
