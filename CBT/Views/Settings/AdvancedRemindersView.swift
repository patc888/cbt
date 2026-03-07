import SwiftUI
import UserNotifications

struct AdvancedRemindersView: View {
    @AppStorage("cbt_moodReminderEnabled") private var moodReminderEnabled = false
    @AppStorage("cbt_reflectionReminderEnabled") private var reflectionReminderEnabled = false

    @AppStorage("cbt_moodReminderHour") private var moodReminderHour = 9
    @AppStorage("cbt_moodReminderMinute") private var moodReminderMinute = 0

    @AppStorage("cbt_reflectionReminderHour") private var reflectionReminderHour = 20
    @AppStorage("cbt_reflectionReminderMinute") private var reflectionReminderMinute = 0

    @AppStorage("cbt_quietHoursEnabled") private var quietHoursEnabled = false
    @AppStorage("cbt_quietHoursStartHour") private var quietHoursStartHour = 22
    @AppStorage("cbt_quietHoursStartMinute") private var quietHoursStartMinute = 0
    @AppStorage("cbt_quietHoursEndHour") private var quietHoursEndHour = 7
    @AppStorage("cbt_quietHoursEndMinute") private var quietHoursEndMinute = 0

    @Environment(ThemeManager.self) private var themeManager

    @State private var authorizationState: ReminderManager.AuthorizationState = .unknown
    @State private var showingMoodTimePicker = false
    @State private var showingReflectionTimePicker = false
    @State private var showingQuietStartPicker = false
    @State private var showingQuietEndPicker = false

    private let reminderManager = ReminderManager.shared
    private let moodReminderIdentifier = "daily_mood_reminder"
    private let reflectionReminderIdentifier = "daily_reflection_reminder"

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    advancedContent
                }
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle(String(localized: "Advanced Reminders"))
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .task {
            await refreshAuthorizationState()
        }
    }

    private var advancedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: String(localized: "Mood & Reflection")) {
                ToggleRow(
                    icon: "face.smiling",
                    iconColor: themeManager.primaryColor,
                    title: String(localized: "Mood Check-In"),
                    subtitle: String(localized: "Daily prompt to log your mood"),
                    isOn: Binding(
                        get: { moodReminderEnabled },
                        set: { newValue in
                            Task {
                                await handleMoodReminderToggleChange(newValue)
                            }
                        }
                    )
                )

                if moodReminderEnabled {
                    Button {
                        HapticManager.shared.lightImpact()
                        withAnimation(.spring()) {
                            showingMoodTimePicker.toggle()
                        }
                    } label: {
                        SettingsRow(title: String(localized: "Time")) {
                            SettingsPickerButton(
                                value: moodTimeLabel,
                                isExpanded: showingMoodTimePicker
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    if showingMoodTimePicker {
                        DatePicker(
                            "",
                            selection: moodTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.horizontal, 16)
                    }
                }

                ToggleRow(
                    icon: "moon.stars.fill",
                    iconColor: themeManager.primaryColor,
                    title: String(localized: "Evening Reflection"),
                    subtitle: String(localized: "Evening prompt for exercises"),
                    isOn: Binding(
                        get: { reflectionReminderEnabled },
                        set: { newValue in
                            Task {
                                await handleReflectionReminderToggleChange(newValue)
                            }
                        }
                    )
                )

                if reflectionReminderEnabled {
                    Button {
                        HapticManager.shared.lightImpact()
                        withAnimation(.spring()) {
                            showingReflectionTimePicker.toggle()
                        }
                    } label: {
                        SettingsRow(title: String(localized: "Time")) {
                            SettingsPickerButton(
                                value: reflectionTimeLabel,
                                isExpanded: showingReflectionTimePicker
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    if showingReflectionTimePicker {
                        DatePicker(
                            "",
                            selection: reflectionTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.horizontal, 16)
                    }
                }
            }

            SettingsSection(title: String(localized: "Quiet Hours")) {
                ToggleRow(
                    icon: "moon.zzz.fill",
                    iconColor: themeManager.primaryColor,
                    title: String(localized: "Enable Quiet Hours"),
                    subtitle: String(localized: "Mutes reminders during these times"),
                    isOn: $quietHoursEnabled
                )

                if quietHoursEnabled {
                    Button {
                        HapticManager.shared.lightImpact()
                        withAnimation(.spring()) {
                            showingQuietStartPicker.toggle()
                        }
                    } label: {
                        SettingsRow(title: String(localized: "Quiet Start")) {
                            SettingsPickerButton(
                                value: quietStartLabel,
                                isExpanded: showingQuietStartPicker
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    if showingQuietStartPicker {
                        DatePicker(
                            "",
                            selection: quietStartBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.horizontal, 16)
                    }

                    Button {
                        HapticManager.shared.lightImpact()
                        withAnimation(.spring()) {
                            showingQuietEndPicker.toggle()
                        }
                    } label: {
                        SettingsRow(title: String(localized: "Quiet End")) {
                            SettingsPickerButton(
                                value: quietEndLabel,
                                isExpanded: showingQuietEndPicker
                            )
                        }
                    }
                    .buttonStyle(.plain)

                    if showingQuietEndPicker {
                        DatePicker(
                            "",
                            selection: quietEndBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .padding(.horizontal, 16)
                    }
                }
            }

            if authorizationState == .denied {
                SettingsSection(title: "") {
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
        }
        .padding(.top, 16)
    }

    private var moodTimeLabel: String {
        date(hour: moodReminderHour, minute: moodReminderMinute).timeOnly
    }

    private var reflectionTimeLabel: String {
        date(hour: reflectionReminderHour, minute: reflectionReminderMinute).timeOnly
    }

    private var quietStartLabel: String {
        date(hour: quietHoursStartHour, minute: quietHoursStartMinute).timeOnly
    }

    private var quietEndLabel: String {
        date(hour: quietHoursEndHour, minute: quietHoursEndMinute).timeOnly
    }

    private var moodTimeBinding: Binding<Date> {
        Binding(
            get: { date(hour: moodReminderHour, minute: moodReminderMinute) },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                moodReminderHour = components.hour ?? 9
                moodReminderMinute = components.minute ?? 0

                if moodReminderEnabled {
                    Task {
                        await scheduleMoodReminderIfAuthorized()
                    }
                }
            }
        )
    }

    private var reflectionTimeBinding: Binding<Date> {
        Binding(
            get: { date(hour: reflectionReminderHour, minute: reflectionReminderMinute) },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reflectionReminderHour = components.hour ?? 20
                reflectionReminderMinute = components.minute ?? 0

                if reflectionReminderEnabled {
                    Task {
                        await scheduleReflectionReminderIfAuthorized()
                    }
                }
            }
        )
    }

    private var quietStartBinding: Binding<Date> {
        Binding(
            get: { date(hour: quietHoursStartHour, minute: quietHoursStartMinute) },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                quietHoursStartHour = components.hour ?? 22
                quietHoursStartMinute = components.minute ?? 0
            }
        )
    }

    private var quietEndBinding: Binding<Date> {
        Binding(
            get: { date(hour: quietHoursEndHour, minute: quietHoursEndMinute) },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                quietHoursEndHour = components.hour ?? 7
                quietHoursEndMinute = components.minute ?? 0
            }
        )
    }

    private func refreshAuthorizationState() async {
        let latestState = await reminderManager.getAuthorizationState()
        await MainActor.run {
            authorizationState = latestState
        }
    }

    private func handleMoodReminderToggleChange(_ isEnabled: Bool) async {
        if isEnabled {
            let canSchedule = await ensureAuthorizationForScheduling()
            guard canSchedule else {
                await MainActor.run {
                    moodReminderEnabled = false
                }
                return
            }
            await MainActor.run {
                moodReminderEnabled = true
            }
            await scheduleMoodReminderIfAuthorized()
        } else {
            await MainActor.run {
                moodReminderEnabled = false
            }
            await reminderManager.cancel(moodReminderIdentifier)
        }
    }

    private func handleReflectionReminderToggleChange(_ isEnabled: Bool) async {
        if isEnabled {
            let canSchedule = await ensureAuthorizationForScheduling()
            guard canSchedule else {
                await MainActor.run {
                    reflectionReminderEnabled = false
                }
                return
            }
            await MainActor.run {
                reflectionReminderEnabled = true
            }
            await scheduleReflectionReminderIfAuthorized()
        } else {
            await MainActor.run {
                reflectionReminderEnabled = false
            }
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

    private func date(hour: Int, minute: Int) -> Date {
        let now = Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? now
    }
}
