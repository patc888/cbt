import SwiftData
import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query private var preferences: [AppPreferences]

    private var appPreferences: AppPreferences? {
        preferences.first
    }

    @Environment(\.dismiss) private var dismiss
    @State private var showingResetAlert = false
    @State private var notificationAccessState: TimeNotificationManager.AccessState = .notDetermined

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    mainContent
                }
                .frame(maxWidth: 600)
            }
            .frame(maxWidth: 600)
            .padding(.top, 50) // Adjust for close button area

            navigationArrow
        }
        .navigationTitle("")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
#endif
        .alert("Reset All Data", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will delete all your schedule blocks and routines. This action cannot be undone.")
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
        VStack(spacing: 20) {
            HStack {
                Text("Settings")
                    .font(.system(size: Theme.fontSizeTitle, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
            }
            .padding(.top, 12)
            .padding(.bottom, 8)

            if appPreferences == nil {
                TimeSettingsSection(title: "Setup") {
                    EmptyStateView(
                        title: "Settings Are Preparing",
                        systemImage: "gearshape.2.fill",
                        message: "Your preferences are still loading. Reopen Settings in a moment if controls do not appear yet.",
                        eyebrow: "Settings"
                    )
                    .padding(.vertical, 8)
                }
            } else {
                TimeSubscriptionSettingsView(
                    isPremium: appEnvironment.subscriptionStore.isPremium,
                    action: {
                        HapticManager.shared.lightImpact()
                        appEnvironment.appState.showPremium()
                    }
                )

                TimeSchedulingSettingsView(
                    preferences: appPreferences,
                    onUpdate: updatePreferences
                )

                TimeAppearanceSettingsView(
                    preferences: appPreferences,
                    onUpdate: updatePreferences
                )

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
                    showingResetAlert = true
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    private var navigationArrow: some View {
        Button(action: {
            HapticManager.shared.lightImpact()
            dismiss()
        }) {
            Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.primaryPurple)
                .frame(width: 32, height: 32)
                .background(Theme.primaryPurple.opacity(0.1))
                .clipShape(Circle())
        }
        .padding(.trailing, 20)
        .padding(.top, 12)
    }

    private func updatePreferences(_ update: (AppPreferences) -> Void) {
        guard let appPreferences else {
            return
        }

        update(appPreferences)
        try? appEnvironment.preferencesStore.save(appPreferences, in: modelContext)
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
        UIApplication.shared.open(url)
#elseif os(macOS)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
#endif
    }

    private func resetAllData() {
        HapticManager.shared.lightImpact()
        do {
            try modelContext.delete(model: TimeBlock.self)
            try modelContext.delete(model: ScheduleTemplate.self)
            try modelContext.delete(model: BlockChecklistItem.self)
            
            if let prefs = appPreferences {
                prefs.defaultBlockDurationMinutes = 60
                prefs.dayStartHour = 6
                prefs.firstWeekday = .monday
                prefs.notificationsEnabled = false
                prefs.notificationLeadTimeMinutes = 0
                prefs.showsCompletedBlocks = true
            }
            
            try modelContext.save()
            Task {
                await appEnvironment.resyncNotifications(using: modelContext)
            }
        } catch {
            print("Error resetting data: \(error)")
        }
    }
}
