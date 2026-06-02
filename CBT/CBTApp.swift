import OSLog
import SwiftUI
import SwiftData

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

    private static let modelContainerBootstrap = CloudStorageBootstrap.makeModelContainer()

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
        AppConfiguration.registerUserDefaults()
        _storageRecoveryMessage = State(initialValue: Self.modelContainerBootstrap.recoveryMessage)
        ContextualNotificationService.shared.configureAsNotificationDelegate()

        if let modelContainer = Self.modelContainerBootstrap.container {
            let cloudManager = CloudSettingsManager.shared
            cloudManager.modelContainer = modelContainer
        }

        CloudStorageBootstrap.publish(Self.modelContainerBootstrap)
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
            .task {
                await PersonalizedReminderService.shared.refreshEnabledReminders(modelContext: modelContainer.mainContext)
                await StreakReengagementNotificationService.shared.handleAppLogin(modelContext: modelContainer.mainContext)
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    if !hasCheckedLockOnLaunch {
                        hasCheckedLockOnLaunch = true
                    }
                    Task {
                        await DailyReminderService.shared.refreshQuoteOfTheDayIfEnabled()
                        await PersonalizedReminderService.shared.refreshEnabledReminders(modelContext: modelContainer.mainContext)
                        await StreakReengagementNotificationService.shared.handleAppLogin(modelContext: modelContainer.mainContext)
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
