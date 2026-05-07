import os
import SwiftData
import SwiftUI
#if os(iOS)
import UIKit
#endif

private let logger = Logger(subsystem: "com.xeo.timeblocking", category: "SettingsView")

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Query private var preferences: [AppPreferences]

    private var appPreferences: AppPreferences? {
        preferences.first
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var metrics: LayoutMetrics { LayoutMetrics.metrics(for: horizontalSizeClass) }

    @Environment(\.dismiss) private var dismiss
    @State private var showingResetOptions = false
    @State private var showingSubscription = false
    @State private var notificationAccessState: TimeNotificationManager.AccessState = .notDetermined
    @StateObject private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                ThemedBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        mainContent
                    }
                    .responsiveMaxWidth(maxWidth: metrics.contentMaxWidth)
                }
                .padding(.top, 60)

                closeButton
                    .padding(.trailing, 20)
                    .padding(.top, 60)
            }
            .ignoresSafeArea()
            .navigationTitle("")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
#endif
        }
#if os(iOS)
        .statusBarHidden(true)
#endif
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar, .bottomBar, .tabBar)
#else
        .toolbar(.hidden, for: .windowToolbar)
#endif
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
            await subscriptionManager.checkSubscriptionStatus()
            syncSubscriptionStatus()
            await refreshNotificationAccessState()
        }
        .onChange(of: subscriptionManager.isPremium) { _, _ in
            syncSubscriptionStatus()
        }
        .timeSubscriptionPresentation(isPresented: $showingSubscription)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            Task {
                await subscriptionManager.checkSubscriptionStatus()
                syncSubscriptionStatus()
                await refreshNotificationAccessState()

                if appPreferences?.notificationsEnabled ?? false {
                    await appEnvironment.resyncNotifications(using: modelContext)
                }
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 16) {
            TimeTopHeadlineView(title: "Settings")
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

                SubscriptionSettingsView(
                    subscriptionManager: subscriptionManager,
                    onPresentPaywall: presentSubscription
                )

                TimeAppearanceSettingsView(
                    preferences: appPreferences,
                    onUpdate: updatePreferences
                )

                TimeSecuritySettingsView(
                    preferences: appPreferences
                )

                TimeNotificationsSettingsView(
                    preferences: appPreferences,
                    accessState: notificationAccessState,
                    onUpdate: updatePreferences,
                    onEnabledChanged: setNotificationsEnabled,
                    onLeadTimeChanged: resyncNotifications,
                    onOpenSystemSettings: openNotificationSettings
                )

                TimeDataManagementSettingsView()

                TimeAboutSettingsView {
                    HapticManager.shared.mediumImpact()
                    showingResetOptions = true
                }
                .padding(.bottom, 24)

                VersionFooterView()
                    .padding(.bottom, 40)
            }
        }
        .padding(.horizontal, 16)
    }

    private var closeButton: some View {
        TimeDismissButton(style: .chevron)
    }

    private func updatePreferences(_ update: (AppPreferences) -> Void) {
        guard let appPreferences else {
            return
        }

        update(appPreferences)
        try? appEnvironment.preferencesStore.save(appPreferences, in: modelContext)
        appEnvironment.syncPreferencesToUserDefaults(using: modelContext)
    }

    private func presentSubscription() {
        showingSubscription = true
    }

    private func syncSubscriptionStatus() {
        guard let appPreferences else {
            return
        }

        appPreferences.isPremium = subscriptionManager.isPremium
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


