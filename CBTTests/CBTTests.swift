//
//  CBTTests.swift
//  CBTTests
//
//  Created by Melissa Chan on 3/4/26.
//

import Testing
import Foundation
import SwiftData
import CloudKit
import SwiftUI
@testable import CBT

struct CBTTests {

    @Test func durationFormattingUsesCompactSessionLabels() {
        #expect(DurationFormatting.sessionLabel(seconds: 0) == "0s")
        #expect(DurationFormatting.sessionLabel(seconds: 45) == "45s")
        #expect(DurationFormatting.sessionLabel(seconds: 90) == "1m 30s")
        #expect(DurationFormatting.sessionLabel(seconds: 120) == "2m")
    }

    @Test func journalEntryBuildsSessionMetadataLine() {
        let entry = JournalEntry(
            title: "Reset",
            body: "Body",
            sourceKind: SessionSourceKind.breathing.rawValue,
            sourceID: "breathing-1",
            durationSeconds: 90
        )

        #expect(entry.sessionSourceKind == .breathing)
        #expect(entry.durationLabel == "1m 30s")
        #expect(entry.sessionMetadataLine == "Breathing • 1m 30s")
    }

    @Test func moodEntryBackupRoundTripPreservesTriggersAndIntensity() throws {
        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = ModelContext(sourceContainer)
        let createdAt = Date(timeIntervalSince1970: 1_234_567)
        let moodID = UUID()
        let entry = MoodEntry(
            id: moodID,
            createdAt: createdAt,
            moodScore: 8,
            emotions: ["hopeful", "calm"],
            triggers: ["work", "sleep"],
            notes: "Feeling steadier",
            intensity: 7
        )
        sourceContext.insert(entry)
        try sourceContext.save()

        let exportURL = try DataExportService().exportDataFileURL(from: sourceContext)
        let payloadData = try Data(contentsOf: exportURL)
        let exportedPayload = try JSONDecoder().decode(CBTDataExportPayload.self, from: payloadData)
        let exportedEntry = try #require(exportedPayload.moodEntries.first)

        #expect(exportedEntry.id == moodID)
        #expect(exportedEntry.triggers == ["work", "sleep"])
        #expect(exportedEntry.intensity == 7)

        let restoredContainer = try makeInMemoryContainer()
        let restoredContext = ModelContext(restoredContainer)
        try DataImportService().importData(from: exportURL, into: restoredContext)

        let restoredEntries = try restoredContext.fetch(
            FetchDescriptor<MoodEntry>(sortBy: [SortDescriptor(\MoodEntry.createdAt)])
        )
        let restoredEntry = try #require(restoredEntries.first)

        #expect(restoredEntry.id == moodID)
        #expect(restoredEntry.createdAt == createdAt)
        #expect(restoredEntry.emotions == ["hopeful", "calm"])
        #expect(restoredEntry.triggers == ["work", "sleep"])
        #expect(restoredEntry.notes == "Feeling steadier")
        #expect(restoredEntry.intensity == 7)
    }

    @Test func legacyMoodEntryBackupWithoutNewFieldsStillImports() throws {
        let payload = """
        {
          "appVersion" : "1.0",
          "exerciseCompletions" : [],
          "exportedAt" : "2026-04-02T00:00:00Z",
          "moodEntries" : [
            {
              "createdAt" : 1234567,
              "emotions" : ["sad"],
              "id" : "11111111-1111-1111-1111-111111111111",
              "moodScore" : 3,
              "notes" : "Legacy backup"
            }
          ],
          "thoughtRecords" : []
        }
        """

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("legacy-mood-backup-\(UUID().uuidString).json")
        try payload.data(using: .utf8).map { try $0.write(to: url) }

        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        try DataImportService().importData(from: url, into: context)

        let entries = try context.fetch(FetchDescriptor<MoodEntry>())
        let entry = try #require(entries.first)

        #expect(entry.moodScore == 3)
        #expect(entry.emotions == ["sad"])
        #expect(entry.triggers.isEmpty)
        #expect(entry.intensity == nil)
        #expect(entry.notes == "Legacy backup")
    }

    @Test func importRestoresExistingRecordsWithMatchingIDs() throws {
        let sharedMoodID = UUID()
        let sharedThoughtID = UUID()
        let sharedCompletionID = UUID()
        let sharedJournalID = UUID()

        let backupContainer = try makeInMemoryContainer()
        let backupContext = ModelContext(backupContainer)
        backupContext.insert(
            MoodEntry(
                id: sharedMoodID,
                createdAt: Date(timeIntervalSince1970: 1_000),
                moodScore: 2,
                emotions: ["sad"],
                triggers: ["weather"],
                notes: "From backup",
                intensity: 3
            )
        )
        backupContext.insert(
            ThoughtRecord(
                id: sharedThoughtID,
                createdAt: Date(timeIntervalSince1970: 2_000),
                situation: "Backup situation",
                automaticThought: "Backup thought",
                emotions: ["anxious"],
                distortions: ["fortune telling"],
                evidenceFor: "Backup for",
                evidenceAgainst: "Backup against",
                balancedThought: "Backup balanced",
                intensityBefore: 85,
                intensityAfter: 25
            )
        )
        backupContext.insert(
            ExerciseCompletion(
                id: sharedCompletionID,
                createdAt: Date(timeIntervalSince1970: 3_000),
                exerciseID: "backup-exercise",
                notes: "Backup completion"
            )
        )
        backupContext.insert(
            JournalEntry(
                id: sharedJournalID,
                createdAt: Date(timeIntervalSince1970: 4_000),
                title: "Backup title",
                body: "Backup body",
                sourceKind: SessionSourceKind.breathing.rawValue,
                sourceID: "backup-session",
                durationSeconds: 150
            )
        )
        try backupContext.save()

        let backupURL = try DataExportService().exportDataFileURL(from: backupContext)

        let restoreContainer = try makeInMemoryContainer()
        let restoreContext = ModelContext(restoreContainer)

        let existingMood = MoodEntry(
            id: sharedMoodID,
            createdAt: Date(timeIntervalSince1970: 10),
            moodScore: 9,
            emotions: ["hopeful"],
            triggers: ["work"],
            notes: "Local mood",
            intensity: 9
        )
        let existingThought = ThoughtRecord(
            id: sharedThoughtID,
            createdAt: Date(timeIntervalSince1970: 20),
            situation: "Local situation",
            automaticThought: "Local thought",
            emotions: ["confident"],
            distortions: ["all-or-nothing"],
            evidenceFor: "Local for",
            evidenceAgainst: "Local against",
            balancedThought: "Local balanced",
            intensityBefore: 10,
            intensityAfter: 5
        )
        let existingCompletion = ExerciseCompletion(
            id: sharedCompletionID,
            createdAt: Date(timeIntervalSince1970: 30),
            exerciseID: "local-exercise",
            notes: "Local completion"
        )
        let existingJournal = JournalEntry(
            id: sharedJournalID,
            createdAt: Date(timeIntervalSince1970: 40),
            title: "Local title",
            body: "Local body",
            sourceKind: SessionSourceKind.exercise.rawValue,
            sourceID: "local-session",
            durationSeconds: 30
        )

        restoreContext.insert(existingMood)
        restoreContext.insert(existingThought)
        restoreContext.insert(existingCompletion)
        restoreContext.insert(existingJournal)
        try restoreContext.save()

        try DataImportService().importData(from: backupURL, into: restoreContext)

        let restoredMood = try #require(try restoreContext.fetch(FetchDescriptor<MoodEntry>()).first)
        #expect(restoredMood.id == sharedMoodID)
        #expect(restoredMood.createdAt == Date(timeIntervalSince1970: 1_000))
        #expect(restoredMood.moodScore == 2)
        #expect(restoredMood.emotions == ["sad"])
        #expect(restoredMood.triggers == ["weather"])
        #expect(restoredMood.notes == "From backup")
        #expect(restoredMood.intensity == 3)
        #expect(restoredMood.isDeleted == false)

        let restoredThought = try #require(try restoreContext.fetch(FetchDescriptor<ThoughtRecord>()).first)
        #expect(restoredThought.id == sharedThoughtID)
        #expect(restoredThought.createdAt == Date(timeIntervalSince1970: 2_000))
        #expect(restoredThought.situation == "Backup situation")
        #expect(restoredThought.automaticThought == "Backup thought")
        #expect(restoredThought.emotions == ["anxious"])
        #expect(restoredThought.distortions == ["fortune telling"])
        #expect(restoredThought.evidenceFor == "Backup for")
        #expect(restoredThought.evidenceAgainst == "Backup against")
        #expect(restoredThought.balancedThought == "Backup balanced")
        #expect(restoredThought.intensityBefore == 85)
        #expect(restoredThought.intensityAfter == 25)
        #expect(restoredThought.isDeleted == false)

        let restoredCompletion = try #require(try restoreContext.fetch(FetchDescriptor<ExerciseCompletion>()).first)
        #expect(restoredCompletion.id == sharedCompletionID)
        #expect(restoredCompletion.createdAt == Date(timeIntervalSince1970: 3_000))
        #expect(restoredCompletion.exerciseID == "backup-exercise")
        #expect(restoredCompletion.notes == "Backup completion")
        #expect(restoredCompletion.isDeleted == false)

        let restoredJournal = try #require(try restoreContext.fetch(FetchDescriptor<JournalEntry>()).first)
        #expect(restoredJournal.id == sharedJournalID)
        #expect(restoredJournal.createdAt == Date(timeIntervalSince1970: 4_000))
        #expect(restoredJournal.title == "Backup title")
        #expect(restoredJournal.body == "Backup body")
        #expect(restoredJournal.sourceKind == SessionSourceKind.breathing.rawValue)
        #expect(restoredJournal.sourceID == "backup-session")
        #expect(restoredJournal.durationSeconds == 150)
        #expect(restoredJournal.isDeleted == false)
    }

    @Test func softDeletedRecordsAreExcludedFromExportPayload() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        let mood = MoodEntry(
            createdAt: Date(timeIntervalSince1970: 101),
            moodScore: 9,
            emotions: ["calm"],
            triggers: ["sleep"],
            notes: "Deleted mood",
            intensity: 6
        )
        let thought = ThoughtRecord(
            createdAt: Date(timeIntervalSince1970: 202),
            situation: "Meeting",
            automaticThought: "I will mess this up",
            emotions: ["anxious"],
            distortions: ["fortune telling"],
            evidenceFor: "I am nervous",
            evidenceAgainst: "I prepared",
            balancedThought: "I can handle this",
            intensityBefore: 80,
            intensityAfter: 35
        )
        let completion = ExerciseCompletion(
            createdAt: Date(timeIntervalSince1970: 303),
            exerciseID: "breathing-reset",
            notes: "Deleted completion"
        )
        let journal = JournalEntry(
            createdAt: Date(timeIntervalSince1970: 404),
            title: "Deleted journal",
            body: "Backup contents",
            sourceKind: SessionSourceKind.breathing.rawValue,
            sourceID: "session-1",
            durationSeconds: 120
        )

        context.insert(mood)
        context.insert(thought)
        context.insert(completion)
        context.insert(journal)
        try context.save()

        try context.cbtStore.softDelete(item: mood)
        try context.cbtStore.softDelete(item: thought)
        try context.cbtStore.softDelete(item: completion)
        try context.cbtStore.softDelete(item: journal)

        let exportURL = try DataExportService().exportDataFileURL(from: context)
        let payload = try JSONDecoder().decode(
            CBTDataExportPayload.self,
            from: Data(contentsOf: exportURL)
        )

        #expect(payload.moodEntries.isEmpty)
        #expect(payload.thoughtRecords.isEmpty)
        #expect(payload.exerciseCompletions.isEmpty)
        #expect(payload.journalEntries?.isEmpty == true)
    }

    @Test func quarantineStoreForRepairMovesRelatedFilesIntoRecoveryDirectory() throws {
        let directory = try makeTemporaryDirectory()
        let storeURL = directory.appendingPathComponent("cbt.store")
        let relatedFiles = [
            storeURL,
            directory.appendingPathComponent("cbt.store-shm"),
            directory.appendingPathComponent("cbt.store-wal")
        ]
        let unrelatedFiles = [
            directory.appendingPathComponent("notes.txt"),
            directory.appendingPathComponent("cbt.store.backup"),
            directory.appendingPathComponent("cbt.store-copy")
        ]

        for file in relatedFiles + unrelatedFiles {
            try Data("test".utf8).write(to: file)
        }

        let quarantineDirectory = try DataResetManager.quarantineStoreForRepair(
            at: storeURL,
            now: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let quarantineURL = try #require(quarantineDirectory)

        for file in relatedFiles {
            #expect(FileManager.default.fileExists(atPath: file.path) == false)
            #expect(
                FileManager.default.fileExists(
                    atPath: quarantineURL.appendingPathComponent(file.lastPathComponent).path
                )
            )
        }

        for file in unrelatedFiles {
            #expect(FileManager.default.fileExists(atPath: file.path))
            #expect(
                FileManager.default.fileExists(
                    atPath: quarantineURL.appendingPathComponent(file.lastPathComponent).path
                ) == false
            )
        }
        #expect(quarantineURL.lastPathComponent.hasPrefix("repair-2023-11-14-"))
    }

    @Test func removeStoreFilesDeletesOnlyMatchingStoreSidecars() throws {
        let directory = try makeTemporaryDirectory()
        let storeURL = directory.appendingPathComponent("cbt.store")
        let relatedFiles = [
            storeURL,
            directory.appendingPathComponent("cbt.store-shm"),
            directory.appendingPathComponent("cbt.store-wal")
        ]
        let unrelatedFiles = [
            directory.appendingPathComponent("cbt-backup.store"),
            directory.appendingPathComponent("cbt.store.backup"),
            directory.appendingPathComponent("cbt.store-copy")
        ]

        for file in relatedFiles + unrelatedFiles {
            try Data("test".utf8).write(to: file)
        }

        try DataResetManager.removeStoreFiles(at: storeURL)

        for file in relatedFiles {
            #expect(FileManager.default.fileExists(atPath: file.path) == false)
        }

        for file in unrelatedFiles {
            #expect(FileManager.default.fileExists(atPath: file.path))
        }
    }

    @MainActor
    @Test func requestLocalWipePostsResetNotification() async throws {
        let manager = DataResetManager()

        let notification = await withCheckedContinuation { continuation in
            var observer: NSObjectProtocol?
            observer = NotificationCenter.default.addObserver(
                forName: .requestDataReset,
                object: nil,
                queue: nil
            ) { notification in
                if let observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                continuation.resume(returning: notification)
            }

            manager.requestLocalWipe()
        }

        #expect(notification.name == .requestDataReset)
    }

    @Test func cloudDeleteErrorMappingTreatsZoneNotFoundAsSuccessAndMapsKnownFailures() throws {
        #expect(DataResetManager.mapCloudDeleteError(CKError(.zoneNotFound)) == nil)

        let authError = try #require(
            DataResetManager.mapCloudDeleteError(CKError(.notAuthenticated)) as? DataResetError
        )
        #expect(authError == .iCloudAccountRequired)

        let networkError = try #require(
            DataResetManager.mapCloudDeleteError(CKError(.networkFailure)) as? DataResetError
        )
        #expect(networkError == .networkUnavailable)

        let unknownError = try #require(
            DataResetManager.mapCloudDeleteError(CKError(.internalError)) as? CKError
        )
        #expect(unknownError.code == .internalError)
    }

    @Test func bootstrapFlowRetriesRecoveredPrimaryBeforeFallingBack() throws {
        var attemptedStages = [CBTApp.BootstrapStage]()
        var quarantined = false
        var removedFallbackStore = false

        let result = CBTApp.runBootstrapFlow(
            reason: "unit-test",
            actions: CBTApp.BootstrapActions<String>(
                makePrimary: { stage in
                    attemptedStages.append(stage)
                    if stage == .primary {
                        throw TestFailure.simulated
                    }

                    return stage.rawValue
                },
                quarantineDefaultStoreForRepair: {
                    quarantined = true
                    return URL(fileURLWithPath: "/tmp/recovered")
                },
                removeFallbackStoreFiles: {
                    removedFallbackStore = true
                },
                makeFallback: { "fallback" },
                makeInMemory: { "memory" },
                logBootstrapFailure: { _, _, _ in },
                logHousekeepingFailure: { _, _ in },
                logFallbackLaunch: { },
                logInMemoryLaunch: { }
            )
        )

        switch result {
        case .ready(let resource, let resolution):
            #expect(resource == CBTApp.BootstrapStage.primaryRecovery.rawValue)
            switch resolution {
            case .primaryRecovery:
                break
            default:
                Issue.record("Expected primary recovery resolution, got \(String(describing: resolution))")
            }
        case .repair:
            Issue.record("Expected primary recovery bootstrap to succeed")
        }

        #expect(attemptedStages == [.primary, .primaryRecovery])
        #expect(quarantined)
        #expect(removedFallbackStore == false)
    }

    @Test func bootstrapFlowFallsBackToInMemoryAfterPersistentStoreFailures() throws {
        var removedFallbackStore = false
        var launchedFallback = false
        var launchedInMemory = false

        let result = CBTApp.runBootstrapFlow(
            reason: "unit-test",
            actions: CBTApp.BootstrapActions<String>(
                makePrimary: { _ in throw TestFailure.simulated },
                quarantineDefaultStoreForRepair: { nil },
                removeFallbackStoreFiles: {
                    removedFallbackStore = true
                },
                makeFallback: {
                    launchedFallback = true
                    throw TestFailure.simulated
                },
                makeInMemory: {
                    launchedInMemory = true
                    return "memory"
                },
                logBootstrapFailure: { _, _, _ in },
                logHousekeepingFailure: { _, _ in },
                logFallbackLaunch: { },
                logInMemoryLaunch: { }
            )
        )

        switch result {
        case .ready(let resource, let resolution):
            #expect(resource == "memory")
            switch resolution {
            case .inMemory:
                break
            default:
                Issue.record("Expected in-memory resolution, got \(String(describing: resolution))")
            }
        case .repair:
            Issue.record("Expected in-memory recovery bootstrap to succeed")
        }

        #expect(removedFallbackStore)
        #expect(launchedFallback)
        #expect(launchedInMemory)
    }

    @Test func lockCheckDecisionRelocksOnlyWhenAppBecomesActiveAndReady() {
        let backgroundDecision = CBTApp.lockCheckDecision(
            for: .background,
            shouldCheckLockOnNextActive: false,
            isReady: true
        )
        #expect(backgroundDecision.nextShouldCheckLockOnNextActive)
        switch backgroundDecision.action {
        case .none:
            break
        case .authenticate:
            Issue.record("Background transition should not authenticate")
        }

        let activeReadyDecision = CBTApp.lockCheckDecision(
            for: .active,
            shouldCheckLockOnNextActive: true,
            isReady: true
        )
        #expect(activeReadyDecision.nextShouldCheckLockOnNextActive == false)
        switch activeReadyDecision.action {
        case .authenticate:
            break
        case .none:
            Issue.record("Ready active transition should authenticate")
        }

        let activeNotReadyDecision = CBTApp.lockCheckDecision(
            for: .active,
            shouldCheckLockOnNextActive: true,
            isReady: false
        )
        #expect(activeNotReadyDecision.nextShouldCheckLockOnNextActive)
        switch activeNotReadyDecision.action {
        case .none:
            break
        case .authenticate:
            Issue.record("Inactive bootstrap state should not authenticate")
        }
    }

    @Test func loadAppLockEnabledReadsPersistedSetting() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(UserSettings(hapticsEnabled: true, appLockEnabled: true))
        try context.save()

        let isEnabled = await CBTApp.loadAppLockEnabled(from: container)

        #expect(isEnabled)
    }

    @Test func loadEnforceableAppLockEnabledDisablesUnavailableLock() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        context.insert(UserSettings(hapticsEnabled: true, appLockEnabled: true))
        try context.save()

        let isEnabled = await CBTApp.loadEnforceableAppLockEnabled(
            from: container,
            isAppLockAvailable: false
        )

        #expect(isEnabled == false)
        #expect(try UserSettings.fetchAppLockEnabled(from: context) == false)
    }

}

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([
        UserSettings.self,
        MoodEntry.self,
        ThoughtRecord.self,
        ExerciseCompletion.self,
        JournalEntry.self
    ])
    let configuration = ModelConfiguration(
        "Tests-\(UUID().uuidString)",
        schema: schema,
        isStoredInMemoryOnly: true
    )
    return try ModelContainer(for: schema, configurations: [configuration])
}

private func makeTemporaryDirectory() throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

private enum TestFailure: Error {
    case simulated
}
