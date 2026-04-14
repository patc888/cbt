import OSLog
import Foundation
import SwiftData
import SwiftUI

@main
struct CBTApp: App {
    private nonisolated static let bootstrapTimeoutSeconds: TimeInterval = 120

    private var currentContainer: ModelContainer? {
        guard case .ready(let container) = launchState else { return nil }
        return container
    }

    private struct LoadingRequest: Sendable {
        let id = UUID()
        let reason: String
    }

    private nonisolated static let logger = AppLogger.make(category: "AppBootstrap")

    private nonisolated static let schema = Schema(versionedSchema: CBTVersionedSchemaV1.self)

    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    @State private var launchState: LaunchState

    @State private var loadingRequest: LoadingRequest
    @State private var resetID = UUID()
    @State private var themeManager = ThemeManager()
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var securityManager = SecurityManager.shared
    @AppStorage("appLockEnabled") private var appLockEnabledPreference = false
    @AppStorage("hideAppSwitcher") private var hideAppSwitcher = false
    @State private var shouldCheckLockOnNextActive = true
    @State private var lastStartedBootstrapID: UUID?
    @State private var isResetInProgress = false

    init() {
        // Perform emergency hard wipe if flagged before any SwiftData initialization starts.
        DataResetManager.performHardWipeIfNeeded()
        
        let initialRequest = LoadingRequest(reason: "app launch")
        _launchState = State(initialValue: .launching)
        _loadingRequest = State(initialValue: initialRequest)
    }

    var body: some Scene {
        WindowGroup {
            mainWindowChrome
        }
    }

    @ViewBuilder
    private var mainWindowChrome: some View {
        ZStack {
            rootView
                .blur(radius: securityManager.isContentProtected ? 20 : 0)
                .overlay {
                    if securityManager.isContentProtected {
                        Color(UIColor.systemBackground)
                            .ignoresSafeArea()
                    }
                }
            
            // This is the interaction-blocking layer
            SecurityOverlayView()
        }
        .environment(themeManager)
        .environmentObject(securityManager)
        .preferredColorScheme(themeManager.appTheme.colorScheme)
        .onChange(of: scenePhase) { _, newPhase in
            handleScenePhaseChange(newPhase)
        }
            .onReceive(NotificationCenter.default.publisher(for: .didResetData)) { _ in
                themeManager = ThemeManager()
                securityManager.unlock()
                scheduleBootstrap(reason: "local reset")
            }
            .onReceive(NotificationCenter.default.publisher(for: .requestDataReset)) { _ in
                beginLocalResetFlow()
            }
            .onAppear {
                // CloudSyncMonitor initialization moved to ReadyAppRoot.onAppear 
                // to prevent launch traps during bootstrap or repair.
            }
    }

    @ViewBuilder
    private var rootView: some View {
        switch launchState {
        case .launching, .migrating:
            DataRepairLoadingView(isMigrating: launchState == .migrating)
                .task(id: loadingRequest.id) {
                    guard !isResetInProgress else { return }
                    await bootstrapIntoCurrentState(for: loadingRequest)
                }
                .task(id: isResetInProgress) {
                    guard isResetInProgress else { return }
                    await DataResetManager.shared.performLocalWipeHousekeeping()
                }
        case .ready(let container):
            ReadyAppRoot(
                container: container,
                resetID: resetID,
                onAppear: {
                    handleReadyRootAppear(with: container)
                }
            )
        case .failed:
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
        shouldCheckLockOnNextActive = true
        isResetInProgress = false
        launchState = .launching
        loadingRequest = LoadingRequest(reason: reason)
    }

    @MainActor
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        let container = currentContainer

        if newPhase == .active {
            securityManager.checkBiometrics()
        }

        if newPhase != .active {
            protectContentForBackgroundIfNeeded()
        }

        let decision = Self.lockCheckDecision(
            for: newPhase,
            shouldCheckLockOnNextActive: shouldCheckLockOnNextActive,
            isReady: container != nil
        )

        shouldCheckLockOnNextActive = decision.nextShouldCheckLockOnNextActive

        guard decision.action == .authenticate, let container else {
            if newPhase == .active {
                securityManager.clearContentProtection()
            }
            return
        }

        let isLockEnabled = Self.loadEnforceableAppLockEnabled(
            from: container,
            isAppLockAvailable: securityManager.isAppLockAvailable
        )

        guard isLockEnabled else {
            appLockEnabledPreference = false
            securityManager.clearContentProtection()
            return
        }

        appLockEnabledPreference = true
        securityManager.lock()
        securityManager.authenticate()
    }

    @MainActor
    private func protectContentForBackgroundIfNeeded() {
        guard currentContainer != nil else { return }
        guard appLockEnabledPreference || hideAppSwitcher else { return }

        if appLockEnabledPreference {
            securityManager.lock()
        } else {
            securityManager.protectContent()
        }
    }

    @MainActor
    private func beginLocalResetFlow() {
        shouldCheckLockOnNextActive = true
        isResetInProgress = true
        themeManager = ThemeManager()
        securityManager.unlock()
        
        // Disable cloud sync for safety and request a hard wipe on next launch
        // to ensure we can break through any existing file locks.
        DataResetManager.isCloudSyncEnabled = false
        DataResetManager.requestHardWipeOnNextLaunch()
        
        launchState = .launching
    }



    @MainActor
    private func bootstrapIntoCurrentState(for request: LoadingRequest) async {
        guard lastStartedBootstrapID != request.id else { return }
        lastStartedBootstrapID = request.id

        Self.logger.info(
            "Bootstrap starting reason=\(request.reason, privacy: .public)"
        )

        // Implement a 'soft timeout' to update UI if bootstrap takes a while (e.g. migration)
        let softTimeoutTask = Task {
            try? await Task.sleep(nanoseconds: 5 * 1_000_000_000)
            if !Task.isCancelled && launchState == .launching && loadingRequest.id == request.id {
                withAnimation(.easeInOut) {
                    launchState = .migrating
                }
            }
        }

        let nextState = await Self.bootstrapAsync(reason: request.reason)
        softTimeoutTask.cancel()

        guard !Task.isCancelled else { return }
        guard loadingRequest.id == request.id else { return }
        if case .ready = nextState {
            resetID = UUID()
        }

        switch nextState {
        case .launching, .migrating:
            Self.logger.info("Bootstrap resolved → \(nextState == .launching ? "launching" : "migrating", privacy: .public) (unexpected)")
        case .ready:
            Self.logger.info("Bootstrap resolved → ready")
        case .failed:
            Self.logger.warning("Bootstrap resolved → failed")
        }

        launchState = nextState
    }

    @MainActor
    private func syncSecurityPreferences(from container: ModelContainer) {
        let isLockEnabled = Self.loadEnforceableAppLockEnabled(
            from: container,
            isAppLockAvailable: securityManager.isAppLockAvailable
        )
        appLockEnabledPreference = isLockEnabled
    }

    @MainActor
    private func handleReadyRootAppear(with container: ModelContainer) {
        syncSecurityPreferences(from: container)
        handleScenePhaseChange(scenePhase)
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
            return .failed
        }

        lock.lock()
        defer { lock.unlock() }
        return result ?? .failed
    }

    private nonisolated static func bootstrap(reason: String) -> LaunchState {
        let actions = BootstrapActions<ModelContainer>(
            makePrimary: { try makePrimaryContainer(stage: $0) },
            quarantineDefaultStoreForRepair: { try DataResetManager.quarantineDefaultStoreForRepair() },
            removeFallbackStoreFiles: { try DataResetManager.removeFallbackStoreFiles() },
            makeFallback: { try makeFallbackContainer() },
            makeInMemory: { try makeInMemoryContainer() },
            logBootstrapFailure: { error, stage, reason in
                logBootstrapFailure(error, stage: stage, reason: reason)
            },
            logHousekeepingFailure: { error, action in
                logHousekeepingFailure(error, action: action)
            },
            logFallbackLaunch: {
                logger.notice("Launching with an isolated local fallback store.")
            },
            logInMemoryLaunch: {
                logger.notice("Launching with an in-memory recovery store.")
            }
        )

        switch runBootstrapFlow(reason: reason, actions: actions) {
        case .ready(let container, _):
            return .ready(container)
        case .repair:
            return .failed
        }
    }

    @MainActor
    static func loadAppLockEnabled(from container: ModelContainer) -> Bool {
        let context = container.mainContext
        do {
            return try UserSettings.fetchAppLockEnabled(from: context)
        } catch {
            Self.logger.error("Failed to fetch settings for lock check: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    @MainActor
    static func loadEnforceableAppLockEnabled(
        from container: ModelContainer,
        isAppLockAvailable: Bool
    ) -> Bool {
        let context = container.mainContext
        do {
            // Use reconcileSingleton instead of fetchAppLockEnabled here to
            // ensure any orphaned duplicates from a previous crash/reset
            // are cleared without triggering an immediate context save
            // during the startup environment propagation.
            let settings = try UserSettings.reconcileSingleton(in: context, shouldSaveIfChanged: false)
            let isEnabled = settings?.appLockEnabled == true

            guard isEnabled else { return false }
            guard isAppLockAvailable else {
                try UserSettings.setAppLockEnabled(false, in: context)
                return false
            }
            return true
        } catch {
            Self.logger.error("Failed to reconcile app lock settings: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private nonisolated static func makePrimaryContainer(stage: BootstrapStage) throws -> ModelContainer {
        try DebugBootstrapControl.injectFailureIfNeeded(for: stage)
        
        let storeURL = DataResetManager.defaultStoreURL
        try DataResetManager.ensureStoreParentDirectoryExists(for: storeURL)

        // Explicitly define the configuration with our robustly-resolved URL.
        let configuration = ModelConfiguration(
            "PrimaryLocalStore",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: cloudKitDatabase
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: CBTModelMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private nonisolated static func makeFallbackContainer() throws -> ModelContainer {
        try DebugBootstrapControl.injectFailureIfNeeded(for: .fallback)
        
        let storeURL = DataResetManager.fallbackStoreURL
        try DataResetManager.ensureStoreParentDirectoryExists(for: storeURL)

        let configuration = ModelConfiguration(
            "LocalRecovery",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none // Always skip CloudKit for fallback recovery
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: CBTModelMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private nonisolated static func makeInMemoryContainer() throws -> ModelContainer {
        try DebugBootstrapControl.injectFailureIfNeeded(for: .inMemory)

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none // Always skip CloudKit for in-memory recovery
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: CBTModelMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private nonisolated static var cloudKitDatabase: ModelConfiguration.CloudKitDatabase {
        DataResetManager.isCloudSyncEnabled ? .automatic : .none
    }

    nonisolated static func runBootstrapFlow<Resource: Sendable>(
        reason: String,
        actions: BootstrapActions<Resource>
    ) -> BootstrapAttemptResult<Resource> {
        do {
            return .ready(try actions.makePrimary(.primary), .primary)
        } catch {
            actions.logBootstrapFailure(error, .primary, reason)
        }

        do {
            if try actions.quarantineDefaultStoreForRepair() != nil {
                logger.notice("Quarantined the default store before retrying model bootstrap.")
            }
        } catch {
            actions.logHousekeepingFailure(error, "quarantine-default-store")
        }

        do {
            return .ready(try actions.makePrimary(.primaryRecovery), .primaryRecovery)
        } catch {
            actions.logBootstrapFailure(error, .primaryRecovery, reason)
        }

        do {
            try actions.removeFallbackStoreFiles()
        } catch {
            actions.logHousekeepingFailure(error, "clear-fallback-store")
        }

        do {
            actions.logFallbackLaunch()
            return .ready(try actions.makeFallback(), .fallback)
        } catch {
            actions.logBootstrapFailure(error, .fallback, reason)
        }

        do {
            actions.logInMemoryLaunch()
            return .ready(try actions.makeInMemory(), .inMemory)
        } catch {
            actions.logBootstrapFailure(error, .inMemory, reason)
            return .repair
        }
    }

    nonisolated static func lockCheckDecision(
        for newPhase: ScenePhase,
        shouldCheckLockOnNextActive: Bool,
        isReady: Bool
    ) -> LockCheckDecision {
        switch newPhase {
        case .background:
            return LockCheckDecision(
                nextShouldCheckLockOnNextActive: true,
                action: .none
            )
        case .active:
            guard shouldCheckLockOnNextActive, isReady else {
                return LockCheckDecision(
                    nextShouldCheckLockOnNextActive: shouldCheckLockOnNextActive,
                    action: .none
                )
            }

            return LockCheckDecision(
                nextShouldCheckLockOnNextActive: false,
                action: .authenticate
            )
        case .inactive:
            return LockCheckDecision(
                nextShouldCheckLockOnNextActive: shouldCheckLockOnNextActive,
                action: .none
            )
        @unknown default:
            return LockCheckDecision(
                nextShouldCheckLockOnNextActive: shouldCheckLockOnNextActive,
                action: .none
            )
        }
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

private struct SecurityOverlayView: View {
    @EnvironmentObject var securityManager: SecurityManager
    @Environment(ThemeManager.self) var themeManager
    @State private var overlayManager: SecurityOverlayManager?

    var body: some View {
        Color.clear
            .onAppear {
                if overlayManager == nil {
                    overlayManager = SecurityOverlayManager(
                        securityManager: securityManager,
                        themeManager: themeManager
                    )
                }
            }
    }
}







