import SwiftUI
import UserNotifications

struct RemindersSettingsSection: View {
    @AppStorage("cbt_moodReminderEnabled") private var moodReminderEnabled = false
    @AppStorage("cbt_reflectionReminderEnabled") private var reflectionReminderEnabled = false
    @AppStorage("cbt_quoteOfTheDayEnabled") private var quoteOfTheDayEnabled = false

    @AppStorage("cbt_moodReminderHour") private var moodReminderHour = 9
    @AppStorage("cbt_moodReminderMinute") private var moodReminderMinute = 0

    @AppStorage("cbt_reflectionReminderHour") private var reflectionReminderHour = 20
    @AppStorage("cbt_reflectionReminderMinute") private var reflectionReminderMinute = 0

    @Environment(ThemeManager.self) private var themeManager
    @State private var authorizationStatus: PermissionManager.Status = .notDetermined
    @State private var isShowingPermissionSheet = false

    private let dailyReminderService = DailyReminderService.shared

    var body: some View {
        SettingsSection(title: String(localized: "Reminders")) {
            ToggleRow(
                icon: "bell.badge.fill",
                iconColor: themeManager.primaryColor,
                title: String(localized: "Reminders"),
                subtitle: String(localized: "Morning intentions, evening reflection, and a daily quote"),
                isOn: Binding(
                    get: { moodReminderEnabled || reflectionReminderEnabled || quoteOfTheDayEnabled },
                    set: { newValue in
                        Task {
                            await handleMasterRemindersToggle(newValue)
                        }
                    }
                )
            )

            NavigationLink(destination: AdvancedRemindersView()) {
                SettingsRow(
                    icon: "gearshape.2.fill",
                    iconColor: themeManager.primaryColor,
                    title: String(localized: "Advanced Reminders"),
                    subtitle: String(localized: "Daily check-ins, quote alert, quiet hours")
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if authorizationStatus == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Notifications Disabled"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryColor)

                    Text(String(localized: "Enable notifications in System Settings to receive reminders."))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)

                    Button(String(localized: "Open Settings")) {
                        PermissionManager.shared.openSettings()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryColor)
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .task {
            await refreshAuthorizationStatus()
        }
        .sheet(isPresented: $isShowingPermissionSheet) {
            PermissionDeniedView(type: .notifications)
        }
    }

    private func refreshAuthorizationStatus() async {
        let status = await PermissionManager.shared.status(for: .notifications)
        await MainActor.run {
            authorizationStatus = status
        }
    }

    private func handleMasterRemindersToggle(_ isEnabled: Bool) async {
        if isEnabled {
            let canSchedule = await ensureAuthorizationForScheduling()
            guard canSchedule else { return }
            await MainActor.run {
                moodReminderEnabled = true
                reflectionReminderEnabled = true
                quoteOfTheDayEnabled = true
            }
            await scheduleMoodReminderIfAuthorized()
            await scheduleReflectionReminderIfAuthorized()
            await scheduleQuoteOfTheDayIfAuthorized()
        } else {
            await MainActor.run {
                moodReminderEnabled = false
                reflectionReminderEnabled = false
                quoteOfTheDayEnabled = false
            }
            dailyReminderService.cancel(.morningIntentions)
            dailyReminderService.cancel(.eveningReflection)
            dailyReminderService.cancelQuoteOfTheDay()
        }
    }

    private func ensureAuthorizationForScheduling() async -> Bool {
        await refreshAuthorizationStatus()

        switch authorizationStatus {
        case .notDetermined:
            let status = await PermissionManager.shared.request(.notifications)
            await refreshAuthorizationStatus()
            return status == .authorized
        case .denied:
            await MainActor.run {
                isShowingPermissionSheet = true
            }
            return false
        case .authorized, .limited:
            return true
        }
    }

    private func scheduleMoodReminderIfAuthorized() async {
        guard await ensureAuthorizationForScheduling() else { return }
        try? await dailyReminderService.schedule(
            .morningIntentions,
            hour: moodReminderHour,
            minute: moodReminderMinute
        )
    }

    private func scheduleReflectionReminderIfAuthorized() async {
        guard await ensureAuthorizationForScheduling() else { return }
        try? await dailyReminderService.schedule(
            .eveningReflection,
            hour: reflectionReminderHour,
            minute: reflectionReminderMinute
        )
    }

    private func scheduleQuoteOfTheDayIfAuthorized() async {
        guard await ensureAuthorizationForScheduling() else { return }
        try? await dailyReminderService.scheduleQuoteOfTheDay()
    }
}
