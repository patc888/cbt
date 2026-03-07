import SwiftUI
import UserNotifications

struct RemindersSettingsSection: View {
    @AppStorage("cbt_moodReminderEnabled") private var moodReminderEnabled = false
    @AppStorage("cbt_reflectionReminderEnabled") private var reflectionReminderEnabled = false

    @AppStorage("cbt_moodReminderHour") private var moodReminderHour = 9
    @AppStorage("cbt_moodReminderMinute") private var moodReminderMinute = 0

    @AppStorage("cbt_reflectionReminderHour") private var reflectionReminderHour = 20
    @AppStorage("cbt_reflectionReminderMinute") private var reflectionReminderMinute = 0

    @Environment(ThemeManager.self) private var themeManager

    @State private var authorizationState: ReminderManager.AuthorizationState = .unknown

    private let reminderManager = ReminderManager.shared
    private let moodReminderIdentifier = "daily_mood_reminder"
    private let reflectionReminderIdentifier = "daily_reflection_reminder"

    var body: some View {
        SettingsSection(title: String(localized: "Reminders")) {
            ToggleRow(
                icon: "bell.badge.fill",
                iconColor: themeManager.primaryColor,
                title: String(localized: "Reminders"),
                subtitle: String(localized: "Daily mood check-in and evening reflection"),
                isOn: Binding(
                    get: { moodReminderEnabled || reflectionReminderEnabled },
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
                    subtitle: String(localized: "Mood check-in, evening reflection, quiet hours")
                ) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if authorizationState == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "Notifications Disabled"))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryColor)

                    Text(String(localized: "Enable notifications in System Settings to receive reminders."))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)

                    Button(String(localized: "Open Settings")) {
                        reminderManager.openSystemNotificationSettings()
                    }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryColor)
                    .padding(.top, 4)
                }
                .padding(16)
            }
        }
        .task {
            await refreshAuthorizationState()
        }
    }

    private func refreshAuthorizationState() async {
        let latestState = await reminderManager.getAuthorizationState()
        await MainActor.run {
            authorizationState = latestState
        }
    }

    private func handleMasterRemindersToggle(_ isEnabled: Bool) async {
        if isEnabled {
            let canSchedule = await ensureAuthorizationForScheduling()
            guard canSchedule else { return }
            await MainActor.run {
                moodReminderEnabled = true
                reflectionReminderEnabled = true
            }
            await scheduleMoodReminderIfAuthorized()
            await scheduleReflectionReminderIfAuthorized()
        } else {
            await MainActor.run {
                moodReminderEnabled = false
                reflectionReminderEnabled = false
            }
            await reminderManager.cancel(moodReminderIdentifier)
            await reminderManager.cancel(reflectionReminderIdentifier)
        }
    }

    private func ensureAuthorizationForScheduling() async -> Bool {
        await refreshAuthorizationState()

        if authorizationState == .notDetermined {
            _ = await reminderManager.requestAuthorization()
            await refreshAuthorizationState()
        }

        return authorizationState == .authorized || authorizationState == .provisional || authorizationState == .ephemeral
    }

    private func scheduleMoodReminderIfAuthorized() async {
        guard await ensureAuthorizationForScheduling() else { return }
        try? await reminderManager.scheduleDaily(
            identifier: moodReminderIdentifier,
            title: "How are you feeling?",
            body: "Take a quick moment to log your mood.",
            hour: moodReminderHour,
            minute: moodReminderMinute
        )
    }

    private func scheduleReflectionReminderIfAuthorized() async {
        guard await ensureAuthorizationForScheduling() else { return }
        try? await reminderManager.scheduleDaily(
            identifier: reflectionReminderIdentifier,
            title: "Evening reflection",
            body: "Review your thoughts or complete an exercise.",
            hour: reflectionReminderHour,
            minute: reflectionReminderMinute
        )
    }
}
