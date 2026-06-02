import SwiftData
import SwiftUI
import UserNotifications

struct RemindersSettingsSection: View {
    @AppStorage("cbt_moodReminderEnabled") private var dailyMoodCheckInEnabled = false
    @AppStorage("cbt_streakReengagementReminderEnabled") private var streakReengagementEnabled = false
    @AppStorage("cbt_reflectionReminderEnabled") private var eveningReflectionEnabled = false
    @AppStorage("cbt_weeklyReportReminderEnabled") private var weeklyReportEnabled = false
    @AppStorage("cbt_breathingResetReminderEnabled") private var breathingResetEnabled = false
    @AppStorage("cbt_plannedActivityReminderEnabled") private var plannedActivityEnabled = false
    @AppStorage("cbt_courseContinuationReminderEnabled") private var courseContinuationEnabled = false
    @AppStorage("cbt_sleepWindDownReminderEnabled") private var sleepWindDownEnabled = false
    @AppStorage("cbt_quoteOfTheDayEnabled") private var quoteOfTheDayEnabled = false

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @State private var authorizationStatus: PermissionManager.Status = .notDetermined
    @State private var isShowingPermissionSheet = false

    private let personalizedReminderService = PersonalizedReminderService.shared
    private let dailyReminderService = DailyReminderService.shared

    private var isAnyReminderEnabled: Bool {
        dailyMoodCheckInEnabled ||
        streakReengagementEnabled ||
        eveningReflectionEnabled ||
        weeklyReportEnabled ||
        breathingResetEnabled ||
        plannedActivityEnabled ||
        courseContinuationEnabled ||
        sleepWindDownEnabled ||
        quoteOfTheDayEnabled
    }

    var body: some View {
        SettingsSection(title: String(localized: "Reminders")) {
            ToggleRow(
                icon: "bell.badge.fill",
                iconColor: themeManager.primaryColor,
                title: String(localized: "Reminders"),
                subtitle: String(localized: "Mood check-ins, re-engagement, reflections, reports, activities, courses, breathing, quotes, and sleep support"),
                isOn: Binding(
                    get: { isAnyReminderEnabled },
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
                    subtitle: String(localized: "Choose reminder types, schedules, life-event prompts, and quiet hours")
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

                    Text(String(localized: "Enable notifications in System Settings to receive the reminders you choose."))
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
                dailyMoodCheckInEnabled = true
                streakReengagementEnabled = true
                eveningReflectionEnabled = true
                weeklyReportEnabled = true
                breathingResetEnabled = true
                plannedActivityEnabled = true
                courseContinuationEnabled = true
                sleepWindDownEnabled = true
                quoteOfTheDayEnabled = true
            }
            await personalizedReminderService.refreshEnabledReminders(modelContext: modelContext)
            try? await dailyReminderService.scheduleQuoteOfTheDay()
        } else {
            await MainActor.run {
                dailyMoodCheckInEnabled = false
                streakReengagementEnabled = false
                eveningReflectionEnabled = false
                weeklyReportEnabled = false
                breathingResetEnabled = false
                plannedActivityEnabled = false
                courseContinuationEnabled = false
                sleepWindDownEnabled = false
                quoteOfTheDayEnabled = false
            }
            personalizedReminderService.cancelAllPersonalizedReminders()
            dailyReminderService.cancelQuoteOfTheDay()
        }
    }

    private func ensureAuthorizationForScheduling() async -> Bool {
        await refreshAuthorizationStatus()

        switch authorizationStatus {
        case .notDetermined:
            let status = await PermissionManager.shared.request(.notifications)
            await refreshAuthorizationStatus()
            return status.isAuthorized
        case .denied:
            await MainActor.run {
                isShowingPermissionSheet = true
            }
            return false
        case .authorized, .limited:
            return true
        }
    }
}
