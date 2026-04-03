import OSLog
import Foundation
import SwiftData
import SwiftUI

@main
struct CBTApp: App {
    private nonisolated static let bootstrapTimeoutSeconds: TimeInterval = 12

    fileprivate enum LaunchState: Sendable {
        case launching
        case preparingContainer(ModelContainer)
        case ready(ModelContainer)
        case failed
    }

    private var currentContainer: ModelContainer? {
        guard case .ready(let container) = launchState else { return nil }
        return container
    }

    private var isProtectedDataReady: Bool {
        currentContainer != nil
    }

    private struct LoadingRequest: Sendable {
        let id = UUID()
        let reason: String
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

    nonisolated struct BootstrapActions<Resource: Sendable>: Sendable {
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

    nonisolated enum BootstrapAttemptResult<Resource: Sendable> {
        case ready(Resource, BootstrapResolution)
        case repair
    }

    struct LockCheckDecision: Equatable {
        enum Action: Equatable {
            case none
            case authenticate
        }

        let nextShouldCheckLockOnNextActive: Bool
        let action: Action
    }

    fileprivate enum BootstrapError: Error, Sendable {
        case debugInjectedFailure(String)
    }

    private nonisolated static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CBT",
        category: "AppBootstrap"
    )

    private nonisolated static let schema = Schema([
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
    @AppStorage("appLockEnabled") private var appLockEnabledPreference = false
    @AppStorage("hideAppSwitcher") private var hideAppSwitcher = false
    @State private var shouldCheckLockOnNextActive = true
    @State private var lastStartedBootstrapID: UUID?
    @State private var isResetInProgress = false

    init() {
        let initialRequest = LoadingRequest(reason: "app launch")
        _launchState = State(initialValue: .launching)
        _loadingRequest = State(initialValue: initialRequest)
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .environment(themeManager)
                .preferredColorScheme(themeManager.appTheme.colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
                .onChange(of: isProtectedDataReady) { _, isReady in
                    guard isReady, let container = currentContainer else { return }
                    syncSecurityPreferences(from: container)
                    handleScenePhaseChange(scenePhase)
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
        case .launching:
            DataRepairLoadingView()
                .task(id: loadingRequest.id) {
                    guard !isResetInProgress else { return }
                    await bootstrapIntoCurrentState(for: loadingRequest)
                }
                .task(id: isResetInProgress) {
                    guard isResetInProgress else { return }
                    await DataResetManager.shared.performLocalWipeHousekeeping()
                }
        case .preparingContainer(let container), .ready(let container):
            AppContainerGate(
                launchState: $launchState,
                container: container,
                resetID: resetID
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
        launchState = .launching
    }

    @MainActor
    private func bootstrapIntoCurrentState(for request: LoadingRequest) async {
        guard lastStartedBootstrapID != request.id else { return }
        lastStartedBootstrapID = request.id

        Self.logger.info(
            "Bootstrap starting reason=\(request.reason, privacy: .public)"
        )

        let nextState = await Self.bootstrapAsync(reason: request.reason)

        guard !Task.isCancelled else { return }
        guard loadingRequest.id == request.id else { return }
        if case .preparingContainer = nextState {
            resetID = UUID()
        }

        switch nextState {
        case .launching:
            Self.logger.info("Bootstrap resolved → launching (unexpected)")
        case .preparingContainer:
            Self.logger.info("Bootstrap resolved → preparingContainer")
        case .ready:
            Self.logger.info("Bootstrap resolved → ready (unexpected)")
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
            return .preparingContainer(container)
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
            let isEnabled = try UserSettings.fetchAppLockEnabled(from: context)
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

        // CloudKit stays behind a single app-wide capability switch so the
        // persistence stack and settings copy cannot drift out of sync.
        let configuration = ModelConfiguration(
            "PrimaryLocalStore",
            schema: schema,
            url: DataResetManager.defaultStoreURL,
            cloudKitDatabase: cloudKitDatabase
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private nonisolated static func makeFallbackContainer() throws -> ModelContainer {
        try DebugBootstrapControl.injectFailureIfNeeded(for: .fallback)

        let configuration = ModelConfiguration(
            "LocalRecovery",
            schema: schema,
            url: DataResetManager.fallbackStoreURL,
            cloudKitDatabase: cloudKitDatabase
        )

        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private nonisolated static func makeInMemoryContainer() throws -> ModelContainer {
        try DebugBootstrapControl.injectFailureIfNeeded(for: .inMemory)

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: cloudKitDatabase
        )

        return try ModelContainer(for: schema, configurations: [configuration])
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

private struct AppContainerGate: View {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CBT",
        category: "AppContainerGate"
    )

    @Binding var launchState: CBTApp.LaunchState
    let container: ModelContainer
    let resetID: UUID

    @StateObject private var securityManager = SecurityManager.shared
    @State private var isContainerSettled = false

    var body: some View {
        ZStack {
            if isContainerSettled {
                ContentView()
                    .id(resetID)
                    .transition(.opacity)
                    .onAppear {
                        if case .preparingContainer = launchState {
                            launchState = .ready(container)
                        }
                        logMainUIPresented()
                    }
            } else {
                ContainerReadinessGate(onReady: {
                    settleContainerEnvironment()
                })
                .transition(.opacity)
            }

            if securityManager.isContentProtected {
                securityCover
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isContainerSettled)
        .animation(.easeInOut(duration: 0.15), value: securityManager.isContentProtected)
        .modelContainer(container)
        .environmentObject(securityManager)
        .onChange(of: resetID) { _, _ in
            isContainerSettled = false
            if case .ready = launchState {
                launchState = .preparingContainer(container)
            }
        }
    }

    @ViewBuilder
    private var securityCover: some View {
        if securityManager.isLocked {
            LockView()
        } else {
            PrivacyShieldView()
        }
    }

    @MainActor
    private func settleContainerEnvironment() {
        guard !isContainerSettled else { return }

        Task { @MainActor in
            // Give SwiftUI one more main-actor turn after injecting
            // `.modelContainer(container)` before constructing any view
            // tree that contains `@Query`.
            await Task.yield()
            guard !isContainerSettled else { return }
            isContainerSettled = true

            if case .preparingContainer = launchState {
                Self.logger.info("Container environment safely populated – advancing to ready state. resetID=\(resetID.uuidString.prefix(8), privacy: .public)")
                launchState = .ready(container)
            }
        }
    }

    private func logMainUIPresented() {
        let platform: String
        #if targetEnvironment(macCatalyst)
        platform = "macCatalyst"
        #elseif canImport(UIKit)
        platform = UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "iPhone"
        #else
        platform = "macOS"
        #endif
        Self.logger.info(
            "Main UI presented – platform=\(platform, privacy: .public) resetID=\(resetID.uuidString.prefix(8), privacy: .public)"
        )
    }
}

private struct ContainerReadinessGate: View {
    @Environment(\.modelContext) private var modelContext
    let onReady: () -> Void

    var body: some View {
        BootstrapGateView()
            .task {
                // Force the environment-backed model context to resolve
                // before the app advances to query-backed content, then
                // give SwiftUI another turn to propagate the environment
                // through the root navigation/tab containers on iPad.
                _ = modelContext.container
                await Task.yield()
                guard !Task.isCancelled else { return }
                onReady()
            }
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

/// Shown inside `ReadyRootView` for exactly one run-loop tick while the
/// `.modelContainer` modifier settles into the SwiftUI environment.
///
/// # Safety contract
/// This view **must never** contain:
/// - `@Query`
/// - `@Environment(\.modelContext)`
/// - Any `SwiftData` import or model reference
/// - Any child view that reads from the model container
///
/// It exists solely to occupy the view hierarchy while
/// `.modelContainer(container)` propagates, preventing premature
/// `@Query` evaluation on iPhone, iPad, and Mac Catalyst.
///
/// On Mac Catalyst, this gate also prevents window restoration from
/// instantiating query-backed views before the container is stable —
/// `@State isContainerSettled` in `ReadyRootView` is not persisted
/// across app launches, so the gate always starts closed.
private struct BootstrapGateView: View {
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
