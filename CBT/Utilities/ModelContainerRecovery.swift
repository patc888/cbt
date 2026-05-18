import Foundation
import Darwin
import SwiftData
import os.log

struct ModelContainerRecovery {
    private let logger = Logger(subsystem: "com.melichan.CBT", category: "ModelContainerRecovery")

    let schema: Schema
    let groupID: String
    let storeName: String
    let cloudKitDatabase: ModelConfiguration.CloudKitDatabase

    init(
        schema: Schema,
        groupID: String,
        storeName: String = "default.store",
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase = .private(AppConfiguration.cloudKitContainerIdentifier)
    ) {
        self.schema = schema
        self.groupID = groupID
        self.storeName = storeName
        self.cloudKitDatabase = cloudKitDatabase
    }

    func makeModelContainer() throws -> ModelContainer {
        let storeURL = resolvedStoreURL()
        if let storeURL {
            Self.clearLaunchBlockingExtendedAttributes(for: storeURL)
        }

        do {
            return try makePreferredContainer(storeURL: storeURL)
        } catch {
            logger.error("Preferred SwiftData container creation failed: \(String(describing: error), privacy: .public)")

            guard Self.isLikelySchemaConflict(error) else {
                throw error
            }

            do {
                logger.warning("Detected likely schema conflict. Retrying without CloudKit before resetting the store.")
                return try makeLocalOnlyContainer(storeURL: storeURL)
            } catch {
                logger.error("Local-only recovery attempt failed: \(String(describing: error), privacy: .public)")
            }

            guard let storeURL else {
                throw error
            }

            let archivedStores = try quarantineStoreFiles(at: storeURL)
            if archivedStores.isEmpty {
                logger.warning("No existing store files were found to quarantine before reset.")
            } else {
                let archivedPaths = archivedStores.map { $0.path(percentEncoded: false) }.joined(separator: ", ")
                logger.warning("Quarantined conflicting store files before reset: \(archivedPaths, privacy: .public)")
            }

            return try makePreferredContainer(storeURL: storeURL)
        }
    }

    private func makePreferredContainer(storeURL: URL?) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: CBTModelMigrationPlan.self,
            configurations: [preferredConfiguration(storeURL: storeURL)]
        )
    }

    private func makeLocalOnlyContainer(storeURL: URL?) throws -> ModelContainer {
        try ModelContainer(
            for: schema,
            migrationPlan: CBTModelMigrationPlan.self,
            configurations: [localOnlyConfiguration(storeURL: storeURL)]
        )
    }

    private func preferredConfiguration(storeURL: URL?) -> ModelConfiguration {
        if let storeURL {
            return ModelConfiguration("Default", schema: schema, url: storeURL, cloudKitDatabase: cloudKitDatabase)
        }

        return ModelConfiguration("Default", schema: schema, cloudKitDatabase: cloudKitDatabase)
    }

    private func localOnlyConfiguration(storeURL: URL?) -> ModelConfiguration {
        if let storeURL {
            return ModelConfiguration("Default", schema: schema, url: storeURL)
        }

        return ModelConfiguration("Default", schema: schema)
    }

    private func resolvedStoreURL() -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent(storeName)
    }

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

    static func isLikelySchemaConflict(_ error: Error) -> Bool {
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
