import SwiftUI
import SwiftData

struct TimeSchedulingSettingsView: View {
    let preferences: AppPreferences?
    let onUpdate: ((AppPreferences) -> Void) -> Void
    
    var body: some View {
        TimeSettingsSection(
            title: "Scheduling"
        ) {
            defaultDurationRow
            dayStartRow
            weekStartRow
        }
    }
    
    private var defaultDurationRow: some View {
        TimeSettingsRow(
            icon: "timer",
            iconColor: Theme.primaryAccent,
            title: "Default Block Length"
        ) {
            Menu {
                ForEach([15, 30, 45, 60, 90, 120, 180], id: \.self) { minutes in
                    Button("\(minutes) min") {
                        onUpdate {
                            $0.defaultBlockDurationMinutes = minutes
                        }
                    }
                }
            } label: {
                TimeSettingsDropdownButton(value: "\(preferences?.defaultBlockDurationMinutes ?? 60) min", isExpanded: false)
            }
        }
    }

    private var dayStartRow: some View {
        TimeSettingsRow(
            icon: "sunrise",
            iconColor: Theme.primaryAccent,
            title: "Day Start Hour"
        ) {
            Menu {
                ForEach(0..<24, id: \.self) { hour in
                    Button(String(format: "%02d:00", hour)) {
                        onUpdate {
                            $0.dayStartHour = hour
                        }
                    }
                }
            } label: {
                TimeSettingsDropdownButton(value: "\(preferences?.dayStartHour ?? 6):00", isExpanded: false)
            }
        }
    }

    private var weekStartRow: some View {
        TimeSettingsRow(
            icon: "calendar",
            iconColor: Theme.primaryAccent,
            title: "Week Starts On"
        ) {
            Menu {
                ForEach(Weekday.allCases) { weekday in
                    Button(weekday.title) {
                        onUpdate {
                            $0.firstWeekdayValue = weekday
                        }
                    }
                }
            } label: {
                TimeSettingsDropdownButton(value: preferences?.firstWeekdayValue.title ?? Weekday.monday.title, isExpanded: false)
            }
        }
    }
}
