import Foundation
import SwiftData
import CloudKit
import CoreData
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
    private let syncMonitor: CloudKitSyncMonitor

    init(fileManager: FileManager = .default, syncMonitor: CloudKitSyncMonitor? = nil) {
        self.fileManager = fileManager
        self.syncMonitor = syncMonitor ?? .shared
    }

    // MARK: Cloud / DB audit
    var isAuditing = false
    var isCheckingSync = false
    var auditResults: [String] = []
    var syncAuditResults: [String] = []
    var cloudAccountStatus: String = "Checking..."
    var cloudKitReachabilityStatus: String = "Not checked"
    var lastCloudKitEventSummary: String {
        syncMonitor.lastEventSummary
    }
    var persistenceMode: String = "Checking..."
    var cloudKitFallbackReason: String = ""
    var cloudKitRecoveryMessage: String = ""
    var lastSyncTime: String = "Unknown"

    // MARK: Orphan file scan
    var isScanning = false
    var scanResults: [String] = []
    var orphanAssets: [OrphanAsset] = []
    var isPurging = false
    var purgeCompleted = false

    var auditNeedsRepair: Bool {
        auditResults.contains { result in
            result.hasPrefix("Repaired")
                || result.hasPrefix("Found")
                || result.hasPrefix("Audit failed")
                || result.contains("duplicate")
        }
    }

    var syncNeedsAttention: Bool {
        syncAuditResults.contains { result in
            result.hasPrefix("Issue:")
                || result.hasPrefix("CloudKit private database error")
                || result.hasPrefix("Using local fallback")
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
        refreshPersistenceStatus()

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

    func auditSyncHealth(context: ModelContext) {
        guard !isCheckingSync else { return }
        isCheckingSync = true
        syncAuditResults.removeAll()

        Task {
            refreshPersistenceStatus()

            var results: [String] = []
            results.append("Storage mode: \(persistenceMode)")

            if persistenceMode != "CloudKit" {
                let reason = cloudKitFallbackReason.isEmpty ? "CloudKit is not active for this launch." : cloudKitFallbackReason
                results.append("Using local fallback: \(reason)")
            }

            let reachability = await checkPrivateDatabaseReachability()
            cloudKitReachabilityStatus = reachability
            results.append(reachability)
            results.append(contentsOf: localRecordInventoryResults(context: context))
            results.append("Latest sync event: \(lastCloudKitEventSummary)")

            if lastCloudKitEventSummary.hasPrefix("No SwiftData CloudKit events") {
                results.append("Issue: No SwiftData CloudKit import/export event has been observed during this launch. Create or edit a record, then refresh this audit to confirm export activity.")
            }

            syncAuditResults = results
            isCheckingSync = false
        }
    }

    private func refreshPersistenceStatus() {
        let defaults = UserDefaults.standard
        let isCloudKitEnabled = defaults.bool(forKey: AppConfiguration.cloudKitEnabledKey)
        let mode = defaults.string(forKey: AppConfiguration.persistenceModeKey)

        if isCloudKitEnabled || mode == "cloudKit" {
            persistenceMode = "CloudKit"
        } else {
            persistenceMode = "Local Fallback"
        }

        cloudKitFallbackReason = defaults.string(forKey: AppConfiguration.cloudKitFailureReasonKey) ?? ""
        cloudKitRecoveryMessage = defaults.string(forKey: AppConfiguration.cloudKitRecoveryMessageKey) ?? ""
    }

    private func checkPrivateDatabaseReachability() async -> String {
        await withCheckedContinuation { continuation in
            AppConfiguration.cloudKitContainer.privateCloudDatabase.fetchAllRecordZones { zones, error in
                if let error {
                    continuation.resume(returning: "CloudKit private database error: \(error.localizedDescription)")
                } else {
                    continuation.resume(returning: "CloudKit private database reachable. Zones visible: \(zones?.count ?? 0).")
                }
            }
        }
    }

    private func localRecordInventoryResults(context: ModelContext) -> [String] {
        do {
            let moodEntries = try context.fetch(FetchDescriptor<MoodEntry>())
            let thoughtRecords = try context.fetch(FetchDescriptor<ThoughtRecord>())
            let completions = try context.fetch(FetchDescriptor<ExerciseCompletion>())
            let journalEntries = try context.fetch(FetchDescriptor<JournalEntry>())
            let plannedActivities = try context.fetch(FetchDescriptor<PlannedActivity>())
            let assessmentLogs = try context.fetch(FetchDescriptor<AssessmentLog>())
            let personalityLogs = try context.fetch(FetchDescriptor<PersonalityAssessmentLog>())
            let programProgresses = try context.fetch(FetchDescriptor<ProgramProgress>())
            let flexibleJournalEntries = try context.fetch(FetchDescriptor<FlexibleJournalEntry>())
            let moodCheckIns = try context.fetch(FetchDescriptor<MoodCheckIn>())
            let breathingSessions = try context.fetch(FetchDescriptor<BreathingSession>())
            let safetyPlans = try context.fetch(FetchDescriptor<SafetyPlan>())
            let settings = try context.fetch(FetchDescriptor<UserSettings>())

            var results = [
                activeCountLine("Mood entries", records: moodEntries),
                activeCountLine("Thought records", records: thoughtRecords),
                activeCountLine("Exercise completions", records: completions),
                activeCountLine("Journal entries", records: journalEntries),
                activeCountLine("Planned activities", records: plannedActivities),
                "Assessment logs: \(assessmentLogs.count)",
                "Personality assessment logs: \(personalityLogs.count)",
                activeCountLine("Program progress", records: programProgresses),
                "Flexible journal entries: \(flexibleJournalEntries.count)",
                activeCountLine("Mood check-ins", records: moodCheckIns),
                activeCountLine("Breathing sessions", records: breathingSessions),
                "Safety plans: \(safetyPlans.count)",
                "User settings records: \(settings.count)"
            ]

            appendDuplicateIDCheck("Mood entries", ids: moodEntries.map(\.id), to: &results)
            appendDuplicateIDCheck("Thought records", ids: thoughtRecords.map(\.id), to: &results)
            appendDuplicateIDCheck("Exercise completions", ids: completions.map(\.id), to: &results)
            appendDuplicateIDCheck("Journal entries", ids: journalEntries.map(\.id), to: &results)
            appendDuplicateIDCheck("Planned activities", ids: plannedActivities.map(\.id), to: &results)
            appendDuplicateIDCheck("Assessment logs", ids: assessmentLogs.map(\.id), to: &results)
            appendDuplicateIDCheck("Personality assessment logs", ids: personalityLogs.map(\.id), to: &results)
            appendDuplicateIDCheck("Program progress", ids: programProgresses.map(\.id), to: &results)
            appendDuplicateIDCheck("Flexible journal entries", ids: flexibleJournalEntries.map(\.id), to: &results)
            appendDuplicateIDCheck("Mood check-ins", ids: moodCheckIns.map(\.id), to: &results)
            appendDuplicateIDCheck("Breathing sessions", ids: breathingSessions.map(\.id), to: &results)
            appendDuplicateIDCheck("Safety plans", ids: safetyPlans.map(\.id), to: &results)

            if settings.count > 1 {
                results.append("Issue: Found \(settings.count) UserSettings records. Run database repair to collapse duplicates.")
            }

            return results
        } catch {
            return ["Issue: Could not inspect local synced records: \(error.localizedDescription)"]
        }
    }

    private func activeCountLine<Record: SoftDeletableRecord>(_ label: String, records: [Record]) -> String {
        let activeCount = records.filter { !$0.isDeleted }.count
        return "\(label): \(activeCount) active / \(records.count) total"
    }

    private func appendDuplicateIDCheck(_ label: String, ids: [UUID], to results: inout [String]) {
        let duplicateCount = ids.count - Set(ids).count
        if duplicateCount > 0 {
            results.append("Issue: \(label) contains \(duplicateCount) duplicate id value\(duplicateCount == 1 ? "" : "s").")
        }
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
