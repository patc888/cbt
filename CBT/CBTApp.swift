import SwiftUI
import SwiftData
import OSLog

@main
struct CBTApp: App {
    // MARK: - Model Container Bootstrap

    private struct ModelContainerBootstrap {
        let container: ModelContainer?
        let cloudKitEnabled: Bool
        let recoveryMessage: String?
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CBT",
        category: "App"
    )

    private static let modelContainerBootstrap: ModelContainerBootstrap = {
        let shouldUseCloudKit = DataResetManager.isCloudSyncEnabled

        if !shouldUseCloudKit {
            do {
                let container = try SharedPersistence.makeModelContainer(cloudKitEnabled: false)
                logger.info("[SwiftData] Successfully using local store because CloudKit sync is disabled")
                return ModelContainerBootstrap(container: container, cloudKitEnabled: false, recoveryMessage: nil)
            } catch {
                logger.info("[SwiftData] Local store failed while CloudKit sync was disabled: \(error.localizedDescription)")
            }
        }

        // MARK: - Attempt 1: Default store + CloudKit sync (ideal path)
        do {
            let container = try SharedPersistence.makeModelContainer(cloudKitEnabled: true)
            logger.info("[SwiftData] Successfully using default store + CloudKit")
            return ModelContainerBootstrap(container: container, cloudKitEnabled: true, recoveryMessage: nil)
        } catch {
            logger.info("[SwiftData] Default + CloudKit failed: \(error.localizedDescription)")
        }

        // MARK: - Attempt 2: Default store, no CloudKit (offline fallback)
        do {
            let container = try SharedPersistence.makeModelContainer(cloudKitEnabled: false)
            logger.info("[SwiftData] Successfully using default local store (CloudKit disabled)")
            return ModelContainerBootstrap(container: container, cloudKitEnabled: false, recoveryMessage: nil)
        } catch {
            logger.info("[SwiftData] Default local store failed: \(error.localizedDescription)")
        }

        // MARK: - Attempt 3: In-memory recovery (last resort)
        do {
            let container = try SharedPersistence.makeInMemoryModelContainer()
            return ModelContainerBootstrap(
                container: container,
                cloudKitEnabled: false,
                recoveryMessage: "CBT couldn't open its persistent store and started in temporary recovery mode. Changes may not persist until you relaunch the app."
            )
        } catch {
            return ModelContainerBootstrap(
                container: nil,
                cloudKitEnabled: false,
                recoveryMessage: "CBT couldn't open its data store. Relaunch the app. If the problem continues, restart the device or reinstall the app."
            )
        }
    }()

    private var sharedModelContainer: ModelContainer? {
        Self.modelContainerBootstrap.container
    }

    // MARK: - State

    @StateObject private var securityManager = SecurityManager.shared
    @State private var themeManager = ThemeManager()
    @State private var hasCheckedLockOnLaunch = false
    @State private var storageRecoveryMessage: String?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _storageRecoveryMessage = State(initialValue: Self.modelContainerBootstrap.recoveryMessage)

        // Start CloudKit sync monitoring early
        if Self.modelContainerBootstrap.cloudKitEnabled {
            CloudSyncMonitor.shared.startMonitoring()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let modelContainer = sharedModelContainer {
                    appRoot(modelContainer: modelContainer)
                } else {
                    storageUnavailableView
                }
            }
            .task {
                // Perform non-blocking biometrics check after launch
                try? await Task.sleep(for: .milliseconds(200))
                securityManager.checkBiometrics()
            }
            .environment(themeManager)
            .alert(
                "Storage Unavailable",
                isPresented: Binding(
                    get: { storageRecoveryMessage != nil },
                    set: { presented in
                        if !presented {
                            storageRecoveryMessage = nil
                        }
                    }
                )
            ) {
                Button("OK", role: .cancel) {
                    storageRecoveryMessage = nil
                }
            } message: {
                Text(storageRecoveryMessage ?? "")
            }
        }
    }

    // MARK: - App Root

    private func appRoot(modelContainer: ModelContainer) -> some View {
        ContentView()
            .environmentObject(securityManager)
            .environment(themeManager)
            .modelContainer(modelContainer)
            .overlay {
                if securityManager.isLocked {
                    SecurityCoverRoot()
                        .environment(themeManager)
                        .environmentObject(securityManager)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    if !hasCheckedLockOnLaunch {
                        hasCheckedLockOnLaunch = true
                    }
                    // Refresh sync status when foregrounding
                    if Self.modelContainerBootstrap.cloudKitEnabled {
                        CloudSyncMonitor.shared.refreshAccountStatus()
                    }
                }
            }
    }

    // MARK: - Storage Unavailable

    private var storageUnavailableView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            ContentUnavailableView(
                "Couldn't Start CBT",
                systemImage: "exclamationmark.triangle.fill",
                description: Text("CBT couldn't open its data store. Relaunch the app to try again.")
            )
            .padding(24)
        }
    }
}
