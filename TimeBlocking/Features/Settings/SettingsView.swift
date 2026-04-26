import os
import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

private let logger = Logger(subsystem: "com.melichan.TimeBlocking", category: "SettingsView")

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Query private var preferences: [AppPreferences]

    private var appPreferences: AppPreferences? {
        preferences.first
    }

    @Environment(\.dismiss) private var dismiss
    @State private var showingResetOptions = false
    @State private var notificationAccessState: TimeNotificationManager.AccessState = .notDetermined

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AuroraBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        mainContent
                    }
                    .frame(maxWidth: 600)
                    .padding(.top, 60)
                    .padding(.bottom, 40)
                }
                .frame(maxWidth: .infinity)

                HStack {
                    Spacer()
                    closeButton
                }
                .padding(.trailing, 24)
                .padding(.top, 60)
            }
            .ignoresSafeArea()
        }
        .statusBarHidden(true)
        .toolbar(.hidden, for: .navigationBar, .bottomBar, .tabBar)
        .confirmationDialog("Reset Data", isPresented: $showingResetOptions, titleVisibility: .visible) {
            Button("Reset to Empty", role: .destructive) {
                resetAllDataToEmpty()
            }
            Button("Reset to Sample Data", role: .destructive) {
                resetAllDataToSample()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose whether to clear everything to a blank app or wipe current data and restore the sample schedule.")
        }
        .task {
            await refreshNotificationAccessState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await refreshNotificationAccessState()

                if appPreferences?.notificationsEnabled ?? false {
                    await appEnvironment.resyncNotifications(using: modelContext)
                }
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Text("Settings")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 4)

            if appPreferences == nil {
                TimeSettingsSection(
                    title: "Setup"
                ) {
                    EmptyStateView(
                        title: "Settings Are Preparing",
                        systemImage: "gearshape.2.fill",
                        message: "Your preferences are still loading. Reopen Settings in a moment if controls do not appear yet.",
                        eyebrow: "Settings"
                    )
                    .padding(.vertical, 8)
                }
            } else {
                TimeSchedulingSettingsView(
                    preferences: appPreferences,
                    onUpdate: updatePreferences
                )

                TimeAppearanceSettingsView(
                    preferences: appPreferences,
                    onUpdate: updatePreferences
                )

                TimeSecuritySettingsView(
                    preferences: appPreferences
                )

                WhatIsTimeBlockingCard()
                    .padding(.top, 8)

                TimeNotificationsSettingsView(
                    preferences: appPreferences,
                    accessState: notificationAccessState,
                    onUpdate: updatePreferences,
                    onEnabledChanged: setNotificationsEnabled,
                    onLeadTimeChanged: resyncNotifications,
                    onOpenSystemSettings: openNotificationSettings
                )

                TimeAboutSettingsView {
                    HapticManager.shared.mediumImpact()
                    showingResetOptions = true
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private var closeButton: some View {
        Button {
            HapticManager.shared.lightImpact()
            appEnvironment.appState.showScheduleHome()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.primaryAccent)
                .frame(width: 36, height: 36)
                .background(Theme.primaryAccent.opacity(0.1))
                .clipShape(Circle())
        }
    }

    private func updatePreferences(_ update: (AppPreferences) -> Void) {
        guard let appPreferences else {
            return
        }

        update(appPreferences)
        try? appEnvironment.preferencesStore.save(appPreferences, in: modelContext)
        appEnvironment.syncPreferencesToUserDefaults(using: modelContext)
    }


    private func setNotificationsEnabled(_ isEnabled: Bool) {
        Task {
            if isEnabled {
                _ = await appEnvironment.timeNotificationManager.requestAuthorizationIfNeeded()
                await refreshNotificationAccessState()
            }

            await appEnvironment.resyncNotifications(using: modelContext)
            await refreshNotificationAccessState()
        }
    }

    private func resyncNotifications() {
        Task {
            await appEnvironment.resyncNotifications(using: modelContext)
            await refreshNotificationAccessState()
        }
    }

    private func refreshNotificationAccessState() async {
        notificationAccessState = await appEnvironment.timeNotificationManager.accessState()
    }

    private func openNotificationSettings() {
#if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        openURL(url)
#elseif os(macOS)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        openURL(url)
#endif
    }

    private func resetAllDataToEmpty() {
        HapticManager.shared.lightImpact()
        Task {
            do {
                try await appEnvironment.resetAllDataToEmpty(using: modelContext)
            } catch {
                logger.error("Failed to reset data to empty: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func resetAllDataToSample() {
        HapticManager.shared.lightImpact()
        Task {
            do {
                try await appEnvironment.resetAllDataToSample(using: modelContext)
            } catch {
                logger.error("Failed to reset data to sample: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}
