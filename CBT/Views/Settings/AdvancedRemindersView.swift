import SwiftData
import SwiftUI
import UserNotifications

struct AdvancedRemindersView: View {
    @AppStorage("cbt_moodReminderEnabled") private var dailyMoodCheckInEnabled = false
    @AppStorage("cbt_reflectionReminderEnabled") private var eveningReflectionEnabled = false
    @AppStorage("cbt_weeklyReportReminderEnabled") private var weeklyReportEnabled = false
    @AppStorage("cbt_breathingResetReminderEnabled") private var breathingResetEnabled = false
    @AppStorage("cbt_plannedActivityReminderEnabled") private var plannedActivityEnabled = false
    @AppStorage("cbt_courseContinuationReminderEnabled") private var courseContinuationEnabled = false
    @AppStorage("cbt_sleepWindDownReminderEnabled") private var sleepWindDownEnabled = false
    @AppStorage("cbt_quoteOfTheDayEnabled") private var quoteOfTheDayEnabled = false
    @AppStorage("cbt_contextualBeforeWorkEnabled") private var contextualBeforeWorkEnabled = false
    @AppStorage("cbt_contextualDuringCommuteEnabled") private var contextualDuringCommuteEnabled = false
    @AppStorage("cbt_contextualBeforeBedEnabled") private var contextualBeforeBedEnabled = false

    @AppStorage("cbt_moodReminderHour") private var dailyMoodCheckInHour = 9
    @AppStorage("cbt_moodReminderMinute") private var dailyMoodCheckInMinute = 0
    @AppStorage("cbt_reflectionReminderHour") private var eveningReflectionHour = 20
    @AppStorage("cbt_reflectionReminderMinute") private var eveningReflectionMinute = 30
    @AppStorage("cbt_weeklyReportReminderHour") private var weeklyReportHour = 18
    @AppStorage("cbt_weeklyReportReminderMinute") private var weeklyReportMinute = 0
    @AppStorage("cbt_weeklyReportReminderWeekday") private var weeklyReportWeekday = 1
    @AppStorage("cbt_breathingResetReminderHour") private var breathingResetHour = 14
    @AppStorage("cbt_breathingResetReminderMinute") private var breathingResetMinute = 0
    @AppStorage("cbt_courseContinuationReminderHour") private var courseContinuationHour = 16
    @AppStorage("cbt_courseContinuationReminderMinute") private var courseContinuationMinute = 0
    @AppStorage("cbt_sleepWindDownReminderHour") private var sleepWindDownHour = 21
    @AppStorage("cbt_sleepWindDownReminderMinute") private var sleepWindDownMinute = 30

    @AppStorage("cbt_quietHoursEnabled") private var quietHoursEnabled = false
    @AppStorage("cbt_quietHoursStartHour") private var quietHoursStartHour = 22
    @AppStorage("cbt_quietHoursStartMinute") private var quietHoursStartMinute = 0
    @AppStorage("cbt_quietHoursEndHour") private var quietHoursEndHour = 7
    @AppStorage("cbt_quietHoursEndMinute") private var quietHoursEndMinute = 0

    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager

    @State private var authorizationStatus: PermissionManager.Status = .notDetermined
    @State private var isShowingPermissionSheet = false
    @State private var expandedReminderTimePicker: PersonalizedReminderType?
    @State private var showingQuietStartPicker = false
    @State private var showingQuietEndPicker = false

    private let personalizedReminderService = PersonalizedReminderService.shared
    private let dailyReminderService = DailyReminderService.shared
    private let contextualNotificationService = ContextualNotificationService.shared

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
            await refreshAuthorizationStatus()
            await personalizedReminderService.refreshEnabledReminders(modelContext: modelContext)
        }
        .sheet(isPresented: $isShowingPermissionSheet) {
            PermissionDeniedView(type: .notifications)
        }
    }

    private var advancedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsSection(title: String(localized: "Personal Reminders")) {
                ForEach(PersonalizedReminderType.allCases) { reminderType in
                    ToggleRow(
                        icon: reminderType.icon,
                        iconColor: themeManager.primaryColor,
                        title: reminderType.title,
                        subtitle: subtitle(for: reminderType),
                        isOn: binding(for: reminderType)
                    )

                    if isReminderEnabled(reminderType) {
                        scheduleControls(for: reminderType)
                    }
                }
            }

            SettingsSection(title: String(localized: "Quote")) {
                ToggleRow(
                    icon: "quote.opening",
                    iconColor: themeManager.primaryColor,
                    title: String(localized: "Quote of the Day"),
                    subtitle: String(localized: "A daily affirmation at 9:00 AM"),
                    isOn: Binding(
                        get: { quoteOfTheDayEnabled },
                        set: { newValue in
                            Task {
                                await handleQuoteOfTheDayToggleChange(newValue)
                            }
                        }
                    )
                )
            }

            SettingsSection(title: String(localized: "Life Events")) {
                ForEach(contextualNotificationService.defaultTemplates) { template in
                    ToggleRow(
                        icon: icon(for: template),
                        iconColor: themeManager.primaryColor,
                        title: template.lifeEvent.title,
                        subtitle: subtitle(for: template),
                        isOn: binding(for: template.lifeEvent)
                    )
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
                    quietTimeRow(
                        title: String(localized: "Quiet Start"),
                        label: quietStartLabel,
                        isExpanded: showingQuietStartPicker,
                        toggle: { showingQuietStartPicker.toggle() }
                    )

                    if showingQuietStartPicker {
                        quietDatePicker(selection: quietStartBinding)
                    }

                    quietTimeRow(
                        title: String(localized: "Quiet End"),
                        label: quietEndLabel,
                        isExpanded: showingQuietEndPicker,
                        toggle: { showingQuietEndPicker.toggle() }
                    )

                    if showingQuietEndPicker {
                        quietDatePicker(selection: quietEndBinding)
                    }
                }
            }

            if authorizationStatus == .denied {
                SettingsSection(title: "") {
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
        }
        .padding(.top, 16)
    }

    @ViewBuilder
    private func scheduleControls(for reminderType: PersonalizedReminderType) -> some View {
        if reminderType == .weeklyReport {
            weeklyReportDayRow
        }

        if reminderType.showsTimePicker {
            Button {
                HapticManager.shared.lightImpact()
                withAnimation(.spring()) {
                    expandedReminderTimePicker = expandedReminderTimePicker == reminderType ? nil : reminderType
                }
            } label: {
                SettingsRow(title: String(localized: "Time")) {
                    SettingsPickerButton(
                        value: reminderTimeLabel(for: reminderType),
                        isExpanded: expandedReminderTimePicker == reminderType
                    )
                }
            }
            .buttonStyle(.plain)

            if expandedReminderTimePicker == reminderType {
                DatePicker(
                    "",
                    selection: reminderTimeBinding(for: reminderType),
                    displayedComponents: .hourAndMinute
                )
                #if os(iOS)
                .datePickerStyle(.wheel)
                #endif
                .labelsHidden()
                .transition(.opacity.combined(with: .move(edge: .top)))
                .padding(.horizontal, 16)
            }
        }
    }

    private var weeklyReportDayRow: some View {
        SettingsRow(title: String(localized: "Day")) {
            Picker(String(localized: "Day"), selection: weeklyReportWeekdayBinding) {
                ForEach(weekdayOptions.indices, id: \.self) { index in
                    let option = weekdayOptions[index]
                    Text(option.title).tag(option.value)
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func quietTimeRow(
        title: String,
        label: String,
        isExpanded: Bool,
        toggle: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.lightImpact()
            withAnimation(.spring()) {
                toggle()
            }
        } label: {
            SettingsRow(title: title) {
                SettingsPickerButton(
                    value: label,
                    isExpanded: isExpanded
                )
            }
        }
        .buttonStyle(.plain)
    }

    private func quietDatePicker(selection: Binding<Date>) -> some View {
        DatePicker(
            "",
            selection: selection,
            displayedComponents: .hourAndMinute
        )
        #if os(iOS)
        .datePickerStyle(.wheel)
        #endif
        .labelsHidden()
        .transition(.opacity.combined(with: .move(edge: .top)))
        .padding(.horizontal, 16)
    }

    private var quietStartLabel: String {
        date(hour: quietHoursStartHour, minute: quietHoursStartMinute).timeOnly
    }

    private var quietEndLabel: String {
        date(hour: quietHoursEndHour, minute: quietHoursEndMinute).timeOnly
    }

    private var weekdayOptions: [(value: Int, title: String)] {
        Calendar.current.weekdaySymbols.enumerated().map { index, title in
            (value: index + 1, title: title)
        }
    }

    private var weeklyReportWeekdayBinding: Binding<Int> {
        Binding(
            get: { weeklyReportWeekday },
            set: { newValue in
                weeklyReportWeekday = newValue
                if weeklyReportEnabled {
                    Task {
                        await schedulePersonalizedReminderIfAuthorized(.weeklyReport)
                    }
                }
            }
        )
    }

    private func binding(for reminderType: PersonalizedReminderType) -> Binding<Bool> {
        Binding(
            get: { isReminderEnabled(reminderType) },
            set: { isEnabled in
                Task {
                    await handlePersonalizedReminderToggle(reminderType, isEnabled: isEnabled)
                }
            }
        )
    }

    private func binding(for lifeEvent: LifeEvent) -> Binding<Bool> {
        Binding(
            get: {
                switch lifeEvent {
                case .beforeWork:
                    return contextualBeforeWorkEnabled
                case .duringCommute:
                    return contextualDuringCommuteEnabled
                case .beforeBed:
                    return contextualBeforeBedEnabled
                }
            },
            set: { isEnabled in
                Task {
                    await handleContextualReminderToggle(lifeEvent, isEnabled: isEnabled)
                }
            }
        )
    }

    private func isReminderEnabled(_ reminderType: PersonalizedReminderType) -> Bool {
        switch reminderType {
        case .dailyMoodCheckIn:
            return dailyMoodCheckInEnabled
        case .eveningReflection:
            return eveningReflectionEnabled
        case .weeklyReport:
            return weeklyReportEnabled
        case .breathingReset:
            return breathingResetEnabled
        case .plannedActivity:
            return plannedActivityEnabled
        case .courseContinuation:
            return courseContinuationEnabled
        case .sleepWindDown:
            return sleepWindDownEnabled
        }
    }

    @MainActor
    private func setReminderEnabled(_ reminderType: PersonalizedReminderType, isEnabled: Bool) {
        switch reminderType {
        case .dailyMoodCheckIn:
            dailyMoodCheckInEnabled = isEnabled
        case .eveningReflection:
            eveningReflectionEnabled = isEnabled
        case .weeklyReport:
            weeklyReportEnabled = isEnabled
        case .breathingReset:
            breathingResetEnabled = isEnabled
        case .plannedActivity:
            plannedActivityEnabled = isEnabled
        case .courseContinuation:
            courseContinuationEnabled = isEnabled
        case .sleepWindDown:
            sleepWindDownEnabled = isEnabled
        }
    }

    private func subtitle(for reminderType: PersonalizedReminderType) -> String {
        if reminderType == .plannedActivity {
            return reminderType.settingsSubtitle
        }

        if reminderType == .weeklyReport {
            return String(localized: "\(weekdayName(for: weeklyReportWeekday)) at \(reminderTimeLabel(for: reminderType))")
        }

        return String(localized: "\(reminderType.settingsSubtitle) at \(reminderTimeLabel(for: reminderType))")
    }

    private func reminderTimeLabel(for reminderType: PersonalizedReminderType) -> String {
        date(hour: reminderHour(for: reminderType), minute: reminderMinute(for: reminderType)).timeOnly
    }

    private func reminderTimeBinding(for reminderType: PersonalizedReminderType) -> Binding<Date> {
        Binding(
            get: {
                date(
                    hour: reminderHour(for: reminderType),
                    minute: reminderMinute(for: reminderType)
                )
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                setReminderTime(
                    reminderType,
                    hour: components.hour ?? reminderType.defaultHour,
                    minute: components.minute ?? reminderType.defaultMinute
                )

                if isReminderEnabled(reminderType) {
                    Task {
                        await schedulePersonalizedReminderIfAuthorized(reminderType)
                    }
                }
            }
        )
    }

    private func reminderHour(for reminderType: PersonalizedReminderType) -> Int {
        switch reminderType {
        case .dailyMoodCheckIn:
            return dailyMoodCheckInHour
        case .eveningReflection:
            return eveningReflectionHour
        case .weeklyReport:
            return weeklyReportHour
        case .breathingReset:
            return breathingResetHour
        case .plannedActivity:
            return reminderType.defaultHour
        case .courseContinuation:
            return courseContinuationHour
        case .sleepWindDown:
            return sleepWindDownHour
        }
    }

    private func reminderMinute(for reminderType: PersonalizedReminderType) -> Int {
        switch reminderType {
        case .dailyMoodCheckIn:
            return dailyMoodCheckInMinute
        case .eveningReflection:
            return eveningReflectionMinute
        case .weeklyReport:
            return weeklyReportMinute
        case .breathingReset:
            return breathingResetMinute
        case .plannedActivity:
            return reminderType.defaultMinute
        case .courseContinuation:
            return courseContinuationMinute
        case .sleepWindDown:
            return sleepWindDownMinute
        }
    }

    private func setReminderTime(_ reminderType: PersonalizedReminderType, hour: Int, minute: Int) {
        switch reminderType {
        case .dailyMoodCheckIn:
            dailyMoodCheckInHour = hour
            dailyMoodCheckInMinute = minute
        case .eveningReflection:
            eveningReflectionHour = hour
            eveningReflectionMinute = minute
        case .weeklyReport:
            weeklyReportHour = hour
            weeklyReportMinute = minute
        case .breathingReset:
            breathingResetHour = hour
            breathingResetMinute = minute
        case .plannedActivity:
            break
        case .courseContinuation:
            courseContinuationHour = hour
            courseContinuationMinute = minute
        case .sleepWindDown:
            sleepWindDownHour = hour
            sleepWindDownMinute = minute
        }
    }

    private func weekdayName(for weekday: Int) -> String {
        let options = weekdayOptions
        return options.first { $0.value == weekday }?.title ?? options.first?.title ?? ""
    }

    private func icon(for template: NotificationTemplate) -> String {
        switch template.deepLink {
        case .breathing:
            return "wind"
        case .journal:
            return "book.pages.fill"
        case .morningIntentions:
            return "sunrise.fill"
        case .eveningReflection, .sleepWindDown:
            return "moon.stars.fill"
        case .affirmation:
            return "sparkles"
        case .moodCheckIn:
            return "face.smiling"
        case .weeklyReport:
            return "chart.line.uptrend.xyaxis"
        case .plannedActivity:
            return "calendar.badge.clock"
        case .courseContinuation:
            return "graduationcap.fill"
        }
    }

    private func subtitle(for template: NotificationTemplate) -> String {
        let triggerLabel: String
        if let calendarTrigger = template.trigger as? UNCalendarNotificationTrigger,
           let hour = calendarTrigger.dateComponents.hour,
           let minute = calendarTrigger.dateComponents.minute {
            triggerLabel = date(hour: hour, minute: minute).timeOnly
        } else {
            triggerLabel = String(localized: "Contextual reminder")
        }

        switch template.deepLink {
        case .breathing:
            return String(localized: "\(triggerLabel) - opens Breathing")
        case .journal:
            return String(localized: "\(triggerLabel) - opens Journal")
        case .morningIntentions:
            return String(localized: "\(triggerLabel) - opens Morning Intentions")
        case .eveningReflection:
            return String(localized: "\(triggerLabel) - opens Evening Reflection")
        case .affirmation:
            return String(localized: "\(triggerLabel) - opens Affirmations")
        case .moodCheckIn:
            return String(localized: "\(triggerLabel) - opens Mood Check-In")
        case .weeklyReport:
            return String(localized: "\(triggerLabel) - opens Insights")
        case .plannedActivity:
            return String(localized: "\(triggerLabel) - opens Activity Planner")
        case .courseContinuation:
            return String(localized: "\(triggerLabel) - opens Library")
        case .sleepWindDown:
            return String(localized: "\(triggerLabel) - opens Sleep Wind-Down")
        }
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

    private func refreshAuthorizationStatus() async {
        let status = await PermissionManager.shared.status(for: .notifications)
        await MainActor.run {
            authorizationStatus = status
        }
    }

    private func handlePersonalizedReminderToggle(_ reminderType: PersonalizedReminderType, isEnabled: Bool) async {
        if isEnabled {
            let canSchedule = await ensureAuthorizationForScheduling()
            guard canSchedule else {
                await setReminderEnabled(reminderType, isEnabled: false)
                return
            }

            await setReminderEnabled(reminderType, isEnabled: true)
            await schedulePersonalizedReminderIfAuthorized(reminderType)
        } else {
            await setReminderEnabled(reminderType, isEnabled: false)
            personalizedReminderService.cancel(reminderType)
        }
    }

    private func handleQuoteOfTheDayToggleChange(_ isEnabled: Bool) async {
        if isEnabled {
            let canSchedule = await ensureAuthorizationForScheduling()
            guard canSchedule else {
                await MainActor.run {
                    quoteOfTheDayEnabled = false
                }
                return
            }
            await MainActor.run {
                quoteOfTheDayEnabled = true
            }
            try? await dailyReminderService.scheduleQuoteOfTheDay()
        } else {
            await MainActor.run {
                quoteOfTheDayEnabled = false
            }
            dailyReminderService.cancelQuoteOfTheDay()
        }
    }

    private func handleContextualReminderToggle(_ lifeEvent: LifeEvent, isEnabled: Bool) async {
        if isEnabled {
            let canSchedule = await ensureAuthorizationForScheduling()
            guard canSchedule, let template = contextualNotificationService.template(for: lifeEvent) else {
                await setContextualReminder(lifeEvent, isEnabled: false)
                return
            }

            await setContextualReminder(lifeEvent, isEnabled: true)
            try? await contextualNotificationService.schedule(template)
        } else {
            await setContextualReminder(lifeEvent, isEnabled: false)
            contextualNotificationService.cancel(lifeEvent: lifeEvent)
        }
    }

    @MainActor
    private func setContextualReminder(_ lifeEvent: LifeEvent, isEnabled: Bool) {
        switch lifeEvent {
        case .beforeWork:
            contextualBeforeWorkEnabled = isEnabled
        case .duringCommute:
            contextualDuringCommuteEnabled = isEnabled
        case .beforeBed:
            contextualBeforeBedEnabled = isEnabled
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

    private func schedulePersonalizedReminderIfAuthorized(_ reminderType: PersonalizedReminderType) async {
        guard await ensureAuthorizationForScheduling() else { return }

        do {
            switch reminderType {
            case .plannedActivity:
                try await personalizedReminderService.schedulePlannedActivityReminders(modelContext: modelContext)
            case .courseContinuation:
                try await personalizedReminderService.scheduleCourseContinuationReminder(
                    modelContext: modelContext,
                    hour: courseContinuationHour,
                    minute: courseContinuationMinute
                )
            default:
                try await personalizedReminderService.schedule(
                    reminderType,
                    hour: reminderHour(for: reminderType),
                    minute: reminderMinute(for: reminderType),
                    weekday: weeklyReportWeekday
                )
            }
        } catch {
            return
        }
    }

    private func date(hour: Int, minute: Int) -> Date {
        let now = Date()
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components) ?? now
    }
}
