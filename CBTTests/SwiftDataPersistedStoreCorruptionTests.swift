//
//  SwiftDataPersistedStoreCorruptionTests.swift
//  CBTTests
//
//  Reproduces the *class* of failure seen in the App Store crash: SwiftData work on the
//  main `NSManagedObjectContext` queue during view refresh (`_SwiftData_SwiftUI` in the
//  stack) after opening a damaged on-disk store. The field report was `EXC_BREAKPOINT`
//  in `_assertionFailure` inside SwiftData — a hard trap, not always a thrown `Error`.
//
//  - The first test is safe for CI: random bytes at the primary URL must fail `ModelContainer` init.
//  - The second test corrupts a real seeded store, then expects a thrown error from open **or**
//    from the same `FetchDescriptor` pattern used in `InsightsView` / `TimelineView` (mirrors `@Query`).
//    If your OS/runtime instead **traps**, the test process will stop in the debugger — that is still
//    a successful local reproduction of the production condition.
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import CBT

// MARK: - SwiftUI probe (crash stack included `_SwiftData_SwiftUI`)

private struct MoodQueryProbeView: View {
    @Query(
        filter: #Predicate<MoodEntry> { $0.isDeleted == false },
        sort: \MoodEntry.createdAt,
        order: .forward
    )
    private var moods: [MoodEntry]

    var body: some View {
        Text(verbatim: "\(moods.count)")
            .accessibilityHidden(true)
    }
}

@MainActor
private enum SwiftDataCrashReproductionFixtures {
    static let cbtSchema = Schema([
        UserSettings.self,
        MoodEntry.self,
        ThoughtRecord.self,
        ExerciseCompletion.self,
        JournalEntry.self
    ])

    static func makeUniqueStoreDirectory() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("CBT-SwiftData-Repro", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Same shape as `CBTApp.makePrimaryContainer`: named store on disk, no CloudKit.
    static func makePrimaryConfiguration(url storeURL: URL) -> ModelConfiguration {
        ModelConfiguration(
            "PrimaryLocalStore",
            schema: cbtSchema,
            url: storeURL,
            cloudKitDatabase: .none
        )
    }

    static func seedFreshStore(storeURL: URL) throws {
        let configuration = makePrimaryConfiguration(url: storeURL)
        let container = try ModelContainer(for: cbtSchema, configurations: [configuration])
        let context = ModelContext(container)
        context.insert(MoodEntry(moodScore: 5))
        try context.save()
    }

    static func overwriteStoreInteriorWithNoise(at storeURL: URL) throws {
        let handle = try FileHandle(forUpdating: storeURL)
        defer { try? handle.close() }
        let length = try handle.seekToEnd()
        guard length > 8192 else { return }
        try handle.seek(toOffset: 8192)
        try handle.write(contentsOf: Data(repeating: 0xAD, count: 2048))
    }

    static func truncateStoreToBreakMetadata(at storeURL: URL) throws {
        var data = try Data(contentsOf: storeURL)
        let truncated = data.prefix(220)
        try truncated.write(to: storeURL, options: .atomic)
    }

    static func removeSQLiteSidecarFilesIfPresent(storeURL: URL) {
        let fm = FileManager.default
        let dir = storeURL.deletingLastPathComponent()
        let baseName = storeURL.lastPathComponent
        for suffix in ["-wal", "-shm"] {
            let url = dir.appendingPathComponent(baseName + suffix)
            try? fm.removeItem(at: url)
        }
    }

    /// Mirrors `@Query` usage in `InsightsDashboardContent` / timeline screens.
    static func exerciseProductionStyleMainContextFetches(on context: ModelContext) throws {
        let moodDesc = FetchDescriptor<MoodEntry>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\MoodEntry.createdAt, order: .forward)]
        )
        _ = try context.fetch(moodDesc)

        let thoughtDesc = FetchDescriptor<ThoughtRecord>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\ThoughtRecord.createdAt, order: .forward)]
        )
        _ = try context.fetch(thoughtDesc)

        let completionDesc = FetchDescriptor<ExerciseCompletion>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\ExerciseCompletion.createdAt, order: .forward)]
        )
        _ = try context.fetch(completionDesc)

        let journalDesc = FetchDescriptor<JournalEntry>(
            predicate: #Predicate { $0.isDeleted == false },
            sortBy: [SortDescriptor(\JournalEntry.createdAt, order: .forward)]
        )
        _ = try context.fetch(journalDesc)
    }

    /// Exercises `_SwiftData_SwiftUI` + `performAndWait` stack similar to the layout-time crash.
    static func renderMoodQueryProbe(modelContainer: ModelContainer) {
        let probe = MoodQueryProbeView()
            .modelContainer(modelContainer)
        let renderer = ImageRenderer(content: probe)
        renderer.proposedSize = ProposedViewSize(width: 120, height: 44)
        #if canImport(UIKit)
        renderer.scale = 1.0
        _ = renderer.uiImage
        #elseif canImport(AppKit)
        _ = renderer.nsImage
        #endif
    }
}

struct SwiftDataPersistedStoreCorruptionTests {

    @Test @MainActor
    func swiftDataRejectsRandomBytesAtPrimaryStoreURL() throws {
        let dir = try SwiftDataCrashReproductionFixtures.makeUniqueStoreDirectory()
        let storeURL = dir.appendingPathComponent("PrimaryLocalStore.store")
        try Data(repeating: 0xCB, count: 4096).write(to: storeURL)

        let configuration = SwiftDataCrashReproductionFixtures.makePrimaryConfiguration(url: storeURL)

        #expect(throws: (any Error).self) {
            _ = try ModelContainer(
                for: SwiftDataCrashReproductionFixtures.cbtSchema,
                configurations: [configuration]
            )
        }
    }

    @Test @MainActor
    func swiftDataCorruptedSeededStoreFailsOpenOrQueryLikeProductionInsightsTimeline() throws {
        let dir = try SwiftDataCrashReproductionFixtures.makeUniqueStoreDirectory()
        let storeURL = dir.appendingPathComponent("PrimaryLocalStore.store")

        try SwiftDataCrashReproductionFixtures.seedFreshStore(storeURL: storeURL)
        try SwiftDataCrashReproductionFixtures.overwriteStoreInteriorWithNoise(at: storeURL)
        SwiftDataCrashReproductionFixtures.removeSQLiteSidecarFilesIfPresent(storeURL: storeURL)

        let configuration = SwiftDataCrashReproductionFixtures.makePrimaryConfiguration(url: storeURL)

        #expect(throws: (any Error).self) {
            let container = try ModelContainer(
                for: SwiftDataCrashReproductionFixtures.cbtSchema,
                configurations: [configuration]
            )
            let context = ModelContext(container)
            try SwiftDataCrashReproductionFixtures.exerciseProductionStyleMainContextFetches(on: context)
        }
    }

    @Test @MainActor
    func swiftDataTruncatedStoreFailsOpenOrSwiftUIProbeRender() throws {
        let dir = try SwiftDataCrashReproductionFixtures.makeUniqueStoreDirectory()
        let storeURL = dir.appendingPathComponent("PrimaryLocalStore.store")

        try SwiftDataCrashReproductionFixtures.seedFreshStore(storeURL: storeURL)
        try SwiftDataCrashReproductionFixtures.truncateStoreToBreakMetadata(at: storeURL)
        SwiftDataCrashReproductionFixtures.removeSQLiteSidecarFilesIfPresent(storeURL: storeURL)

        let configuration = SwiftDataCrashReproductionFixtures.makePrimaryConfiguration(url: storeURL)

        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: SwiftDataCrashReproductionFixtures.cbtSchema,
                configurations: [configuration]
            )
        } catch {
            return
        }

        let context = ModelContext(container)
        do {
            try SwiftDataCrashReproductionFixtures.exerciseProductionStyleMainContextFetches(on: context)
        } catch {
            return
        }

        // If open and fetches both succeed, still mirror the layout-time path from the crash
        // (`_SwiftData_SwiftUI`). This may trap with EXC_BREAKPOINT inside SwiftData instead of throwing.
        SwiftDataCrashReproductionFixtures.renderMoodQueryProbe(modelContainer: container)
    }
}
