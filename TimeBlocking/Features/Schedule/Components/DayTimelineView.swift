import SwiftUI
import SwiftData

enum DayTimelineBuiltInItemKind: String, CaseIterable, Identifiable {
    case wakeUp
    case sleep

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wakeUp:
            "Wake Up"
        case .sleep:
            "Sleep"
        }
    }

    var detailLabel: String {
        switch self {
        case .wakeUp:
            "Start of day"
        case .sleep:
            "End of day"
        }
    }

    var systemImage: String {
        switch self {
        case .wakeUp:
            "sunrise.fill"
        case .sleep:
            "moon.stars.fill"
        }
    }
}

struct DayTimelineChecklistItemSnapshot: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
}

struct DayTimelineBlockSnapshot: Identifiable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date
    let category: TimeBlockCategory
    let status: TimeBlockStatus
    let isTemplateBacked: Bool
    let checklistItems: [DayTimelineChecklistItemSnapshot]
    let builtInKind: DayTimelineBuiltInItemKind?

    init(block: TimeBlock) {
        id = block.id
        title = block.title
        startDate = block.startDate
        endDate = block.endDate
        category = block.category
        status = block.status
        isTemplateBacked = block.template != nil
        builtInKind = nil
        checklistItems = (block.checklistItems ?? [])
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt < rhs.createdAt
                }

                return lhs.sortOrder < rhs.sortOrder
            }
            .map { item in
                DayTimelineChecklistItemSnapshot(
                    id: item.id,
                    title: item.title,
                    isCompleted: item.isCompleted
                )
            }
    }

    init(
        builtInKind: DayTimelineBuiltInItemKind,
        startDate: Date,
        endDate: Date,
        status: TimeBlockStatus
    ) {
        id = builtInKind == .wakeUp
            ? UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
            : UUID(uuidString: "00000000-0000-0000-0000-000000000002") ?? UUID()
        title = builtInKind.title
        self.startDate = startDate
        self.endDate = endDate
        category = .routine
        self.status = status
        isTemplateBacked = false
        checklistItems = []
        self.builtInKind = builtInKind
    }

    var isBuiltInStructuralItem: Bool {
        builtInKind != nil
    }
}

struct DayTimelineView: View {
    let date: Date
    let blocks: [DayTimelineBlockSnapshot]
    let structuralItems: [DayTimelineBlockSnapshot]
    let calendarEvents: [TimeCalendarEvent]
    let blockConflictsByID: [UUID: ScheduleBlockConflictSummary]
    let expandedChecklistBlockIDs: Set<UUID>
    let dayStartHour: Int
    let calendar: Calendar
    let onEdit: (UUID) -> Void
    let onToggleCompletion: (UUID) -> Void
    let onToggleStructuralItemCompletion: (DayTimelineBuiltInItemKind) -> Void
    let onToggleChecklistExpansion: (UUID) -> Void
    let onToggleChecklistItem: (UUID, UUID) -> Void
    let onMoveBlock: (UUID, Date) -> Void
    let onCreateBlock: (Date) -> Void

    @State private var dragSession: TimelineBlockDragSession?

    private let hourHeight: CGFloat = 74
    private let labelColumnWidth: CGFloat = 40
    private let snapMinutes = 15
    private let minimumBlockHeight: CGFloat = 44
    private let timelineVerticalPadding: CGFloat = 18
    private let structuralCardHeight: CGFloat = 52
    private let structuralCardSpacing: CGFloat = 10

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

    private var timelineContentTopInset: CGFloat {
        timelineVerticalPadding + structuralCardHeight + structuralCardSpacing
    }

    private var timelineContentBottomInset: CGFloat {
        timelineVerticalPadding + structuralCardHeight + structuralCardSpacing
    }

    private var timelineFrameHeight: CGFloat {
        timelineContentTopInset + timelineHeight + timelineContentBottomInset
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    .padding(.horizontal, 8)
                    .padding(.top, timelineContentTopInset)

                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(longPressCreationGesture(in: proxy))

                    timelineStructuralItems

                    ForEach(timedCalendarEvents) { event in
                        let eventWidth = max(proxy.size.width - labelColumnWidth - 26, 140)
                        let visibleStartDate = displayedStartDate(for: event)

                        CalendarTimelineEventCard(
                            event: event,
                            visibleStartDate: visibleStartDate,
                            visibleEndDate: displayedEndDate(for: event)
                        )
                        .frame(width: eventWidth, height: eventHeight(for: event))
                        .position(
                            x: labelColumnWidth + 10 + (eventWidth / 2),
                            y: timelineContentTopInset + yOffset(for: visibleStartDate) + (eventHeight(for: event) / 2)
                        )
                        .zIndex(0)
                    }

                    ForEach(blocks) { block in
                        let blockWidth = max(proxy.size.width - labelColumnWidth - 14, 150)
                        DayTimelineBlockCard(
                            block: block,
                            displayedStartDate: displayedStartDate(for: block),
                            conflictSummary: blockConflictsByID[block.id],
                            isChecklistExpanded: expandedChecklistBlockIDs.contains(block.id),
                            isDragging: dragSession?.blockID == block.id,
                            onEdit: {
                                onEdit(block.id)
                            },
                            onToggleCompletion: {
                                onToggleCompletion(block.id)
                            },
                            onToggleChecklistExpansion: {
                                onToggleChecklistExpansion(block.id)
                            },
                            onToggleChecklistItem: { itemID in
                                onToggleChecklistItem(block.id, itemID)
                            }
                        )
                        .frame(width: blockWidth, height: blockHeight(for: block))
                        .position(
                            x: labelColumnWidth + 6 + (blockWidth / 2),
                            y: timelineContentTopInset + yOffset(for: displayedStartDate(for: block)) + (blockHeight(for: block) / 2)
                        )
                        .zIndex(dragSession?.blockID == block.id ? 20 : 1)
                        .highPriorityGesture(
                            dragGesture(for: block),
                            including: block.status == .planned && !block.isBuiltInStructuralItem ? .gesture : .subviews
                        )
                        .onTapGesture {
                            guard !block.isBuiltInStructuralItem else {
                                return
                            }

                            onEdit(block.id)
                        }
                    }
                }
            }
            .frame(height: timelineFrameHeight)
        }
    }

    private func longPressCreationGesture(in proxy: GeometryProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.4)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onEnded { value in
                guard case .second(true, let drag?) = value,
                      let pressedDate = startDate(forBackgroundPressAt: drag.location, in: proxy.size) else {
                    return
                }

                HapticManager.shared.mediumImpact()
                onCreateBlock(pressedDate)
            }
    }

    private var timelineStructuralItems: some View {
        GeometryReader { proxy in
            let cardWidth = max(proxy.size.width - labelColumnWidth - 14, 150)

            ZStack(alignment: .topLeading) {
                if let wakeUpItem = structuralItems.first(where: { $0.builtInKind == .wakeUp }) {
                    DayTimelineBlockCard(
                        block: wakeUpItem,
                        displayedStartDate: wakeUpItem.startDate,
                        conflictSummary: nil,
                        isChecklistExpanded: false,
                        isDragging: false,
                        onEdit: nil,
                        onToggleCompletion: {
                            if let builtInKind = wakeUpItem.builtInKind {
                                onToggleStructuralItemCompletion(builtInKind)
                            }
                        },
                        onToggleChecklistExpansion: nil,
                        onToggleChecklistItem: { _ in }
                    )
                    .frame(width: cardWidth, height: structuralCardHeight)
                    .position(
                        x: labelColumnWidth + 6 + (cardWidth / 2),
                        y: timelineVerticalPadding + (structuralCardHeight / 2)
                    )
                }

                if let sleepItem = structuralItems.first(where: { $0.builtInKind == .sleep }) {
                    DayTimelineBlockCard(
                        block: sleepItem,
                        displayedStartDate: sleepItem.startDate,
                        conflictSummary: nil,
                        isChecklistExpanded: false,
                        isDragging: false,
                        onEdit: nil,
                        onToggleCompletion: {
                            if let builtInKind = sleepItem.builtInKind {
                                onToggleStructuralItemCompletion(builtInKind)
                            }
                        },
                        onToggleChecklistExpansion: nil,
                        onToggleChecklistItem: { _ in }
                    )
                    .frame(width: cardWidth, height: structuralCardHeight)
                    .position(
                        x: labelColumnWidth + 6 + (cardWidth / 2),
                        y: timelineContentTopInset + timelineHeight + structuralCardSpacing + (structuralCardHeight / 2)
                    )
                }
            }
        }
    }

    private func hourLabel(for hour: Int) -> String {
        let clampedHour = min(max(hour, 0), 23)
        let sampleDate = calendar.date(bySettingHour: clampedHour, minute: 0, second: 0, of: timelineBounds.startOfDay) ?? timelineBounds.startOfDay
        return sampleDate.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }

    private func blockHeight(for block: DayTimelineBlockSnapshot) -> CGFloat {
        let durationMinutes = max(block.endDate.timeIntervalSince(block.startDate) / 60, 15)
        return max(CGFloat(durationMinutes / 60) * hourHeight, minimumBlockHeight) + checklistExpansionHeight(for: block)
    }

    private func eventHeight(for event: TimeCalendarEvent) -> CGFloat {
        let clippedDuration = max(displayedEndDate(for: event).timeIntervalSince(displayedStartDate(for: event)) / 60, 15)
        return max(CGFloat(clippedDuration / 60) * hourHeight, 40)
    }

    private func yOffset(for startDate: Date) -> CGFloat {
        let minutes = startDate.timeIntervalSince(timelineBounds.rangeStart) / 60
        return CGFloat(minutes / 60) * hourHeight
    }

    private func displayedStartDate(for block: DayTimelineBlockSnapshot) -> Date {
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

    private func checklistExpansionHeight(for block: DayTimelineBlockSnapshot) -> CGFloat {
        guard expandedChecklistBlockIDs.contains(block.id) else {
            return 0
        }

        let checklistCount = block.checklistItems.count
        guard checklistCount > 0 else {
            return 0
        }

        let visibleRowCount = min(checklistCount, 4)
        return CGFloat(visibleRowCount) * 34 + 18
    }

    private func dragGesture(for block: DayTimelineBlockSnapshot) -> some Gesture {
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

                onMoveBlock(block.id, proposedStartDate)
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

    private func startDate(forBackgroundPressAt location: CGPoint, in size: CGSize) -> Date? {
        let timelineMinX = labelColumnWidth
        let timelineMaxX = size.width
        let timelineMinY = timelineContentTopInset
        let timelineMaxY = timelineContentTopInset + timelineHeight

        guard location.x >= timelineMinX,
              location.x <= timelineMaxX,
              location.y >= timelineMinY,
              location.y <= timelineMaxY else {
            return nil
        }

        let offsetY = location.y - timelineContentTopInset
        let minuteOffset = Int((offsetY / hourHeight) * 60)
        let snappedMinuteOffset = Int((Double(minuteOffset) / Double(snapMinutes)).rounded()) * snapMinutes
        let candidateDate = timelineBounds.rangeStart.addingTimeInterval(Double(snappedMinuteOffset * 60))
        let latestStartDate = timelineBounds.endOfDay.addingTimeInterval(-15 * 60)

        return min(max(candidateDate, timelineBounds.startOfDay), latestStartDate)
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
    let block: DayTimelineBlockSnapshot
    let displayedStartDate: Date
    let conflictSummary: ScheduleBlockConflictSummary?
    let isChecklistExpanded: Bool
    let isDragging: Bool
    let onEdit: (() -> Void)?
    let onToggleCompletion: () -> Void
    let onToggleChecklistExpansion: (() -> Void)?
    let onToggleChecklistItem: (UUID) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var fillProgress: CGFloat = 0
    @State private var bounceScale: CGFloat = 1.0
    @State private var isAnimating = false

    private var isCompleted: Bool {
        block.status == .completed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isChecklistExpanded ? 12 : 6) {
            header

            if !sortedChecklistItems.isEmpty && isChecklistExpanded {
                checklistSummaryButton
            }

            if isChecklistExpanded && !sortedChecklistItems.isEmpty {
                expandedChecklist
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundFill)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(borderColor, lineWidth: conflictSummary == nil ? 1.25 : 1.5)
        }
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isCompleted ? Color.clear : tintColor.opacity(0.9))
                .frame(width: 4)
                .padding(.vertical, 10)
        }
        .shadow(color: tintColor.opacity(isDragging ? 0.18 : 0.08), radius: isDragging ? 22 : 6, x: 0, y: isDragging ? 12 : 3)
        .scaleEffect(isDragging ? 1.015 : bounceScale)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isDragging)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isChecklistExpanded)
    }

    private var sortedChecklistItems: [DayTimelineChecklistItemSnapshot] {
        block.checklistItems
    }

    private var checklistCompletionCount: Int {
        sortedChecklistItems.filter(\.isCompleted).count
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Button(action: handleComplete) {
                ZStack {
                    Circle()
                        .stroke(
                            isCompleted ? Color.green : tintColor.opacity(0.35),
                            lineWidth: 2
                        )
                        .frame(width: 26, height: 26)

                    if isCompleted || fillProgress > 0.9 {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 26, height: 26)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isAnimating)
            .accessibilityLabel(block.status == .completed ? "Mark item as planned" : "Mark item as completed")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    categoryIcon

                    Text(block.title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(isCompleted ? secondaryTextColor : primaryTextColor)
                        .strikethrough(isCompleted, color: secondaryTextColor)
                        .opacity(isCompleted ? 0.82 : 1)
                        .lineLimit(2)

                    if block.isTemplateBacked {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(isCompleted ? secondaryTextColor.opacity(0.75) : secondaryTextColor)
                    }
                }

                HStack(spacing: 8) {
                    Text(timeRangeText)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)

                    if isCompleted {
                        Text("Done")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.green)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.12))
                            )
                    }

                    if let conflictSummary, !isDragging {
                        Text(conflictSummary.badgeText)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(conflictAccentColor)
                    }
                }
            }

            Spacer(minLength: 0)

            if isDragging {
                Text(displayedStartDate.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(tintColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.96))
                    .clipShape(Capsule())
            }
        }
    }

    private var categoryIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tintColor.opacity(isCompleted ? 0.3 : 1.0))
                .frame(width: 22, height: 22)

            Image(systemName: iconSystemName)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isCompleted ? Color.white.opacity(0.6) : Color.white)
        }
    }

    private var checklistSummaryButton: some View {
        Button(action: onToggleChecklistExpansion ?? {}) {
            HStack(spacing: 8) {
                Text("\(checklistCompletionCount)/\(sortedChecklistItems.count) checklist items")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 0)

                Image(systemName: isChecklistExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(onToggleChecklistExpansion == nil)
        .accessibilityLabel(isChecklistExpanded ? "Collapse checklist" : "Expand checklist")
    }

    private var expandedChecklist: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(sortedChecklistItems.prefix(4)) { item in
                Button {
                    onToggleChecklistItem(item.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(item.isCompleted ? .green : secondaryTextColor)

                        Text(item.title)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(item.isCompleted ? secondaryTextColor : primaryTextColor)
                            .strikethrough(item.isCompleted)
                            .lineLimit(2)

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(item.isCompleted ? .green.opacity(0.06) : Color.primary.opacity(0.03))
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.isCompleted ? "Mark checklist item incomplete" : "Mark checklist item complete")
            }

            if sortedChecklistItems.count > 4 {
                Text("+\(sortedChecklistItems.count - 4) more in edit view")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }
        }
    }

    private var timeRangeText: String {
        if let builtInKind = block.builtInKind {
            return builtInKind.detailLabel
        }

        let endDate = displayedStartDate.addingTimeInterval(block.endDate.timeIntervalSince(block.startDate))
        let start = displayedStartDate.formatted(date: .omitted, time: .shortened)
        let end = endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }

    private var tintColor: Color {
        if let builtInKind = block.builtInKind {
            switch builtInKind {
            case .wakeUp:
                return Color(hex: "F59E0B")
            case .sleep:
                return Theme.primaryPurple
            }
        }

        switch block.category {
        case .focus:
            return Theme.primaryPurple
        case .personal:
            return Color(hex: "F59E0B")
        case .admin:
            return Color(hex: "0EA5E9")
        case .routine:
            return Color(hex: "10B981")
        case .custom:
            return Color(hex: "64748B")
        }
    }

    private var backgroundFill: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    isCompleted
                    ? (colorScheme == .dark ? Color.white.opacity(0.03) : Color.gray.opacity(0.04))
                    : (colorScheme == .light ? .white : Color(.secondarySystemGroupedBackground))
                )
            
            if fillProgress > 0 {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(tintColor.opacity(0.12))
                    .scaleEffect(x: fillProgress, anchor: .leading)
            }
        }
    }

    private func handleComplete() {
        if isCompleted {
            onToggleCompletion()
            return
        }
        
        guard !isAnimating else { return }
        
        isAnimating = true
        HapticManager.shared.success()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            bounceScale = 1.05
        }
        withAnimation(.easeInOut(duration: 0.5)) {
            fillProgress = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                bounceScale = 1.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onToggleCompletion()
            isAnimating = false
            fillProgress = 0
        }
    }

    private var iconSystemName: String {
        if let builtInKind = block.builtInKind {
            return builtInKind.systemImage
        }

        switch block.category {
        case .focus:
            return "scope"
        case .personal:
            return "figure.walk"
        case .admin:
            return "tray.full.fill"
        case .routine:
            return "repeat"
        case .custom:
            return "square.grid.2x2.fill"
        }
    }

    private var primaryTextColor: Color {
        Theme.primaryText
    }

    private var secondaryTextColor: Color {
        Theme.secondaryText
    }

    private var conflictAccentColor: Color {
        Color(hex: "B45309")
    }

    private var borderColor: Color {
        if isDragging {
            return Color.white.opacity(0.4)
        }

        if conflictSummary != nil {
            return conflictAccentColor.opacity(0.8)
        }

        if isCompleted {
            return Color.primary.opacity(0.04)
        }

        return tintColor.opacity(0.18)
    }
}
