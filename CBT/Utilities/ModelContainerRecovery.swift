import Foundation
import Darwin
import SwiftData
import os.log

struct ModelContainerRecovery {
    struct RecoveryResult {
        let container: ModelContainer
        let cloudKitEnabled: Bool
        let cloudKitFailure: Error?
    }

    private let logger = Logger(subsystem: "com.melichan.CBT", category: "ModelContainerRecovery")

    let schema: Schema
    let groupID: String
    let storeName: String
    let cloudKitDatabase: ModelConfiguration.CloudKitDatabase

    init(
        schema: Schema,
        groupID: String,
        storeName: String = SharedPersistence.storeFileName,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .private(AppConfiguration.cloudKitContainerIdentifier)
    ) {
        self.schema = schema
        self.groupID = groupID
        self.storeName = storeName
        self.cloudKitDatabase = cloudKitDatabase
    }

    func makeModelContainer() throws -> ModelContainer {
        try makeModelContainerRecovery().container
    }

    func makeModelContainerRecovery() throws -> RecoveryResult {
        let storeURL = resolvedStoreURL()
        if let storeURL {
            Self.clearLaunchBlockingExtendedAttributes(for: storeURL)
        }

        do {
            let container = try makeContainer(storeURL: storeURL, cloudKitDatabase: cloudKitDatabase)
            return RecoveryResult(container: container, cloudKitEnabled: true, cloudKitFailure: nil)
        } catch {
            logger.error("Preferred SwiftData container creation failed: \(String(describing: error), privacy: .public)")

            guard Self.isLikelySchemaConflict(error) else {
                throw error
            }

            let cloudKitFailure = error

            do {
                logger.warning("Detected likely schema conflict. Retrying without CloudKit while preserving the existing store.")
                let container = try makeContainer(storeURL: storeURL, cloudKitDatabase: .none)
                return RecoveryResult(container: container, cloudKitEnabled: false, cloudKitFailure: cloudKitFailure)
            } catch {
                logger.error("Local-only recovery attempt failed: \(String(describing: error), privacy: .public)")
                logger.warning("Leaving the persistent store in place. The app can fall back to temporary storage without resetting user data.")
                throw error
            }
        }
    }

    private func makeContainer(
        storeURL: URL?,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: CBTModelMigrationPlan.self,
            configurations: [makeConfiguration(storeURL: storeURL, cloudKitDatabase: cloudKitDatabase)]
        )
    }

    private func makeConfiguration(
        storeURL: URL?,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) -> ModelConfiguration {
        if let storeURL {
            return ModelConfiguration("Default", schema: schema, url: storeURL, cloudKitDatabase: cloudKitDatabase)
        }

        return ModelConfiguration("Default", schema: schema, cloudKitDatabase: cloudKitDatabase)
    }

    private func resolvedStoreURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent(storeName)
    }

    /// Debug/test utility only. App launch recovery must not move a user's production store.
    func quarantineStoreFiles(at storeURL: URL) throws -> [URL] {
        let fileManager = FileManager.default
        let quarantineSuffix = ISO8601DateFormatter.fileSafeTimestamp.string(from: Date())
        var archivedURLs: [URL] = []

        for sourceURL in Self.storeFileURLs(for: storeURL) where fileManager.fileExists(atPath: sourceURL.path) {
            let archivedURL = sourceURL.deletingLastPathComponent().appendingPathComponent(
                "\(sourceURL.lastPathComponent).conflict-\(quarantineSuffix)"
            )
            try fileManager.moveItem(at: sourceURL, to: archivedURL)
            archivedURLs.append(archivedURL)
        }

        return archivedURLs
    }

    static func storeFileURLs(for storeURL: URL) -> [URL] {
        [
            storeURL,
            storeURL.deletingPathExtension().appendingPathExtension("store-shm"),
            storeURL.deletingPathExtension().appendingPathExtension("store-wal"),
        ]
    }

    static func clearLaunchBlockingExtendedAttributes(for storeURL: URL) {
        let attributeNames = [
            "com.apple.quarantine",
            "com.apple.provenance",
        ]

        for fileURL in storeFileURLs(for: storeURL) where FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL.withUnsafeFileSystemRepresentation { path in
                guard let path else { return }

                for attributeName in attributeNames {
                    _ = attributeName.withCString { name in
                        removexattr(path, name, 0)
                    }
                }
            }
        }
    }

    nonisolated static func isLikelySchemaConflict(_ error: Error) -> Bool {
        let nsError = error as NSError

        if nsError.domain == NSCocoaErrorDomain {
            let migrationCodes: Set<Int> = [134100, 134110, 134130, 134140, 134170, 134180, 134190, 134504]
            if migrationCodes.contains(nsError.code) {
                return true
            }
        }

        let errorText = [
            nsError.localizedDescription,
            nsError.localizedFailureReason,
            String(describing: error),
        ]
        .compactMap { $0?.lowercased() }
        .joined(separator: " ")

        let markers = [
            "migration",
            "migrate",
            "schema",
            "model",
            "version hash",
            "incompatible",
            "not compatible",
            "persistent store",
            "unknown model version",
            "entity mismatch",
        ]

        return markers.contains { errorText.contains($0) }
    }
}

private extension ISO8601DateFormatter {
    static let fileSafeTimestamp: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
