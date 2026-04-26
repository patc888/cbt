@preconcurrency import Dispatch
import CoreData
import Foundation
import SwiftData
import os

struct PersistenceController {
    private static let logger = Logger(subsystem: "com.melichan.TimeBlocking", category: "Persistence")
    private static let cloudKitContainerIdentifier = "iCloud.com.melichan.TimeBlocking"
    private static let forceNoCloudKitEnvironmentKey = "TIMEBLOCKING_FORCE_NO_CLOUDKIT"

    static let schema = Schema(
        [
            TimeBlock.self,
            BrainDumpItem.self,
            BlockChecklistItem.self,
            ScheduleTemplate.self,
            AppPreferences.self,
        ],
        version: .init(4, 0, 0)
    )

    static let shared = PersistenceController()
    static let preview = try! PersistenceController(inMemory: true)

    let container: ModelContainer
    let isFallback: Bool

    /// Internal init for synchronous cases (previews, tests)
    init(inMemory: Bool) throws {
        let configuration = Self.makeConfiguration(inMemory: inMemory, cloudKitDatabase: .none)
        self.container = try Self.makeContainer(configuration: configuration)
        self.isFallback = inMemory
    }

    /// Primary async initializer for the app
    static func createAsync(
        inMemory: Bool = false,
        timeout: TimeInterval = 5.0
    ) async throws -> PersistenceController {
        let resolvedCloudKitDatabase = Self.resolveCloudKitDatabase(
            inMemory: inMemory,
            requestedCloudKitDatabase: nil
        )
        let configuration = Self.makeConfiguration(
            inMemory: inMemory,
            cloudKitDatabase: resolvedCloudKitDatabase
        )

        return try await withCheckedThrowingContinuation { continuation in
            var isResumed = false
            func resumeOnce(with result: Result<PersistenceController, Error>) {
                guard !isResumed else { return }
                isResumed = true
                switch result {
                case .success(let controller):
                    continuation.resume(returning: controller)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let workItem = DispatchWorkItem {
                do {
                    let container = try Self.makeContainer(configuration: configuration)
                    resumeOnce(with: .success(PersistenceController(container: container, isFallback: false)))
                } catch {
                    Self.logger.error("Primary initialization failed: \(error.localizedDescription)")

                    // Recovery Stage 1: Local storage
                    if !inMemory && String(describing: resolvedCloudKitDatabase) != "none" {
                        Self.logger.info("Retrying with local-only storage...")
                        let localConfig = Self.makeConfiguration(inMemory: false, cloudKitDatabase: .none)
                        if let localContainer = try? Self.makeContainer(configuration: localConfig) {
                            resumeOnce(with: .success(PersistenceController(container: localContainer, isFallback: false)))
                            return
                        }
                    }

                    // Recovery Stage 2: In-memory fallback
                    Self.logger.warning("Database unavailable. Falling back to in-memory store.")
                    let inMemoryConfig = Self.makeConfiguration(inMemory: true, cloudKitDatabase: .none)
                    do {
                        let inMemoryContainer = try Self.makeContainer(configuration: inMemoryConfig)
                        resumeOnce(with: .success(PersistenceController(container: inMemoryContainer, isFallback: true)))
                    } catch {
                        resumeOnce(with: .failure(error))
                    }
                }
            }

            // Execute on a background utility queue to avoid blocking main thread
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)

            // Implement timeout for the primary initialization (mostly CloudKit related hangs)
            if String(describing: resolvedCloudKitDatabase) != "none" {
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                    if !workItem.isCancelled {
                        workItem.cancel()
                        Self.logger.error("Initialization timed out after \(timeout)s. Forcing local fallback.")

                        let localConfig = Self.makeConfiguration(inMemory: false, cloudKitDatabase: .none)
                        do {
                            let localContainer = try Self.makeContainer(configuration: localConfig)
                            resumeOnce(with: .success(PersistenceController(container: localContainer, isFallback: false)))
                        } catch {
                            // Last resort: in-memory
                            let inMemoryConfig = Self.makeConfiguration(inMemory: true, cloudKitDatabase: .none)
                            if let inMemoryContainer = try? Self.makeContainer(configuration: inMemoryConfig) {
                                resumeOnce(with: .success(PersistenceController(container: inMemoryContainer, isFallback: true)))
                            } else {
                                resumeOnce(with: .failure(error))
                            }
                        }
                    }
                }
            }
        }
    }

    private init(container: ModelContainer, isFallback: Bool) {
        self.container = container
        self.isFallback = isFallback
    }

    private init() {
        // Legacy shared instance for backward compatibility where needed,
        // but it will likely block the first time it's accessed.
        // We'll move away from this in the app lifecycle.
        let resolvedCloudKitDatabase = Self.resolveCloudKitDatabase(inMemory: false, requestedCloudKitDatabase: .automatic)
        let configuration = Self.makeConfiguration(inMemory: false, cloudKitDatabase: resolvedCloudKitDatabase)
        do {
            self.container = try Self.makeContainer(configuration: configuration)
            self.isFallback = false
        } catch {
            let inMemoryConfig = Self.makeConfiguration(inMemory: true, cloudKitDatabase: .none)
            self.container = try! Self.makeContainer(configuration: inMemoryConfig)
            self.isFallback = true
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
