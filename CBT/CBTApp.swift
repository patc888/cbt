import OSLog
import Foundation
import SwiftData
import SwiftUI

@main
struct CBTApp: App {
    private nonisolated static let bootstrapTimeoutSeconds: TimeInterval = 12

    private enum LaunchState: Sendable {
        case loading
        case ready(ModelContainer)
        case repair
    }

    private struct LoadingRequest: Sendable {
        let id = UUID()
        let reason: String
    }

    fileprivate enum BootstrapStage: String, Sendable {
        case primary = "primary-local"
        case primaryRecovery = "primary-local-recovery"
        case fallback = "fallback-local"
        case inMemory = "fallback-memory"
    }

    fileprivate enum BootstrapError: Error, Sendable {
        case debugInjectedFailure(String)
    }

    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CBT",
        category: "AppBootstrap"
    )

    private nonisolated static let schema = Schema([
        Item.self,
        UserSettings.self,
        MoodEntry.self,
        ThoughtRecord.self,
        ExerciseCompletion.self,
        JournalEntry.self
    ])

    @State private var launchState: LaunchState
    @State private var loadingRequest: LoadingRequest
    @State private var resetID = UUID()
    @State private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var securityManager = SecurityManager.shared
    @State private var hasCheckedLockOnLaunch = false
    @State private var lastStartedBootstrapID: UUID?
    @State private var isResetInProgress = false

    init() {
        let initialRequest = LoadingRequest(reason: "app launch")
        _launchState = State(initialValue: .loading)
        _loadingRequest = State(initialValue: initialRequest)
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(themeManager)
                .preferredColorScheme(themeManager.appTheme.colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    scheduleLockCheckIfNeeded(for: newPhase)
                }
                .onReceive(NotificationCenter.default.publisher(for: .didResetData)) { _ in
                    themeManager = ThemeManager()
                    securityManager.unlock()
                    scheduleBootstrap(reason: "local reset")
                }
                .onReceive(NotificationCenter.default.publisher(for: .requestDataReset)) { _ in
                    beginLocalResetFlow()
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        switch launchState {
        case .loading:
            DataRepairLoadingView()
                .task(id: loadingRequest.id) {
                    guard !isResetInProgress else { return }
                    await bootstrapIntoCurrentState(for: loadingRequest)
                }
        case .ready(let container):
            ReadyRootView(container: container, resetID: resetID)
                .environmentObject(securityManager)
        case .repair:
            DataRepairView(
                onRetry: {
                    scheduleBootstrap(reason: "repair retry")
                },
                onResetThisDevice: {
                    DataResetManager.shared.requestLocalWipe()
                }
            )
        }
    }

    @MainActor
    private func scheduleBootstrap(reason: String) {
        hasCheckedLockOnLaunch = false
        isResetInProgress = false
        launchState = .loading
        loadingRequest = LoadingRequest(reason: reason)
    }

    @MainActor
    private func scheduleLockCheckIfNeeded(for newPhase: ScenePhase) {
        guard newPhase == .active else { return }
        guard !hasCheckedLockOnLaunch else { return }
        guard case .ready(let container) = launchState else { return }

        hasCheckedLockOnLaunch = true

        Task {
            let isLockEnabled = await Self.loadAppLockEnabled(from: container)
            guard isLockEnabled else { return }

            await MainActor.run {
                securityManager.lock()
                securityManager.authenticate()
            }
        }
    }

    @MainActor
    private func beginLocalResetFlow() {
        hasCheckedLockOnLaunch = false
        isResetInProgress = true
        themeManager = ThemeManager()
        securityManager.unlock()
        launchState = .loading

        Task {
            await Task.yield()
            await DataResetManager.shared.performLocalWipeHousekeeping()
        }
    }

    @MainActor
    private func bootstrapIntoCurrentState(for request: LoadingRequest) async {
        guard lastStartedBootstrapID != request.id else { return }
        lastStartedBootstrapID = request.id

        let nextState = await Self.bootstrapAsync(reason: request.reason)

        guard !Task.isCancelled else { return }
        guard loadingRequest.id == request.id else { return }
        if case .ready = nextState {
            resetID = UUID()
        }
        launchState = nextState
    }

    private nonisolated static func bootstrapAsync(reason: String) async -> LaunchState {
        await Task.detached(priority: .userInitiated) {
            Self.bootstrapWithWatchdog(reason: reason)
        }.value
    }

    private nonisolated static func bootstrapWithWatchdog(reason: String) -> LaunchState {
        let group = DispatchGroup()
        let lock = NSLock()
        var result: LaunchState?

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            let state = Self.bootstrap(reason: reason)
            lock.lock()
            result = state
            lock.unlock()
            group.leave()
        }

        let timeout = DispatchTime.now() + Self.bootstrapTimeoutSeconds
        guard group.wait(timeout: timeout) == .success else {
            logger.error(
                "Model bootstrap timed out after \(Self.bootstrapTimeoutSeconds, privacy: .public)s reason=\(reason, privacy: .public)"
            )
            return .repair
        }

        lock.lock()
        defer { lock.unlock() }
        return result ?? .repair
    }

    private nonisolated static func bootstrap(reason: String) -> LaunchState {
        do {
            return .ready(try makePrimaryContainer(stage: .primary))
        } catch {
            logBootstrapFailure(error, stage: .primary, reason: reason)
        }

        do {
            if try DataResetManager.quarantineDefaultStoreForRepair() != nil {
                logger.notice("Quarantined the default store before retrying model bootstrap.")
            }
        } catch {
            logHousekeepingFailure(error, action: "quarantine-default-store")
        }

        do {
            return .ready(try makePrimaryContainer(stage: .primaryRecovery))
        } catch {
            logBootstrapFailure(error, stage: .primaryRecovery, reason: reason)
        }

        do {
            try DataResetManager.removeFallbackStoreFiles()
        } catch {
            logHousekeepingFailure(error, action: "clear-fallback-store")
        }

        do {
            logger.notice("Launching with an isolated local fallback store.")
            return .ready(try makeFallbackContainer())
        } catch {
            logBootstrapFailure(error, stage: .fallback, reason: reason)
        }

        do {
            logger.notice("Launching with an in-memory recovery store.")
            return .ready(try makeInMemoryContainer())
        } catch {
            logBootstrapFailure(error, stage: .inMemory, reason: reason)
            return .repair
        }
    }

    private nonisolated static func loadAppLockEnabled(from container: ModelContainer) async -> Bool {
        await Task.detached(priority: .utility) {
            let context = ModelContext(container)
            let descriptor = FetchDescriptor<UserSettings>()

            do {
                return try context.fetch(descriptor).first?.appLockEnabled == true
            } catch {
                Self.logger.error("Failed to fetch settings for lock check: \(error.localizedDescription, privacy: .public)")
                return false
            }
        }.value
    }

    private nonisolated static func makePrimaryContainer(stage: BootstrapStage) throws -> ModelContainer {
        try DebugBootstrapControl.injectFailureIfNeeded(for: stage)

        // TODO: Reintroduce a CloudKit-backed launch path only after the
        // startup bootstrap has been proven stable in App Review conditions.
        let configuration = ModelConfiguration(
            "PrimaryLocalStore",
            schema: schema,
            url: DataResetManager.defaultStoreURL,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private nonisolated static func makeFallbackContainer() throws -> ModelContainer {
        try DebugBootstrapControl.injectFailureIfNeeded(for: .fallback)

        let configuration = ModelConfiguration(
            "LocalRecovery",
            schema: schema,
            url: DataResetManager.fallbackStoreURL,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private nonisolated static func makeInMemoryContainer() throws -> ModelContainer {
        try DebugBootstrapControl.injectFailureIfNeeded(for: .inMemory)

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private nonisolated static func logBootstrapFailure(
        _ error: Error,
        stage: BootstrapStage,
        reason: String
    ) {
        let nsError = error as NSError
        logger.error(
            "Model bootstrap failed stage=\(stage.rawValue, privacy: .public) reason=\(reason, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
    }

    private nonisolated static func logHousekeepingFailure(_ error: Error, action: String) {
        let nsError = error as NSError
        logger.error(
            "Bootstrap recovery housekeeping failed action=\(action, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
    }
}

private struct ReadyRootView: View {
    let container: ModelContainer
    let resetID: UUID

    @StateObject private var securityManager = SecurityManager.shared

    var body: some View {
        ZStack {
            ContentView()
                .id(resetID)

            if securityManager.isLocked {
                LockView()
                    .transition(.opacity)
                    .zIndex(100)
            }
        }
        .modelContainer(container)
    }
}

private enum DebugBootstrapControl {
    #if DEBUG
    private nonisolated static let launchArguments = ProcessInfo.processInfo.arguments
    private nonisolated static let failAllStores = launchArguments.contains("-debug-modelcontainer-fail-all")
    private nonisolated static let remainingPrimaryFailuresLock = NSLock()
    private nonisolated(unsafe) static var remainingPrimaryFailures = launchArguments.contains("-debug-modelcontainer-fail-primary-once") ? 1 : 0
    #endif

    nonisolated static func injectFailureIfNeeded(for stage: CBTApp.BootstrapStage) throws {
        #if DEBUG
        if failAllStores {
            throw CBTApp.BootstrapError.debugInjectedFailure(stage.rawValue)
        }

        if stage == .primary, consumePrimaryFailureIfNeeded() {
            throw CBTApp.BootstrapError.debugInjectedFailure(stage.rawValue)
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

private struct DataRepairLoadingView: View {
    var body: some View {
        ZStack {
            ThemedBackground()
                .ignoresSafeArea()

            ProgressView("Opening your data...")
                .font(DSTypography.body)
                .padding(24)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous))
                .accessibilityElement(children: .combine)
        }
    }
}

private struct DataRepairView: View {
    @Environment(ThemeManager.self) private var themeManager

    let onRetry: () -> Void
    let onResetThisDevice: () -> Void

    var body: some View {
        ZStack {
            ThemedBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    DSCardContainer {
                        VStack(alignment: .leading, spacing: 16) {
                            Label {
                                Text("Data Repair")
                                    .font(DSTypography.sectionTitle)
                                    .foregroundStyle(DSTheme.primaryText)
                            } icon: {
                                Image(systemName: "externaldrive.badge.exclamationmark")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(themeManager.primaryColor)
                            }

                            Text("Something went wrong while opening your data on this device.")
                                .font(DSTypography.body)
                                .foregroundStyle(DSTheme.primaryText)

                            Text("You can try again, or reset local data on this device. Resetting this device does not delete iCloud data.")
                                .font(DSTypography.body)
                                .foregroundStyle(DSTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    VStack(spacing: 12) {
                        DSPrimaryButton(title: "Retry", action: onRetry)

                        Button("Reset This Device", action: onResetThisDevice)
                            .font(DSTypography.button)
                            .foregroundStyle(Theme.errorRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DSSpacing.large)
                            .background(Theme.errorRed.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.medium, style: .continuous))
                            .accessibilityHint("Deletes local app data and preferences on this device only.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
                .responsiveMaxWidth(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
        }
    }
}
