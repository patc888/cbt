import SwiftUI

struct MonthlyPlanningView: View {
    @Binding var selectedDate: Date

    let days: [MonthlyPlanningDay]
    let summary: ScheduleMonthSummary
    let calendar: Calendar
    let onSelectDay: (Date) -> Void
    let onShiftMonth: (Int) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 7)
    }

    private var weekdaySymbols: [String] {
        ScheduleMonthSupport.weekdaySymbols(calendar: calendar)
    }

    private var maxScheduledMinutes: Int {
        max(days.filter(\.isInDisplayedMonth).map(\.snapshot.scheduledMinutes).max() ?? 0, 1)
    }

    private var cellHeight: CGFloat {
        horizontalSizeClass == .compact ? 76 : 86
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                TimeSectionHeader(
                    "Monthly Planning",
                    subtitle: summary.monthLabel
                )

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    Button {
                        onShiftMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        onShiftMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.bordered)
                }
                .tint(Theme.primaryPurple)
            }

            Text("Tap a day to move into detailed planning.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .padding(.bottom, 2)
                }

                ForEach(days) { day in
                    MonthlyPlanningDayCell(
                        selectedDate: $selectedDate,
                        day: day,
                        maxScheduledMinutes: maxScheduledMinutes,
                        calendar: calendar,
                        cellHeight: cellHeight,
                        onSelectDay: onSelectDay
                    )
                }
            }

            if !summary.hasBlocks {
                Text("No blocks scheduled yet.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
    }
}

private struct MonthlyPlanningDayCell: View {
    @Binding var selectedDate: Date

    let day: MonthlyPlanningDay
    let maxScheduledMinutes: Int
    let calendar: Calendar
    let cellHeight: CGFloat
    let onSelectDay: (Date) -> Void

    private var isSelected: Bool {
        calendar.isDate(day.date, inSameDayAs: selectedDate)
    }

    private var isToday: Bool {
        calendar.isDateInToday(day.date)
    }

    private var loadFraction: CGFloat {
        guard day.snapshot.scheduledMinutes > 0 else {
            return 0
        }

        return CGFloat(day.snapshot.scheduledMinutes) / CGFloat(maxScheduledMinutes)
    }

    private var visibleIndicatorCount: Int {
        min(day.totalBlockCount, 3)
    }

    private var overflowIndicatorCount: Int {
        max(day.totalBlockCount - visibleIndicatorCount, 0)
    }

    var body: some View {
        Button {
            selectedDate = day.date
            onSelectDay(day.date)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 2) {
                    Text(day.date.formatted(.dateTime.day()))
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(dayNumberColor)
                        .lineLimit(1)

                    if isToday {
                        Circle()
                            .fill(Theme.primaryPurple)
                            .frame(width: 5, height: 5)
                    }

                    Spacer(minLength: 0)
                }

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 4) {
                    if day.totalBlockCount > 0 {
                        HStack(spacing: 1.5) {
                            ForEach(0..<visibleIndicatorCount, id: \.self) { index in
                                Circle()
                                    .fill(indicatorColor(for: index))
                                    .frame(width: 3.5, height: 3.5)
                            }

                            if overflowIndicatorCount > 0 {
                                Text("+\(overflowIndicatorCount)")
                                    .font(.system(size: 7, weight: .heavy, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText.opacity(day.isInDisplayedMonth ? 0.9 : 0.55))
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Color.clear
                            .frame(height: 4)
                    }

                    Capsule()
                        .fill(trackColor)
                        .frame(height: 2.5)
                        .overlay(alignment: .leading) {
                            if day.snapshot.scheduledMinutes > 0 {
                                GeometryReader { geometry in
                                    Capsule()
                                        .fill(fillColor)
                                        .frame(width: max(3, geometry.size.width * loadFraction), height: 2.5)
                                }
                                .clipShape(Capsule())
                            }
                        }
                        .opacity(day.isInDisplayedMonth ? 1 : 0.6)

                    if day.snapshot.completedCount > 0, day.totalBlockCount > 0 {
                        GeometryReader { geometry in
                            Capsule()
                                .fill(Color.green.opacity(day.isInDisplayedMonth ? 0.8 : 0.45))
                                .frame(width: max(3, geometry.size.width * CGFloat(day.completionFraction)), height: 1.5)
                        }
                        .frame(height: 1.5)
                    } else {
                        Color.clear
                            .frame(height: 1.5)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: cellHeight, maxHeight: cellHeight, alignment: .topLeading)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .background(cellBackground)
            .clipped()
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var dayNumberColor: Color {
        if isSelected {
            return Theme.primaryPurple
        }

        if day.isInDisplayedMonth {
            return Theme.primaryText
        }

        return Theme.secondaryText.opacity(0.45)
    }

    private func indicatorColor(for index: Int) -> Color {
        if index < day.snapshot.completedCount {
            return Color.green.opacity(day.isInDisplayedMonth ? 0.85 : 0.45)
        }

        return Theme.primaryPurple.opacity(day.isInDisplayedMonth ? 0.75 : 0.35)
    }

    private var trackColor: Color {
        day.isInDisplayedMonth ? Color.primary.opacity(0.08) : Color.primary.opacity(0.04)
    }

    private var fillColor: LinearGradient {
        if day.totalBlockCount > 0, day.snapshot.completedCount == day.totalBlockCount {
            return LinearGradient(colors: [.green.opacity(0.9), .green.opacity(0.65)], startPoint: .leading, endPoint: .trailing)
        }

        return Theme.primaryGradient
    }

    private var cellBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Theme.primaryPurple.opacity(0.1)
        }

        if day.isInDisplayedMonth {
            return Color.primary.opacity(0.035)
        }

        return Color.primary.opacity(0.015)
    }

    private var borderColor: Color {
        if isSelected {
            return Theme.primaryPurple.opacity(0.35)
        }

        if isToday {
            return Theme.primaryPurple.opacity(0.18)
        }

        return Color.primary.opacity(day.isInDisplayedMonth ? 0.07 : 0.03)
    }

    private var accessibilityLabel: String {
        let dateText = day.date.formatted(.dateTime.weekday(.wide).month(.wide).day())
        let countText = day.totalBlockCount == 0 ? "No blocks" : (day.totalBlockCount == 1 ? "1 block" : "\(day.totalBlockCount) blocks")
        let completionText = day.snapshot.completedCount == 0 ? nil : "\(day.snapshot.completedCount) completed"
        let parts = [dateText, countText, completionText].compactMap { $0 }
        return parts.joined(separator: ", ")
    }
}
