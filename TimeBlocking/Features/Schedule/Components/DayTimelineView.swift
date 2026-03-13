import SwiftUI

struct DayTimelineView: View {
    let date: Date
    let blocks: [TimeBlock]
    let calendarEvents: [TimeCalendarEvent]
    let blockConflictsByID: [UUID: ScheduleBlockConflictSummary]
    let dayStartHour: Int
    let calendar: Calendar
    let onEdit: (TimeBlock) -> Void
    let onMoveBlock: (TimeBlock, Date) -> Void

    @State private var dragSession: TimelineBlockDragSession?

    private let hourHeight: CGFloat = 74
    private let labelColumnWidth: CGFloat = 48
    private let snapMinutes = 15
    private let minimumBlockHeight: CGFloat = 54

    private var allDayCalendarEvents: [TimeCalendarEvent] {
        calendarEvents.filter(\.isAllDay)
    }

    private var timedCalendarEvents: [TimeCalendarEvent] {
        calendarEvents.filter { !$0.isAllDay }
    }

    private var timelineBounds: TimelineBounds {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let earliestVisibleStartDate = (blocks.map(\.startDate) + timedCalendarEvents.map(\.startDate)).min()
        let latestVisibleEndDate = (blocks.map(\.endDate) + timedCalendarEvents.map(\.endDate)).max()
        let earliestHour = earliestVisibleStartDate.map { calendar.component(.hour, from: $0) } ?? dayStartHour
        let latestEndDate = latestVisibleEndDate ?? calendar.date(byAdding: .hour, value: 10, to: startOfDay) ?? startOfDay
        let latestComponents = calendar.dateComponents([.hour, .minute], from: latestEndDate)
        let latestRoundedHour = min(24, (latestComponents.hour ?? dayStartHour) + ((latestComponents.minute ?? 0) > 0 ? 1 : 0) + 1)
        let startHour = max(0, min(dayStartHour, earliestHour - 1))
        let endHour = min(24, max(startHour + 12, latestRoundedHour))
        let rangeStart = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: startOfDay) ?? startOfDay
        let rangeEnd = endHour == 24
            ? endOfDay
            : (calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: startOfDay) ?? endOfDay)

        return TimelineBounds(
            startOfDay: startOfDay,
            endOfDay: endOfDay,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            startHour: startHour,
            endHour: endHour
        )
    }

    private var hourMarks: [Int] {
        Array(timelineBounds.startHour..<timelineBounds.endHour)
    }

    private var timelineHeight: CGFloat {
        CGFloat(max(timelineBounds.endHour - timelineBounds.startHour, 1)) * hourHeight
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Label("Day Timeline", systemImage: "timeline.selection")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Spacer(minLength: 0)

                Text("15 min snap")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryPurple)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.primaryPurple.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text("Drag a block vertically to reschedule it within the selected day. Duration stays fixed. Apple Calendar events are read-only.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            if !allDayCalendarEvents.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(allDayCalendarEvents) { event in
                            AllDayCalendarEventChip(event: event)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Theme.primaryPurple.opacity(0.08),
                                    Theme.primaryPurple.opacity(0.03)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Theme.primaryPurple.opacity(0.12), lineWidth: 1)

                    VStack(spacing: 0) {
                        ForEach(hourMarks, id: \.self) { hour in
                            HStack(alignment: .top, spacing: 0) {
                                Text(hourLabel(for: hour))
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                    .frame(width: labelColumnWidth, alignment: .leading)

                                Rectangle()
                                    .fill(Theme.primaryPurple.opacity(hour == timelineBounds.startHour ? 0 : 0.1))
                                    .frame(height: 1)
                            }
                            .frame(height: hourHeight, alignment: .top)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 18)

                    ForEach(timedCalendarEvents) { event in
                        let eventWidth = max(proxy.size.width - labelColumnWidth - 42, 140)
                        let visibleStartDate = displayedStartDate(for: event)

                        CalendarTimelineEventCard(
                            event: event,
                            visibleStartDate: visibleStartDate,
                            visibleEndDate: displayedEndDate(for: event)
                        )
                        .frame(width: eventWidth, height: eventHeight(for: event))
                        .position(
                            x: labelColumnWidth + 22 + (eventWidth / 2),
                            y: 18 + yOffset(for: visibleStartDate) + (eventHeight(for: event) / 2)
                        )
                        .zIndex(0)
                    }

                    ForEach(blocks) { block in
                        let blockWidth = max(proxy.size.width - labelColumnWidth - 26, 150)
                        DayTimelineBlockCard(
                            block: block,
                            displayedStartDate: displayedStartDate(for: block),
                            conflictSummary: blockConflictsByID[block.id],
                            isDragging: dragSession?.blockID == block.id
                        )
                        .frame(width: blockWidth, height: blockHeight(for: block))
                        .position(
                            x: labelColumnWidth + 14 + (blockWidth / 2),
                            y: 18 + yOffset(for: displayedStartDate(for: block)) + (blockHeight(for: block) / 2)
                        )
                        .zIndex(dragSession?.blockID == block.id ? 20 : 1)
                        .highPriorityGesture(dragGesture(for: block))
                        .onTapGesture {
                            onEdit(block)
                        }
                    }
                }
            }
            .frame(height: timelineHeight + 36)
        }
    }

    private func hourLabel(for hour: Int) -> String {
        let clampedHour = min(max(hour, 0), 23)
        let sampleDate = calendar.date(bySettingHour: clampedHour, minute: 0, second: 0, of: timelineBounds.startOfDay) ?? timelineBounds.startOfDay
        return sampleDate.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }

    private func blockHeight(for block: TimeBlock) -> CGFloat {
        let durationMinutes = max(block.endDate.timeIntervalSince(block.startDate) / 60, 15)
        return max(CGFloat(durationMinutes / 60) * hourHeight, minimumBlockHeight)
    }

    private func eventHeight(for event: TimeCalendarEvent) -> CGFloat {
        let clippedDuration = max(displayedEndDate(for: event).timeIntervalSince(displayedStartDate(for: event)) / 60, 15)
        return max(CGFloat(clippedDuration / 60) * hourHeight, 40)
    }

    private func yOffset(for startDate: Date) -> CGFloat {
        let minutes = startDate.timeIntervalSince(timelineBounds.rangeStart) / 60
        return CGFloat(minutes / 60) * hourHeight
    }

    private func displayedStartDate(for block: TimeBlock) -> Date {
        if dragSession?.blockID == block.id {
            return dragSession?.proposedStartDate ?? block.startDate
        }

        return block.startDate
    }

    private func displayedStartDate(for event: TimeCalendarEvent) -> Date {
        max(event.startDate, timelineBounds.rangeStart)
    }

    private func displayedEndDate(for event: TimeCalendarEvent) -> Date {
        min(event.endDate, timelineBounds.rangeEnd)
    }

    private func dragGesture(for block: TimeBlock) -> some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                let duration = block.endDate.timeIntervalSince(block.startDate)

                if dragSession?.blockID != block.id {
                    dragSession = TimelineBlockDragSession(
                        blockID: block.id,
                        originalStartDate: block.startDate,
                        proposedStartDate: block.startDate,
                        duration: duration
                    )
                }

                guard let dragSession else {
                    return
                }

                let proposedStartDate = snappedStartDate(
                    from: dragSession.originalStartDate,
                    translationHeight: value.translation.height,
                    duration: dragSession.duration
                )

                self.dragSession?.proposedStartDate = proposedStartDate
            }
            .onEnded { _ in
                guard let dragSession, dragSession.blockID == block.id else {
                    return
                }

                let proposedStartDate = dragSession.proposedStartDate

                withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                    self.dragSession = nil
                }

                guard proposedStartDate != block.startDate else {
                    return
                }

                onMoveBlock(block, proposedStartDate)
            }
    }

    private func snappedStartDate(
        from originalStartDate: Date,
        translationHeight: CGFloat,
        duration: TimeInterval
    ) -> Date {
        let minuteDelta = Int((translationHeight / hourHeight) * 60)
        let snappedMinuteDelta = Int((Double(minuteDelta) / Double(snapMinutes)).rounded()) * snapMinutes
        let unsnappedDate = originalStartDate.addingTimeInterval(Double(snappedMinuteDelta * 60))
        let minimumStartDate = max(timelineBounds.rangeStart, timelineBounds.startOfDay)
        let maximumStartDate = max(
            minimumStartDate,
            min(
                timelineBounds.rangeEnd.addingTimeInterval(-duration),
                timelineBounds.endOfDay.addingTimeInterval(-duration)
            )
        )

        if unsnappedDate < minimumStartDate {
            return minimumStartDate
        }

        if unsnappedDate > maximumStartDate {
            return maximumStartDate
        }

        return unsnappedDate
    }
}

private struct AllDayCalendarEventChip: View {
    let event: TimeCalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("All day")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(Color.blue)

            Text(event.title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)

            Text(event.sourceTitle)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct CalendarTimelineEventCard: View {
    let event: TimeCalendarEvent
    let visibleStartDate: Date
    let visibleEndDate: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label("Apple Calendar", systemImage: "calendar")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.blue)

                Spacer(minLength: 0)

                Text(timeRangeText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(event.title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2)

            if let location = event.location {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            } else {
                Text(event.sourceTitle)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.blue.opacity(0.08))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.blue.opacity(0.16), lineWidth: 1)
                }
        }
    }

    private var timeRangeText: String {
        let start = visibleStartDate.formatted(date: .omitted, time: .shortened)
        let end = visibleEndDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }
}

private struct TimelineBounds {
    let startOfDay: Date
    let endOfDay: Date
    let rangeStart: Date
    let rangeEnd: Date
    let startHour: Int
    let endHour: Int
}

private struct TimelineBlockDragSession {
    let blockID: UUID
    let originalStartDate: Date
    var proposedStartDate: Date
    let duration: TimeInterval
}

private struct DayTimelineBlockCard: View {
    let block: TimeBlock
    let displayedStartDate: Date
    let conflictSummary: ScheduleBlockConflictSummary?
    let isDragging: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(block.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer(minLength: 0)

                Image(systemName: isDragging ? "arrow.up.and.down" : "line.3.horizontal")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.84))

                if block.template != nil {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.84))
                }
            }

            Text(timeRangeText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))

            HStack(spacing: 8) {
                Label(block.category.title, systemImage: "tag")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))

                if isDragging {
                    Spacer(minLength: 0)

                    Text(displayedStartDate.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(tintColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.94))
                        .clipShape(Capsule())
                } else if let conflictSummary {
                    Spacer(minLength: 0)

                    Label(conflictSummary.badgeText, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(conflictAccentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.94))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tintGradient)
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: conflictSummary == nil ? 1 : 1.5)
                }
        }
        .shadow(color: tintColor.opacity(isDragging ? 0.26 : 0.16), radius: isDragging ? 18 : 10, x: 0, y: isDragging ? 12 : 6)
        .scaleEffect(isDragging ? 1.02 : 1)
        .opacity(isDragging ? 0.98 : 1)
        .animation(.spring(response: 0.24, dampingFraction: 0.84), value: isDragging)
    }

    private var timeRangeText: String {
        let endDate = displayedStartDate.addingTimeInterval(block.endDate.timeIntervalSince(block.startDate))
        let start = displayedStartDate.formatted(date: .omitted, time: .shortened)
        let end = endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }

    private var tintColor: Color {
        switch block.category {
        case .focus:
            Theme.primaryPurple
        case .personal:
            Color(hex: "F59E0B")
        case .admin:
            Color(hex: "0EA5E9")
        case .routine:
            Color(hex: "10B981")
        case .custom:
            Color(hex: "64748B")
        }
    }

    private var tintGradient: LinearGradient {
        LinearGradient(
            colors: [tintColor, tintColor.opacity(0.84)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var conflictAccentColor: Color {
        Color(hex: "B45309")
    }

    private var borderColor: Color {
        if isDragging {
            return Color.white.opacity(0.4)
        }

        if conflictSummary != nil {
            return Color.white.opacity(0.86)
        }

        return Color.white.opacity(0.18)
    }
}
