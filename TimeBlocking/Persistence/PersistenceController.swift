import CoreData
import Foundation
import SwiftData

struct PersistenceController {
    private static let cloudKitContainerIdentifier = "iCloud.com.melichan.TimeBlocking"
    private static let forceNoCloudKitEnvironmentKey = "TIMEBLOCKING_FORCE_NO_CLOUDKIT"

    static let schema = Schema(
        [
            TimeBlock.self,
            BlockChecklistItem.self,
            ScheduleTemplate.self,
            AppPreferences.self,
        ],
        version: .init(3, 0, 0)
    )

    static let shared = PersistenceController()
    static let preview = PersistenceController(inMemory: true)

    let container: ModelContainer

    init(
        inMemory: Bool = false,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase? = nil
    ) {
        let resolvedCloudKitDatabase = Self.resolveCloudKitDatabase(
            inMemory: inMemory,
            requestedCloudKitDatabase: cloudKitDatabase
        )
        let configuration = Self.makeConfiguration(
            inMemory: inMemory,
            cloudKitDatabase: resolvedCloudKitDatabase
        )

        do {
            container = try Self.makeContainer(configuration: configuration)
        } catch {
            fatalError(
                Self.modelContainerFailureMessage(
                    error: error,
                    configuration: configuration,
                    inMemory: inMemory,
                    cloudKitDatabase: resolvedCloudKitDatabase
                )
            )
        }
    }

    private static func makeConfiguration(
        inMemory: Bool,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase,
        url: URL? = nil
    ) -> ModelConfiguration {
        if let url {
            ModelConfiguration(
                "TimeBlocking",
                schema: Self.schema,
                url: url,
                cloudKitDatabase: cloudKitDatabase
            )
        } else {
            ModelConfiguration(
                "TimeBlocking",
                schema: Self.schema,
                isStoredInMemoryOnly: inMemory,
                cloudKitDatabase: cloudKitDatabase
            )
        }
    }

    private static func resolveCloudKitDatabase(
        inMemory: Bool,
        requestedCloudKitDatabase: ModelConfiguration.CloudKitDatabase?
    ) -> ModelConfiguration.CloudKitDatabase {
        let defaultCloudKitDatabase = requestedCloudKitDatabase ?? (inMemory ? .none : .automatic)

        guard !inMemory, isCloudKitForceDisabledForDebugging else {
            return defaultCloudKitDatabase
        }

        return .none
    }

    private static var isCloudKitForceDisabledForDebugging: Bool {
        let value = ProcessInfo.processInfo.environment[forceNoCloudKitEnvironmentKey]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        return value == "1" || value?.lowercased() == "true"
    }

    private static func makeContainer(configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(
            for: Self.schema,
            configurations: [configuration]
        )
    }

    private static func modelContainerFailureMessage(
        error: Error,
        configuration: ModelConfiguration,
        inMemory: Bool,
        cloudKitDatabase: ModelConfiguration.CloudKitDatabase
    ) -> String {
        let shouldRetryWithoutCloudKit = !inMemory && String(describing: cloudKitDatabase) != "none"

        var lines = [
            "Unable to create model container.",
            "schemaVersion=\(schema.version)",
            "inMemory=\(inMemory)",
            "cloudKitDatabase=\(cloudKitDatabase)",
            "expectedCloudKitContainerIdentifier=\(cloudKitContainerIdentifier)",
            "resolvedCloudKitContainerIdentifier=\(configuration.cloudKitContainerIdentifier ?? "nil")",
            "configurationName=\(configuration.name)",
            "storeURL=\(configuration.url.path)",
            "cloudKitForceDisabledForDebugging=\(isCloudKitForceDisabledForDebugging)",
            "cloudKitForceDisabledEnvironmentKey=\(forceNoCloudKitEnvironmentKey)",
            "",
            "Primary error:",
        ]

        lines.append(contentsOf: describe(error: error, indent: "  "))

        if shouldRetryWithoutCloudKit {
            lines.append("")
            lines.append("CloudKit disabled retry:")

            do {
                _ = try makeContainer(
                    configuration: makeConfiguration(
                        inMemory: false,
                        cloudKitDatabase: .none
                    )
                )
                lines.append("  result=success")
                lines.append("  classification=likely CloudKit compatibility or CloudKit configuration issue")
            } catch {
                lines.append("  result=failure")
                lines.append(contentsOf: describe(error: error, indent: "  "))
                lines.append("  classification=likely SwiftData schema, stale store/migration, or local configuration issue")
            }
        }

        if !inMemory {
            lines.append("")
            lines.append("In-memory retry:")

            do {
                _ = try makeContainer(
                    configuration: makeConfiguration(
                        inMemory: true,
                        cloudKitDatabase: .none
                    )
                )
                lines.append("  result=success")
                lines.append("  classification=schema loads in memory")
            } catch {
                lines.append("  result=failure")
                lines.append(contentsOf: describe(error: error, indent: "  "))
                lines.append("  classification=likely invalid schema, relationship, or unsupported property type")
            }

            lines.append("")
            lines.append("Fresh local store retry:")

            let temporaryStoreDirectory = temporaryStoreDirectoryURL()
            let temporaryStoreURL = temporaryStoreDirectory.appendingPathComponent("TimeBlocking.sqlite")

            do {
                try FileManager.default.createDirectory(
                    at: temporaryStoreDirectory,
                    withIntermediateDirectories: true
                )

                _ = try makeContainer(
                    configuration: makeConfiguration(
                        inMemory: false,
                        cloudKitDatabase: .none,
                        url: temporaryStoreURL
                    )
                )
                lines.append("  result=success")
                lines.append("  storeURL=\(temporaryStoreURL.path)")
                lines.append("  classification=existing default store is likely stale or incompatible with the current schema")
            } catch {
                lines.append("  result=failure")
                lines.append("  storeURL=\(temporaryStoreURL.path)")
                lines.append(contentsOf: describe(error: error, indent: "  "))
                lines.append("  classification=local persistent-store configuration or schema-to-store compatibility issue")
            }

            try? FileManager.default.removeItem(at: temporaryStoreDirectory)
        }

        return lines.joined(separator: "\n")
    }

    private static func temporaryStoreDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("TimeBlocking-SwiftData-Debug-\(UUID().uuidString)", isDirectory: true)
    }

    private static func describe(error: Error, indent: String) -> [String] {
        let nsError = error as NSError
        var lines = [
            "\(indent)type=\(String(reflecting: type(of: error)))",
            "\(indent)domain=\(nsError.domain)",
            "\(indent)code=\(nsError.code)",
            "\(indent)localizedDescription=\(nsError.localizedDescription)",
        ]

        if let failureReason = nsError.localizedFailureReason {
            lines.append("\(indent)localizedFailureReason=\(failureReason)")
        }

        if let recoverySuggestion = nsError.localizedRecoverySuggestion {
            lines.append("\(indent)localizedRecoverySuggestion=\(recoverySuggestion)")
        }

        let scalarUserInfo = nsError.userInfo
            .filter { key, _ in
                key != NSUnderlyingErrorKey &&
                key != NSDetailedErrorsKey &&
                key != "NSMultipleUnderlyingErrorsKey"
            }
            .sorted { $0.key < $1.key }

        if !scalarUserInfo.isEmpty {
            lines.append("\(indent)userInfo:")
            for (key, value) in scalarUserInfo {
                lines.append("\(indent)  \(key)=\(String(describing: value))")
            }
        }

        if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            lines.append("\(indent)underlyingError:")
            lines.append(contentsOf: describe(error: underlyingError, indent: indent + "  "))
        }

        if let detailedErrors = nsError.userInfo[NSDetailedErrorsKey] as? [NSError], !detailedErrors.isEmpty {
            lines.append("\(indent)detailedErrors:")
            for (index, detailedError) in detailedErrors.enumerated() {
                lines.append("\(indent)  [\(index)]")
                lines.append(contentsOf: describe(error: detailedError, indent: indent + "    "))
            }
        }

        let multipleUnderlyingErrorsKey = "NSMultipleUnderlyingErrorsKey"
        if let multipleUnderlyingErrors = nsError.userInfo[multipleUnderlyingErrorsKey] as? [NSError],
           !multipleUnderlyingErrors.isEmpty {
            lines.append("\(indent)multipleUnderlyingErrors:")
            for (index, underlyingError) in multipleUnderlyingErrors.enumerated() {
                lines.append("\(indent)  [\(index)]")
                lines.append(contentsOf: describe(error: underlyingError, indent: indent + "    "))
            }
        }

        return lines
    }
}
