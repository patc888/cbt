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
    let onEditBlock: (TimeBlock) -> Void
    let onMoveBlock: (TimeBlock, Date) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var maxScheduledMinutes: Int {
        max(weekDays.map(\.snapshot.scheduledMinutes).max() ?? 0, 1)
    }

    private var allWeekBlocks: [TimeBlock] {
        weekDays.flatMap { $0.snapshot.blocks }
    }

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
                    "Weekly Planning",
                    subtitle: selectedWeekText
                )

                Spacer(minLength: 0)

                HStack(spacing: 8) {
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

            Text("Drag planned blocks between day columns to rebalance the week. Drops keep each block's original start time and duration.")
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
                                    allWeekBlocks: allWeekBlocks,
                                    maxScheduledMinutes: maxScheduledMinutes,
                                    onEditBlock: onEditBlock,
                                    onMoveBlock: onMoveBlock
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
                                allWeekBlocks: allWeekBlocks,
                                maxScheduledMinutes: maxScheduledMinutes,
                                onEditBlock: onEditBlock,
                                onMoveBlock: onMoveBlock
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
    let allWeekBlocks: [TimeBlock]
    let maxScheduledMinutes: Int
    let onEditBlock: (TimeBlock) -> Void
    let onMoveBlock: (TimeBlock, Date) -> Void

    @State private var isDropTargeted = false

    private var blocks: [TimeBlock] {
        day.snapshot.blocks
    }

    private var loadFraction: CGFloat {
        CGFloat(day.snapshot.scheduledMinutes) / CGFloat(maxScheduledMinutes)
    }

    private var isSelected: Bool {
        calendar.isDate(day.date, inSameDayAs: selectedDate)
    }

    private var isToday: Bool {
        calendar.isDateInToday(day.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                selectedDate = day.date
            } label: {
                VStack(alignment: .leading, spacing: 10) {
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
                        Label("\(day.snapshot.plannedCount)", systemImage: "calendar.badge.clock")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))

                        Text(minutesText)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                    }
                    .foregroundStyle(Theme.secondaryText)

                    if day.calendarSummary.hasEvents {
                        HStack(spacing: 8) {
                            Label("\(day.calendarSummary.totalCount)", systemImage: "calendar")
                                .font(.system(size: 11, weight: .bold, design: .rounded))

                            if day.calendarSummary.hasAllDayEvent {
                                Text("All-day")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }

                            if day.calendarSummary.busyMinutes > 0 {
                                Text(calendarBusyText)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                            }

                            if day.conflictCount > 0 {
                                Label("\(day.conflictCount)", systemImage: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(.orange)
                            }
                        }
                        .foregroundStyle(Color.blue)
                    } else if day.conflictCount > 0 {
                        Label("\(day.conflictCount) conflict\(day.conflictCount == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                    }

                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Theme.primaryPurple.opacity(0.12))

                            Capsule()
                                .fill(Theme.primaryGradient)
                                .frame(width: max(proxy.size.width * loadFraction, day.snapshot.scheduledMinutes == 0 ? 0 : 10))
                        }
                    }
                    .frame(height: 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                if blocks.isEmpty {
                    Text("No blocks")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .center)
                } else {
                    ForEach(blocks) { block in
                        WeeklyPlanningBlockCard(
                            block: block,
                            onEdit: {
                                selectedDate = day.date
                                onEditBlock(block)
                            }
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 84, alignment: .top)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 280, alignment: .topLeading)
        .background(columnBackground)
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                .strokeBorder(columnBorderColor, lineWidth: isDropTargeted ? 2 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous))
        .dropDestination(for: String.self) { items, _ in
            guard let blockID = items.compactMap(UUID.init(uuidString:)).first,
                  let block = allWeekBlocks.first(where: { $0.id == blockID }) else {
                return false
            }

            selectedDate = day.date
            onMoveBlock(block, day.date)
            return true
        } isTargeted: { isTargeted in
            self.isDropTargeted = isTargeted
        }
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

    private var calendarBusyText: String {
        if day.calendarSummary.busyMinutes.isMultiple(of: 60) {
            return "\(day.calendarSummary.busyMinutes / 60)h busy"
        }

        return "\(day.calendarSummary.busyMinutes) min busy"
    }

    private var columnBackground: some View {
        RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
            .fill(
                isDropTargeted
                    ? Theme.primaryPurple.opacity(0.12)
                    : (isSelected ? Theme.primaryPurple.opacity(0.08) : Color.primary.opacity(0.03))
            )
    }

    private var columnBorderColor: Color {
        if isDropTargeted {
            return Theme.primaryPurple.opacity(0.34)
        }

        if isSelected {
            return Theme.primaryPurple.opacity(0.2)
        }

        return Color.primary.opacity(0.08)
    }
}

private struct WeeklyPlanningBlockCard: View {
    @Environment(\.colorScheme) private var colorScheme

    let block: TimeBlock
    let onEdit: () -> Void

    private var supportsDrag: Bool {
        block.status == .planned
    }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(categoryColor.opacity(0.9))
                        .frame(width: 9, height: 9)
                        .padding(.top, 4)

                    Text(block.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(2)

                    Spacer(minLength: 0)

                    if block.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                }

                Text(timeRangeText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)

                HStack(spacing: 8) {
                    Text(block.category.title)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(categoryColor)

                    if supportsDrag {
                        Label("Move", systemImage: "arrow.left.and.right")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryPurple)
                    } else {
                        Text(block.status.rawValue.capitalized)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorScheme == .light ? Color.white.opacity(0.9) : Color.white.opacity(0.08))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(categoryColor.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .draggableIfNeeded(supportsDrag, payload: block.id.uuidString) {
            TimeBlockDragPreviewView(
                block: block,
                destinationDate: nil
            )
        }
    }

    private var timeRangeText: String {
        let start = block.startDate.formatted(date: .omitted, time: .shortened)
        let end = block.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }

    private var categoryColor: Color {
        switch block.category {
        case .focus:
            return Theme.primaryPurple
        case .personal:
            return .green
        case .admin:
            return .orange
        case .routine:
            return .blue
        case .custom:
            return .pink
        }
    }
}

private extension View {
    @ViewBuilder
    func draggableIfNeeded<Preview: View>(
        _ condition: Bool,
        payload: String,
        @ViewBuilder preview: () -> Preview
    ) -> some View {
        if condition {
            draggable(payload, preview: preview)
        } else {
            self
        }
    }
}
