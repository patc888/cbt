import SwiftUI

struct TimeNotificationsSettingsView: View {
    @AppStorage("time_settings_reminders_enabled") private var remindersEnabled = false
    @AppStorage("time_settings_reminder_time") private var reminderTimeInterval: Double = Date().timeIntervalSince1970
    @AppStorage("time_settings_reminder_frequency") private var reminderFrequency = "Daily"
    @State private var showingTimePicker = false
    @State private var showingFrequencyMenu = false
    @Namespace private var reminderNamespace

    private var reminderTime: Date {
        get { Date(timeIntervalSince1970: reminderTimeInterval) }
        nonmutating set { reminderTimeInterval = newValue.timeIntervalSince1970 }
    }

    var body: some View {
        TimeSettingsSection(title: "Notifications") {
            TimeSettingsRow(icon: "bell.fill", iconColor: Theme.primaryPurple, title: "Reminders") {
                TimeSegmentedToggle(isOn: $remindersEnabled, namespace: reminderNamespace)
            }

            if remindersEnabled {
                Button {
                    HapticManager.shared.lightImpact()
                    showingTimePicker.toggle()
                } label: {
                    TimeSettingsRow(title: "Time") {
                        TimeSettingsPickerButton(
                            value: reminderTime.formatted(date: .omitted, time: .shortened),
                            isExpanded: showingTimePicker
                        )
                    }
                }
                .buttonStyle(.plain)

                TimeSettingsRow(title: "Frequency") {
                    Menu {
                        ForEach(["Daily", "Weekdays", "Weekly"], id: \.self) { value in
                            Button(value) { reminderFrequency = value }
                        }
                    } label: {
                        TimeSettingsDropdownButton(value: reminderFrequency, isExpanded: showingFrequencyMenu)
                    }
                    .simultaneousGesture(TapGesture().onEnded { showingFrequencyMenu.toggle() })
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $showingTimePicker) {
            VStack(spacing: 16) {
                DatePicker("", selection: Binding(
                    get: { reminderTime },
                    set: { reminderTime = $0 }
                ), displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()

                Button("Done") { showingTimePicker = false }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .padding(24)
            .presentationDetents([.height(320)])
        }
    }
}

struct TimeDataSettingsView: View {
    @AppStorage("time_settings_health_sync_enabled") private var healthSyncEnabled = false
    @Namespace private var healthNamespace

    var body: some View {
        TimeSettingsSection(title: "Data") {
            TimeSettingsRow(icon: "icloud.fill", iconColor: Theme.primaryPurple, title: "iCloud Sync", subtitle: "Sync between iPhone, iPad, and Mac") {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }

            TimeSettingsRow(icon: "heart.fill", iconColor: .red, title: "Apple Health Sync") {
                TimeSegmentedToggle(isOn: $healthSyncEnabled, namespace: healthNamespace)
            }

            Divider()
                .padding(.vertical, 8)

            TimeSettingsRow(icon: "square.and.arrow.up", iconColor: Theme.primaryPurple, title: "Export Data") {
                Button("Export CSV") { HapticManager.shared.mediumImpact() }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryPurple)
            }

            TimeSettingsRow(icon: "square.and.arrow.down", iconColor: Theme.primaryPurple, title: "Import Data") {
                Button("Import CSV") { HapticManager.shared.mediumImpact() }
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryPurple)
            }
        }
    }
}

struct TimeSecuritySettingsView: View {
    @AppStorage("time_settings_app_lock_enabled") private var appLockEnabled = false
    @Namespace private var lockNamespace
    @State private var showingPrivacyInfo = false

    var body: some View {
        TimeSettingsSection(title: "Security") {
            VStack(spacing: 0) {
                TimeSettingsRow(icon: "faceid", iconColor: Theme.primaryPurple, title: "Lock app with Face ID or passcode") {
                    TimeSegmentedToggle(isOn: $appLockEnabled, namespace: lockNamespace)
                }

                Button {
                    HapticManager.shared.lightImpact()
                    showingPrivacyInfo = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                        Text("Why your data is private")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                        Spacer()
                    }
                    .foregroundStyle(Theme.primaryPurple)
                    .padding(.top, 12)
                    .padding(.leading, 32)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingPrivacyInfo) {
            VStack(spacing: 14) {
                Text("Your Data is Private")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("No trackers or third-party analytics. Data is device-first and private.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.secondaryText)
                Button("Got it") { showingPrivacyInfo = false }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .padding(24)
            .presentationDetents([.medium])
        }
    }
}

struct TimeGoalSettingsView: View {
    @AppStorage("time_settings_goal_enabled") private var goalEnabled = false
    @State private var targetWeight = ""
    @State private var targetDate = Date().addingTimeInterval(60 * 60 * 24 * 90)
    @State private var showingDate = false
    @Namespace private var goalNamespace

    var body: some View {
        TimeSettingsSection(title: "Goal") {
            TimeSettingsRow(icon: "target", iconColor: Theme.primaryPurple, title: "Weight Goal") {
                TimeSegmentedToggle(isOn: $goalEnabled, namespace: goalNamespace)
            }

            if goalEnabled {
                Divider()
                    .padding(.vertical, 4)

                TimeSettingsRow(title: "Target Weight") {
                    TextField("Set Weight", text: $targetWeight)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 110)
                }

                Button { showingDate = true } label: {
                    TimeSettingsRow(title: "Target Date") {
                        TimeSettingsPickerButton(
                            value: targetDate.formatted(date: .abbreviated, time: .omitted),
                            isExpanded: showingDate
                        )
                    }
                }
                .buttonStyle(.plain)

                Button {
                    HapticManager.shared.success()
                } label: {
                    HStack {
                        Text("Start Tracking Goal")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Theme.primaryPurple)
                    .clipShape(Capsule())
                }
                .padding(.top, 4)
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingDate) {
            VStack {
                DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                Button("Done") { showingDate = false }
            }
            .padding(20)
            .presentationDetents([.medium])
        }
    }
}

struct TimeBMISettingsView: View {
    @AppStorage("time_settings_bmi_enabled") private var showBMI = true
    @State private var height = "170 cm"
    @State private var showingHeightPicker = false
    @Namespace private var bmiNamespace

    var body: some View {
        TimeSettingsSection(title: "BMI Calculator") {
            Button {
                showingHeightPicker = true
            } label: {
                TimeSettingsRow(title: "Height") {
                    TimeSettingsPickerButton(value: height, isExpanded: showingHeightPicker)
                }
            }
            .buttonStyle(.plain)

            TimeSettingsRow(title: "Show BMI Calculator") {
                TimeSegmentedToggle(isOn: $showBMI, namespace: bmiNamespace)
            }
        }
        .sheet(isPresented: $showingHeightPicker) {
            VStack(spacing: 16) {
                Text("Height")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                TextField("170 cm", text: $height)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                Button("Done") { showingHeightPicker = false }
            }
            .padding(24)
            .presentationDetents([.height(220)])
        }
    }
}

struct TimeOverviewLayoutSettingsView: View {
    var body: some View {
        TimeSettingsSection(title: "Overview Layout") {
            Button {
                HapticManager.shared.mediumImpact()
            } label: {
                TimeSettingsRow(
                    icon: "square.grid.2x2.fill",
                    iconColor: Theme.primaryPurple,
                    title: "Customize Dashboard",
                    subtitle: "Reorder or hide cards"
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private enum TimeWeightUnit: String, CaseIterable, Identifiable {
    case lbs = "LBS"
    case kg = "KG"
    case stone = "STONE"

    var id: String { rawValue }
}

struct TimeUnitsSettingsView: View {
    @State private var unit: TimeWeightUnit = .lbs
    @Namespace private var unitNamespace

    var body: some View {
        TimeSettingsSection(title: "Units") {
            TimeSettingsRow(title: "Weight Unit") {
                TimeSegmentedToggle(
                    selection: $unit,
                    options: TimeWeightUnit.allCases,
                    namespace: unitNamespace,
                    title: { $0.rawValue }
                )
                .frame(maxWidth: 220)
            }
        }
    }
}
