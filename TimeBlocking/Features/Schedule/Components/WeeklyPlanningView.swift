import SwiftUI

struct WeeklyPlanningDay: Identifiable {
    let date: Date
    let snapshot: ScheduleDaySnapshot
    let calendarSummary: TimeCalendarDaySummary
    let conflictCount: Int

    var id: Date { date }
}

struct WeeklyPlanningView: View {
    @Binding var selectedDate: Date

    let weekDays: [WeeklyPlanningDay]
    let calendar: Calendar
    let onShiftWeek: (Int) -> Void
    let onSelectDay: (Date) -> Void
    let onShowMonth: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var selectedWeekText: String {
        guard let firstDate = weekDays.first?.date, let lastDate = weekDays.last?.date else {
            return selectedDate.formatted(.dateTime.month(.wide).day())
        }

        if calendar.isDate(firstDate, equalTo: lastDate, toGranularity: .month) {
            return "\(firstDate.formatted(.dateTime.month(.wide))) \(firstDate.formatted(.dateTime.day()))-\(lastDate.formatted(.dateTime.day()))"
        }

        return "\(firstDate.formatted(.dateTime.month(.abbreviated).day())) - \(lastDate.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var isCompactLayout: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                TimeSectionHeader(
                    "Week Overview",
                    subtitle: "\(selectedWeekText) • Choose a day to edit below"
                )

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button("Month") {
                        onShowMonth()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onShiftWeek(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onShiftWeek(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)
                }
                .tint(Theme.primaryPurple)
            }

            Text("Week is an overview layer. Tap a day to return to the single Day editing canvas.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            Group {
                if isCompactLayout {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(weekDays) { day in
                                WeeklyPlanningDayColumn(
                                    selectedDate: $selectedDate,
                                    day: day,
                                    calendar: calendar,
                                    onSelectDay: onSelectDay
                                )
                                .frame(width: 180)
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(weekDays) { day in
                            WeeklyPlanningDayColumn(
                                selectedDate: $selectedDate,
                                day: day,
                                calendar: calendar,
                                onSelectDay: onSelectDay
                            )
                            .frame(maxWidth: .infinity, alignment: .top)
                        }
                    }
                }
            }
        }
    }
}

private struct WeeklyPlanningDayColumn: View {
    @Binding var selectedDate: Date

    let day: WeeklyPlanningDay
    let calendar: Calendar
    let onSelectDay: (Date) -> Void

    private var isSelected: Bool {
        calendar.isDate(day.date, inSameDayAs: selectedDate)
    }

    private var isToday: Bool {
        calendar.isDateInToday(day.date)
    }

    var body: some View {
        Button {
            selectedDate = day.date
            onSelectDay(day.date)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(isSelected ? Theme.primaryPurple : Theme.secondaryText)

                    Text(day.date.formatted(.dateTime.day()))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Spacer(minLength: 0)

                    if isToday {
                        Text("Today")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryPurple)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Theme.primaryPurple.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    weekStatPill("\(day.snapshot.plannedCount) planned", systemImage: "calendar.badge.clock", tint: Theme.primaryPurple)
                    weekStatPill(minutesText, systemImage: "timer", tint: Theme.primaryText)
                }

                if day.calendarSummary.hasEvents || day.conflictCount > 0 {
                    HStack(spacing: 8) {
                        if day.calendarSummary.hasEvents {
                            weekStatPill("\(day.calendarSummary.totalCount) events", systemImage: "calendar", tint: .blue)
                        }

                        if day.conflictCount > 0 {
                            weekStatPill("\(day.conflictCount) conflict\(day.conflictCount == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill", tint: .orange)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(day.snapshot.blocks.isEmpty ? "Schedule" : "Preview")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)

                    ForEach(blockPreviewLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                            .lineLimit(1)
                    }
                }

                HStack {
                    Text(isSelected ? "Editing this day below" : "Open in Day")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryPurple)

                    Spacer(minLength: 0)

                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.primaryPurple)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 250, alignment: .topLeading)
        .background(columnBackground)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(columnBorderColor, lineWidth: isSelected ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous))
    }

    private var minutesText: String {
        if day.snapshot.scheduledMinutes == 0 {
            return "0 min"
        }

        if day.snapshot.scheduledMinutes.isMultiple(of: 60) {
            return "\(day.snapshot.scheduledMinutes / 60)h"
        }

        return "\(day.snapshot.scheduledMinutes) min"
    }

    private var columnBackground: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
            .fill(isSelected ? Theme.primaryPurple.opacity(0.08) : Color.primary.opacity(0.03))
    }

    private var columnBorderColor: Color {
        if isSelected {
            return Theme.primaryPurple.opacity(0.28)
        }

        return Color.primary.opacity(0.08)
    }

    private var blockPreviewLines: [String] {
        if day.snapshot.blocks.isEmpty {
            return ["No blocks scheduled"]
        }

        return Array(day.snapshot.blocks.prefix(3)).map { block in
            let time = block.startDate.formatted(date: .omitted, time: .shortened)
            return "\(time)  \(block.title)"
        }
    }

    private func weekStatPill(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(tint.opacity(0.08))
            .clipShape(Capsule())
    }
}
