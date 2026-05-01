import Foundation
import SwiftData

/// Centralized SwiftData container configuration for CBT.
/// Mirrors the Weight Tracker app's shared-store bootstrap, with CloudKit
/// enabled for CBT's private iCloud database.
///
/// Boot order:
///   1. Default store + CloudKit sync  (ideal path)
///   2. Default store, no CloudKit     (offline fallback)
///   3. In-memory store                (recovery mode)
enum SharedPersistence {
    static let cloudKitContainerID = "iCloud.com.melichan.CBT"
    static let appGroupIdentifier = "group.com.melichan.CBT"
    static let storeFileName = "default.store"
    private static let storeSidecarExtensions = ["", "-shm", "-wal"]

    static let schema = Schema([
        UserSettings.self,
        MoodEntry.self,
        ThoughtRecord.self,
        ExerciseCompletion.self,
        JournalEntry.self,
    ])

    // MARK: - Factory

    /// Creates a `ModelContainer` with optional CloudKit backing.
    /// - Parameters:
    ///   - storeURL: An explicit file URL for the SQLite store. Pass `nil` to use SwiftData's default location.
    ///   - cloudKitEnabled: Whether to enable CloudKit sync via the private database.
    static func makeModelContainer(
        storeURL: URL? = defaultStoreURL,
        cloudKitEnabled: Bool
    ) throws -> ModelContainer {
        if let storeURL {
            try prepareStoreLocation(at: storeURL)
        }

        let configuration: ModelConfiguration

        if let storeURL {
            configuration = ModelConfiguration(
                url: storeURL,
                cloudKitDatabase: cloudKitEnabled ? .private(cloudKitContainerID) : .none
            )
        } else {
            configuration = ModelConfiguration(
                cloudKitDatabase: cloudKitEnabled ? .private(cloudKitContainerID) : .none
            )
        }

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Uses the same App Group-backed store location pattern as Weight Tracker,
    /// so iPhone, iPad, and Mac Catalyst builds all open the same app container
    /// layout for this bundle.
    static var defaultStoreURL: URL? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }

        return groupURL.appendingPathComponent(storeFileName)
    }

    private static var legacyDefaultStoreURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent(storeFileName)
    }

    private static func prepareStoreLocation(at storeURL: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        guard
            !fileManager.fileExists(atPath: storeURL.path),
            let legacyStoreURL = legacyDefaultStoreURL,
            legacyStoreURL != storeURL,
            fileManager.fileExists(atPath: legacyStoreURL.path)
        else {
            return
        }

        for sidecarExtension in storeSidecarExtensions {
            let legacyURL = URL(fileURLWithPath: legacyStoreURL.path + sidecarExtension)
            let destinationURL = URL(fileURLWithPath: storeURL.path + sidecarExtension)

            guard fileManager.fileExists(atPath: legacyURL.path) else { continue }
            guard !fileManager.fileExists(atPath: destinationURL.path) else { continue }

            try fileManager.copyItem(at: legacyURL, to: destinationURL)
        }
    }

    /// Creates a purely in-memory container (for tests or as a last-resort recovery).
    static func makeInMemoryModelContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
