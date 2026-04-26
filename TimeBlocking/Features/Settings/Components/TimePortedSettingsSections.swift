import SwiftUI
import SwiftData
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

struct TimeNotificationsSettingsView: View {
    private enum ReminderState: Equatable {
        case enabled
        case disabled
        case notYetRequested
        case denied
        case unavailable

        var label: String {
            switch self {
            case .enabled:
                return "Enabled"
            case .disabled:
                return "Disabled"
            case .notYetRequested:
                return "Not Requested"
            case .denied:
                return "Permission Denied"
            case .unavailable:
                return "Unavailable"
            }
        }

        var title: String {
            switch self {
            case .enabled:
                return "Reminders are on"
            case .disabled:
                return "Reminders are off"
            case .notYetRequested:
                return "Permission not requested"
            case .denied:
                return "Permission denied"
            case .unavailable:
                return "Notifications unavailable"
            }
        }

        var message: String {
            switch self {
            case .enabled:
                return "Upcoming planned blocks can alert before they start."
            case .disabled:
                return "Turn reminders on to alert before upcoming planned blocks."
            case .notYetRequested:
                return "The app will ask for notification access when you turn reminders on."
            case .denied:
                return "Allow notifications in the system Settings app to deliver reminders."
            case .unavailable:
                return "Alerts are disabled for Time Blocking in system settings."
            }
        }

        var symbolName: String {
            switch self {
            case .enabled:
                return "checkmark.circle.fill"
            case .disabled:
                return "bell.slash.fill"
            case .notYetRequested:
                return "questionmark.circle.fill"
            case .denied:
                return "exclamationmark.triangle.fill"
            case .unavailable:
                return "bell.badge.slash.fill"
            }
        }
    }

    let preferences: AppPreferences?
    let accessState: TimeNotificationManager.AccessState
    let onUpdate: ((AppPreferences) -> Void) -> Void
    let onEnabledChanged: (Bool) -> Void
    let onLeadTimeChanged: () -> Void
    let onOpenSystemSettings: () -> Void
    @Namespace private var reminderNamespace

    private var remindersEnabled: Binding<Bool> {
        Binding(
            get: { preferences?.notificationsEnabled ?? false },
            set: { newValue in
                onUpdate { $0.notificationsEnabled = newValue }
                onEnabledChanged(newValue)
            }
        )
    }

    private var leadTimeMinutes: Int {
        preferences?.notificationLeadTimeMinutes ?? 0
    }

    private var leadTimeText: String {
        leadTimeMinutes == 0 ? "At block start" : "\(leadTimeMinutes) min before"
    }

    private var reminderState: ReminderState {
        if remindersEnabled.wrappedValue {
            switch accessState {
            case .enabled:
                return .enabled
            case .notDetermined:
                return .notYetRequested
            case .denied:
                return .denied
            case .unavailable:
                return .unavailable
            }
        }

        switch accessState {
        case .notDetermined:
            return .notYetRequested
        case .enabled, .denied, .unavailable:
            return .disabled
        }
    }

    private var shouldShowDetails: Bool {
        reminderState != .enabled && reminderState != .disabled
    }

    private var shouldShowLeadTime: Bool {
        remindersEnabled.wrappedValue || !accessState.allowsScheduling
    }

    private var reminderSubtitle: String {
        switch reminderState {
        case .enabled:
            return "For upcoming planned blocks"
        case .disabled:
            return "Currently off"
        case .notYetRequested:
            return "Permission will be requested when enabled"
        case .denied:
            return "Permission is required"
        case .unavailable:
            return "Turn alerts back on in system settings"
        }
    }

    var body: some View {
        TimeSettingsSection(
            title: "Notifications"
        ) {
            TimeSettingsRow(
                icon: "bell.fill",
                iconColor: Theme.primaryAccent,
                title: "Block Reminders"
            ) {
                TimeSegmentedToggle(isOn: remindersEnabled, namespace: reminderNamespace)
            }

            TimeSettingsRow(
                icon: reminderState.symbolName,
                iconColor: reminderState == .denied ? .orange : Theme.primaryAccent,
                title: "Reminder Status"
            ) {
                Text(reminderState.label)
                    .timeSettingsValueStyle()
            }

            if shouldShowDetails {
                VStack(alignment: .leading, spacing: 10) {
                    Label(reminderState.title, systemImage: reminderState.symbolName)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(reminderState == .denied ? .orange : Theme.secondaryText)

                    Text(
                        reminderState == .notYetRequested
                            ? "Turn on Block Reminders to request access."
                            : reminderState.message
                    )
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)

                    if accessState.requiresSystemSettings {
                        Button(action: onOpenSystemSettings) {
                            Text("Open System Settings")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.primaryAccent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 32)
            }

            if shouldShowLeadTime {
                TimeSettingsRow(
                    icon: "clock.badge",
                    iconColor: Theme.primaryAccent,
                    title: "Reminder Time"
                ) {
                    Menu(leadTimeText) {
                        ForEach([0, 5, 10, 15, 30, 60], id: \.self) { minutes in
                            Button(minutes == 0 ? "At block start" : "\(minutes) min before") {
                                onUpdate {
                                    $0.notificationLeadTimeMinutes = minutes
                                }
                                onLeadTimeChanged()
                            }
                        }
                    }
                    .timeSettingsValueStyle()
                }
            }
        }
    }
}
