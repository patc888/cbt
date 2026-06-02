import Foundation
import OSLog
import SwiftData

enum CloudStorageBootstrap {
    struct Result {
        let container: ModelContainer?
        let cloudKitEnabled: Bool
        let recoveryMessage: String?
        let cloudKitFailureReason: String?
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CBT",
        category: "CloudStorageBootstrap"
    )

    static func makeModelContainer() -> Result {
        if AppConfiguration.shouldUseInMemoryStoreForThisProcess {
            do {
                let container = try SharedPersistence.makeInMemoryModelContainer()
                logger.info("[SwiftData] Successfully using in-memory store for test/debug launch")
                return Result(container: container, cloudKitEnabled: false, recoveryMessage: nil, cloudKitFailureReason: nil)
            } catch {
                logger.error("[SwiftData] In-memory test/debug store failed: \(String(describing: error), privacy: .public)")
            }
        }

        do {
            let recovery = try ModelContainerRecovery(
                schema: SharedPersistence.schema,
                groupID: AppConfiguration.appGroupIdentifier
            )
            .makeModelContainerRecovery()

            if recovery.cloudKitEnabled {
                logger.info("[SwiftData] Successfully using App Group + CloudKit store")
                return Result(container: recovery.container, cloudKitEnabled: true, recoveryMessage: nil, cloudKitFailureReason: nil)
            }

            let failureReason = recovery.cloudKitFailure.map(userVisibleCloudKitFailureReason(from:))
                ?? AppConfiguration.defaultCloudKitFallbackReason
            logger.info("[SwiftData] Successfully using App Group local store after CloudKit recovery fallback")
            return localFallbackResult(container: recovery.container, cloudKitFailureReason: failureReason)
        } catch {
            logger.info("[SwiftData] App Group + CloudKit failed: \(String(describing: error), privacy: .public)")
            let cloudKitFailureReason = userVisibleCloudKitFailureReason(from: error)

            do {
                let container = try SharedPersistence.makeModelContainer(cloudKitEnabled: false)
                logger.info("[SwiftData] Successfully using App Group local store")
                return localFallbackResult(container: container, cloudKitFailureReason: cloudKitFailureReason)
            } catch {
                logger.info("[SwiftData] App Group local store failed: \(error.localizedDescription)")
            }
        }

        return temporaryRecoveryResult()
    }

    static func publish(_ result: Result, defaults: UserDefaults = .standard) {
        defaults.set(result.cloudKitEnabled, forKey: AppConfiguration.cloudKitEnabledKey)
        defaults.set(result.cloudKitEnabled ? "cloudKit" : "local", forKey: AppConfiguration.persistenceModeKey)

        setOrRemove(result.recoveryMessage, forKey: AppConfiguration.cloudKitRecoveryMessageKey, defaults: defaults)
        setOrRemove(result.cloudKitFailureReason, forKey: AppConfiguration.cloudKitFailureReasonKey, defaults: defaults)
    }

    private static func localFallbackResult(container: ModelContainer, cloudKitFailureReason: String) -> Result {
        Result(
            container: container,
            cloudKitEnabled: false,
            recoveryMessage: AppConfiguration.cloudKitFallbackRecoveryMessage,
            cloudKitFailureReason: cloudKitFailureReason
        )
    }

    private static func temporaryRecoveryResult() -> Result {
        do {
            let container = try SharedPersistence.makeInMemoryModelContainer()
            return Result(
                container: container,
                cloudKitEnabled: false,
                recoveryMessage: "CBT couldn't open its persistent store and started in temporary recovery mode. Changes may not persist until you relaunch the app.",
                cloudKitFailureReason: "The persistent store could not be opened, so CBT started in temporary recovery mode."
            )
        } catch {
            return Result(
                container: nil,
                cloudKitEnabled: false,
                recoveryMessage: "CBT couldn't open its data store. Relaunch the app. If the problem continues, restart the device or reinstall the app.",
                cloudKitFailureReason: "The persistent store could not be opened."
            )
        }
    }

    nonisolated private static func userVisibleCloudKitFailureReason(from error: Error) -> String {
        if ModelContainerRecovery.isLikelySchemaConflict(error) {
            return "CloudKit storage could not start because the local data model appears incompatible with the synced CloudKit schema."
        }

        let nsError = error as NSError
        let details = [
            nsError.localizedDescription,
            nsError.localizedFailureReason
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " ")

        guard !details.isEmpty else {
            return AppConfiguration.defaultCloudKitFallbackReason
        }

        return "CloudKit storage could not start: \(details)"
    }

    private static func setOrRemove(_ value: String?, forKey key: String, defaults: UserDefaults) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
