import Foundation
import SwiftData
import os

enum LaunchState: Equatable, Sendable {
    case launching
    case migrating
    case ready(ModelContainer)
    case failed

    static func == (lhs: LaunchState, rhs: LaunchState) -> Bool {
        switch (lhs, rhs) {
        case (.launching, .launching), (.migrating, .migrating), (.failed, .failed):
            return true
        case (.ready, .ready):
            return true
        default:
            return false
        }
    }
}

enum BootstrapStage: String, Sendable {
    case primary = "primary-local"
    case primaryRecovery = "primary-local-recovery"
    case fallback = "fallback-local"
    case inMemory = "fallback-memory"
}

enum BootstrapResolution: Equatable, Sendable {
    case primary
    case primaryRecovery
    case fallback
    case inMemory
    case repair
}

struct BootstrapActions<Resource: Sendable>: Sendable {
    let makePrimary: @Sendable (BootstrapStage) throws -> Resource
    let quarantineDefaultStoreForRepair: @Sendable () throws -> URL?
    let removeFallbackStoreFiles: @Sendable () throws -> Void
    let makeFallback: @Sendable () throws -> Resource
    let makeInMemory: @Sendable () throws -> Resource
    let logBootstrapFailure: @Sendable (Error, BootstrapStage, String) -> Void
    let logHousekeepingFailure: @Sendable (Error, String) -> Void
    let logFallbackLaunch: @Sendable () -> Void
    let logInMemoryLaunch: @Sendable () -> Void
}

enum BootstrapAttemptResult<Resource: Sendable> {
    case ready(Resource, BootstrapResolution)
    case repair
}

enum BootstrapError: Error, Sendable {
    case debugInjectedFailure(String)
}

enum DebugBootstrapControl {
    #if DEBUG
    private nonisolated static let launchArguments = ProcessInfo.processInfo.arguments
    private nonisolated static let failAllStores = launchArguments.contains("-debug-modelcontainer-fail-all")
    private nonisolated static let remainingPrimaryFailuresLock = NSLock()
    private nonisolated(unsafe) static var remainingPrimaryFailures = launchArguments.contains("-debug-modelcontainer-fail-primary-once") ? 1 : 0
    #endif

    nonisolated static func injectFailureIfNeeded(for stage: BootstrapStage) throws {
        #if DEBUG
        if failAllStores {
            throw BootstrapError.debugInjectedFailure(stage.rawValue)
        }

        if stage == .primary, consumePrimaryFailureIfNeeded() {
            throw BootstrapError.debugInjectedFailure(stage.rawValue)
        }
        #endif
    }

    #if DEBUG
    private nonisolated static func consumePrimaryFailureIfNeeded() -> Bool {
        remainingPrimaryFailuresLock.lock()
        defer { remainingPrimaryFailuresLock.unlock() }

        guard remainingPrimaryFailures > 0 else { return false }
        remainingPrimaryFailures -= 1
        return true
    }
    #endif
}
