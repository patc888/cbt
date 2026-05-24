import SwiftUI
import SwiftData
import OSLog

private struct CloudSettingsSyncObserver: View {
    private static let logger = AppLogger.make(category: "CloudSettingsSyncObserver")

    @Environment(\.modelContext) private var modelContext
    @Query private var settingsList: [UserSettings]

    private var syncState: CloudSettingsSnapshot? {
        guard let settings = settingsList.first else { return nil }
        return CloudSettingsSnapshot(settings: settings)
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: syncState) {
                await syncSettings()
            }
    }

    @MainActor
    private func syncSettings() async {
        do {
            let settings = try settingsList.first ?? UserSettings.fetchOrCreate(in: modelContext)
            HapticManager.shared.setEnabled(settings.hapticsEnabled ?? true)
            CloudSettingsManager.shared.syncOnLocalChange(settings: settings)
        } catch {
            Self.logger.error("Failed to bootstrap cloud settings sync: \(error.localizedDescription, privacy: .private)")
        }
    }
}

@main
struct CBTApp: App {
    // MARK: - Model Container Bootstrap

    private struct ModelContainerBootstrap {
        let container: ModelContainer?
        let cloudKitEnabled: Bool
        let recoveryMessage: String?
        let cloudKitFailureReason: String?
    }

    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "CBT",
        category: "App"
    )

    private static let modelContainerBootstrap: ModelContainerBootstrap = {
        // MARK: - Attempt 1: App Group location + CloudKit sync
        do {
            let recovery = try ModelContainerRecovery(
                schema: SharedPersistence.schema,
                groupID: AppConfiguration.appGroupIdentifier
            )
            .makeModelContainerRecovery()

            if recovery.cloudKitEnabled {
                logger.info("[SwiftData] Successfully using App Group + CloudKit store")
                return ModelContainerBootstrap(container: recovery.container, cloudKitEnabled: true, recoveryMessage: nil, cloudKitFailureReason: nil)
            }

            let cloudKitFailureReason = recovery.cloudKitFailure.map(Self.userVisibleCloudKitFailureReason(from:))
                ?? "CloudKit storage could not start. CBT is using local storage for this launch."
            logger.info("[SwiftData] Successfully using App Group local store after CloudKit recovery fallback")
            return ModelContainerBootstrap(
                container: recovery.container,
                cloudKitEnabled: false,
                recoveryMessage: "CBT couldn't start iCloud sync and is temporarily using local storage. Your data will stay on this device until iCloud storage opens successfully.",
                cloudKitFailureReason: cloudKitFailureReason
            )
        } catch {
            logger.info("[SwiftData] App Group + CloudKit failed: \(String(describing: error), privacy: .public)")
            let cloudKitFailureReason = Self.userVisibleCloudKitFailureReason(from: error)

            // MARK: - Attempt 2: App Group location without CloudKit
            do {
                let container = try SharedPersistence.makeModelContainer(cloudKitEnabled: false)
                logger.info("[SwiftData] Successfully using App Group local store")
                return ModelContainerBootstrap(
                    container: container,
                    cloudKitEnabled: false,
                    recoveryMessage: "CBT couldn't start iCloud sync and is temporarily using local storage. Your data will stay on this device until iCloud storage opens successfully.",
                    cloudKitFailureReason: cloudKitFailureReason
                )
            } catch {
                logger.info("[SwiftData] App Group local store failed: \(error.localizedDescription)")
            }
        }

        // Last resort: show the app instead of crashing if the persistent store
        // cannot be opened on this launch.
        do {
            let container = try SharedPersistence.makeInMemoryModelContainer()
            return ModelContainerBootstrap(
                container: container,
                cloudKitEnabled: false,
                recoveryMessage: "CBT couldn't open its persistent store and started in temporary recovery mode. Changes may not persist until you relaunch the app.",
                cloudKitFailureReason: "The persistent store could not be opened, so CBT started in temporary recovery mode."
            )
        } catch {
            return ModelContainerBootstrap(
                container: nil,
                cloudKitEnabled: false,
                recoveryMessage: "CBT couldn't open its data store. Relaunch the app. If the problem continues, restart the device or reinstall the app.",
                cloudKitFailureReason: "The persistent store could not be opened."
            )
        }
    }()

    private var sharedModelContainer: ModelContainer? {
        Self.modelContainerBootstrap.container
    }

    // MARK: - State

    @StateObject private var securityManager = SecurityManager.shared
    @StateObject private var cloudSyncStatusMonitor = CloudSyncStatusMonitor.shared
    @State private var cloudKitSyncMonitor = CloudKitSyncMonitor.shared
    @State private var themeManager = ThemeManager()
    @State private var hasCheckedLockOnLaunch = false
    @State private var storageRecoveryMessage: String?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        _storageRecoveryMessage = State(initialValue: Self.modelContainerBootstrap.recoveryMessage)
        ContextualNotificationService.shared.configureAsNotificationDelegate()

        if let modelContainer = Self.modelContainerBootstrap.container {
            let cloudManager = CloudSettingsManager.shared
            cloudManager.modelContainer = modelContainer
        }

        UserDefaults.standard.set(
            Self.modelContainerBootstrap.cloudKitEnabled,
            forKey: AppConfiguration.cloudKitEnabledKey
        )
        UserDefaults.standard.set(
            Self.modelContainerBootstrap.cloudKitEnabled ? "cloudKit" : "local",
            forKey: AppConfiguration.persistenceModeKey
        )
        if let recoveryMessage = Self.modelContainerBootstrap.recoveryMessage {
            UserDefaults.standard.set(recoveryMessage, forKey: AppConfiguration.cloudKitRecoveryMessageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: AppConfiguration.cloudKitRecoveryMessageKey)
        }
        if let failureReason = Self.modelContainerBootstrap.cloudKitFailureReason {
            UserDefaults.standard.set(failureReason, forKey: AppConfiguration.cloudKitFailureReasonKey)
        } else {
            UserDefaults.standard.removeObject(forKey: AppConfiguration.cloudKitFailureReasonKey)
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
                securityManager.checkBiometrics()
                await DailyReminderService.shared.refreshQuoteOfTheDayIfEnabled()
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
            .environmentObject(cloudSyncStatusMonitor)
            .environment(cloudKitSyncMonitor)
            .environment(themeManager)
            .modelContainer(modelContainer)
            .overlay {
                CloudSettingsSyncObserver()
                    .allowsHitTesting(false)
            }
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
                    Task {
                        await DailyReminderService.shared.refreshQuoteOfTheDayIfEnabled()
                    }
                }
            }
    }

    private static func userVisibleCloudKitFailureReason(from error: Error) -> String {
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

        if details.isEmpty {
            return "CloudKit storage could not start. CBT is using local storage for this launch."
        }

        return "CloudKit storage could not start: \(details)"
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
