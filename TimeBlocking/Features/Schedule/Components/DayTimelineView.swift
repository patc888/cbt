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

    private let hourHeight: CGFloat = 80
    private let labelColumnWidth: CGFloat = 46
    private let timelineHorizontalInset: CGFloat = 10
    private let nodeColumnWidth: CGFloat = 44
    private let laneSpacing: CGFloat = 8
    private let snapMinutes = 15
    private let minimumBlockHeight: CGFloat = 64
    private let minimumBlockDurationMinutes: Double = 15
    private let structuralCardHeight: CGFloat = 72
    private let structuralCardSpacing: CGFloat = 12
    private let timelineTopSafeSpacing: CGFloat = 18
    private let timelineBottomSafeSpacing: CGFloat = 16

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
        timelineTopSafeSpacing + structuralCardHeight + structuralCardSpacing
    }

    private var timelineContentBottomInset: CGFloat {
        structuralCardHeight + structuralCardSpacing + timelineBottomSafeSpacing
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
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                                    .frame(width: labelColumnWidth, alignment: .leading)

                                Rectangle()
                                    .fill(Theme.primaryAccent.opacity(hour == timelineBounds.startHour ? 0 : 0.1))
                                    .frame(height: 1)
                            }
                            .frame(height: hourHeight, alignment: .top)
                        }
                    }
                    .padding(.horizontal, timelineHorizontalInset)
                    .padding(.top, timelineContentTopInset)

                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(longPressCreationGesture(in: proxy))

                    timelineStructuralItems

                    ForEach(timedCalendarEvents) { event in
                        let eventWidth = max(proxy.size.width - labelColumnWidth - 30, 156)
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

                    let blockLayouts = timelineBlockLayouts(in: proxy.size.width)

                    ForEach(blockLayouts) { layout in
                        DayTimelineBlockCard(
                            block: layout.block,
                            displayedStartDate: layout.displayedStartDate,
                            blockHeight: layout.blockHeight,
                            contentWidth: layout.contentFrame.width,
                            conflictSummary: blockConflictsByID[layout.block.id],
                            isChecklistExpanded: expandedChecklistBlockIDs.contains(layout.block.id),
                            isDragging: dragSession?.blockID == layout.block.id,
                            showsTopConnector: layout.showsTopConnector,
                            showsBottomConnector: layout.showsBottomConnector,
                            isAttachmentTarget: dragSession?.attachmentTargetID == layout.block.id,
                            isAttachedPreview: dragSession?.blockID == layout.block.id && dragSession?.attachmentTargetID != nil,
                            onEdit: {
                                onEdit(layout.block.id)
                            },
                            onToggleCompletion: {
                                onToggleCompletion(layout.block.id)
                            },
                            onToggleChecklistExpansion: {
                                onToggleChecklistExpansion(layout.block.id)
                            },
                            onToggleChecklistItem: { itemID in
                                onToggleChecklistItem(layout.block.id, itemID)
                            }
                        )
                        .frame(width: layout.frame.width, height: layout.frame.height)
                        .position(x: layout.frame.midX, y: layout.frame.midY)
                        .zIndex(dragSession?.blockID == layout.block.id ? 20 : 1)
                        .highPriorityGesture(
                            dragGesture(for: layout, in: proxy.size.width),
                            including: layout.block.status == .planned && !layout.block.isBuiltInStructuralItem ? .gesture : .subviews
                        )
                        .onTapGesture {
                            guard !layout.block.isBuiltInStructuralItem else {
                                return
                            }

                            onEdit(layout.block.id)
                        }
                    }
                }
            }
            .frame(height: timelineFrameHeight)
            .clipped()
        }
    }

    private func timelineBlockLayouts(in totalWidth: CGFloat) -> [TimelineBlockLayout] {
        let sortedBlocks = blocks.sorted { lhs, rhs in
            let lhsStart = displayedStartDate(for: lhs)
            let rhsStart = displayedStartDate(for: rhs)
            if lhsStart == rhsStart {
                return lhs.endDate < rhs.endDate
            }

            return lhsStart < rhsStart
        }

        struct ActiveLane {
            let laneIndex: Int
            let endDate: Date
        }

        struct PendingLayout {
            let block: DayTimelineBlockSnapshot
            let displayedStartDate: Date
            let displayedEndDate: Date
            let blockHeight: CGFloat
            let laneIndex: Int
            let clusterID: Int
        }

        var activeLanes: [ActiveLane] = []
        var clusterID = -1
        var pendingLayouts: [PendingLayout] = []
        var laneCountByCluster: [Int: Int] = [:]

        for block in sortedBlocks {
            let startDate = displayedStartDate(for: block)
            let endDate = startDate.addingTimeInterval(block.endDate.timeIntervalSince(block.startDate))
            let height = blockHeight(for: block)

            activeLanes.removeAll { $0.endDate <= startDate }
            if activeLanes.isEmpty {
                clusterID += 1
            }

            let occupiedLanes = Set(activeLanes.map(\.laneIndex))
            let laneIndex = (0...).first(where: { !occupiedLanes.contains($0) }) ?? 0
            activeLanes.append(ActiveLane(laneIndex: laneIndex, endDate: endDate))
            laneCountByCluster[clusterID] = max(laneCountByCluster[clusterID] ?? 0, laneIndex + 1)

            pendingLayouts.append(
                PendingLayout(
                    block: block,
                    displayedStartDate: startDate,
                    displayedEndDate: endDate,
                    blockHeight: height,
                    laneIndex: laneIndex,
                    clusterID: clusterID
                )
            )
        }

        let timelineWidth = max(totalWidth - labelColumnWidth - (timelineHorizontalInset * 2), 180)
        let contentStartX = labelColumnWidth + timelineHorizontalInset

        return pendingLayouts.enumerated().map { index, layout in
            let laneCount = max(laneCountByCluster[layout.clusterID] ?? 1, 1)
            let clusterSpacing = laneCount > 2
                ? max(4, laneSpacing - CGFloat(laneCount - 2))
                : laneSpacing
            let laneWidth = laneCount == 1
                ? timelineWidth
                : max(
                    (timelineWidth - (CGFloat(max(laneCount - 1, 0)) * clusterSpacing)) / CGFloat(laneCount),
                    126
                )
            let totalClusterWidth = (laneWidth * CGFloat(laneCount)) + (CGFloat(max(laneCount - 1, 0)) * clusterSpacing)
            let clusterStartX = contentStartX + max((timelineWidth - totalClusterWidth) / 2, 0)
            let frame = CGRect(
                x: clusterStartX + (CGFloat(layout.laneIndex) * (laneWidth + clusterSpacing)),
                y: timelineContentTopInset + yOffset(for: layout.displayedStartDate),
                width: laneWidth,
                height: layout.blockHeight
            )
            let contentFrame = CGRect(
                x: frame.minX + nodeColumnWidth,
                y: frame.minY,
                width: max(frame.width - nodeColumnWidth, 82),
                height: layout.blockHeight
            )
            let previous = index > 0 ? pendingLayouts[index - 1] : nil
            let next = index < (pendingLayouts.count - 1) ? pendingLayouts[index + 1] : nil

            return TimelineBlockLayout(
                block: layout.block,
                displayedStartDate: layout.displayedStartDate,
                blockHeight: layout.blockHeight,
                frame: frame,
                contentFrame: contentFrame,
                nodeCenterX: frame.minX + (nodeColumnWidth / 2),
                showsTopConnector: previous.map {
                    shouldConnect(
                        DateInterval(start: $0.displayedStartDate, end: $0.displayedEndDate),
                        to: DateInterval(start: layout.displayedStartDate, end: layout.displayedEndDate)
                    )
                } ?? false,
                showsBottomConnector: next.map {
                    shouldConnect(
                        DateInterval(start: layout.displayedStartDate, end: layout.displayedEndDate),
                        to: DateInterval(start: $0.displayedStartDate, end: $0.displayedEndDate)
                    )
                } ?? false
            )
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
            let cardWidth = max(proxy.size.width - labelColumnWidth - (timelineHorizontalInset * 2), 150)
            let cardX = labelColumnWidth + timelineHorizontalInset + (cardWidth / 2)

            ZStack(alignment: .topLeading) {
                if let wakeUpItem = structuralItems.first(where: { $0.builtInKind == .wakeUp }) {
                    DayTimelineBlockCard(
                        block: wakeUpItem,
                        displayedStartDate: wakeUpItem.startDate,
                        blockHeight: structuralCardHeight,
                        contentWidth: cardWidth,
                        conflictSummary: nil,
                        isChecklistExpanded: false,
                        isDragging: false,
                        showsTopConnector: false,
                        showsBottomConnector: false,
                        isAttachmentTarget: false,
                        isAttachedPreview: false,
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
                        x: cardX,
                        y: timelineTopSafeSpacing + (structuralCardHeight / 2)
                    )
                }

                if let sleepItem = structuralItems.first(where: { $0.builtInKind == .sleep }) {
                    DayTimelineBlockCard(
                        block: sleepItem,
                        displayedStartDate: sleepItem.startDate,
                        blockHeight: structuralCardHeight,
                        contentWidth: cardWidth,
                        conflictSummary: nil,
                        isChecklistExpanded: false,
                        isDragging: false,
                        showsTopConnector: false,
                        showsBottomConnector: false,
                        isAttachmentTarget: false,
                        isAttachedPreview: false,
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
                        x: cardX,
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
        let durationMinutes = max(block.endDate.timeIntervalSince(block.startDate) / 60, minimumBlockDurationMinutes)
        return max(CGFloat(durationMinutes / 60) * hourHeight, minimumBlockHeight)
    }

    private func eventHeight(for event: TimeCalendarEvent) -> CGFloat {
        let clippedDuration = max(
            displayedEndDate(for: event).timeIntervalSince(displayedStartDate(for: event)) / 60,
            minimumBlockDurationMinutes
        )
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

    private func dragGesture(for layout: TimelineBlockLayout, in timelineWidth: CGFloat) -> some Gesture {
        let block = layout.block

        return DragGesture(minimumDistance: 3)
            .onChanged { value in
                let duration = block.endDate.timeIntervalSince(block.startDate)

                if dragSession?.blockID != block.id {
                    dragSession = TimelineBlockDragSession(
                        blockID: block.id,
                        originalStartDate: block.startDate,
                        proposedStartDate: block.startDate,
                        duration: duration,
                        attachmentTargetID: nil
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

                let dragPoint = CGPoint(
                    x: layout.contentFrame.midX + value.translation.width,
                    y: layout.contentFrame.midY + value.translation.height
                )
                let attachmentTarget = attachmentTarget(
                    for: block.id,
                    at: dragPoint,
                    horizontalTranslation: value.translation.width,
                    in: timelineWidth
                )

                self.dragSession?.proposedStartDate = proposedStartDate
                self.dragSession?.attachmentTargetID = attachmentTarget?.id

                if let attachmentTarget {
                    self.dragSession?.proposedStartDate = clampedStartDate(
                        attachmentTarget.endDate,
                        duration: dragSession.duration
                    )
                }
            }
            .onEnded { _ in
                guard let dragSession, dragSession.blockID == block.id else {
                    return
                }

                let proposedStartDate = dragSession.attachmentTargetID
                    .flatMap { targetBlock(id: $0) }
                    .map { clampedStartDate($0.endDate, duration: dragSession.duration) }
                    ?? dragSession.proposedStartDate

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

    private func clampedStartDate(_ candidateDate: Date, duration: TimeInterval) -> Date {
        let minimumStartDate = max(timelineBounds.rangeStart, timelineBounds.startOfDay)
        let maximumStartDate = max(
            minimumStartDate,
            min(
                timelineBounds.rangeEnd.addingTimeInterval(-duration),
                timelineBounds.endOfDay.addingTimeInterval(-duration)
            )
        )

        return min(max(candidateDate, minimumStartDate), maximumStartDate)
    }

    private func attachmentTarget(
        for blockID: UUID,
        at point: CGPoint,
        horizontalTranslation: CGFloat,
        in timelineWidth: CGFloat
    ) -> DayTimelineBlockSnapshot? {
        guard horizontalTranslation > 34 else {
            return nil
        }

        return timelineBlockLayouts(in: timelineWidth)
            .filter { layout in
                layout.block.id != blockID &&
                layout.block.status == .planned &&
                !layout.block.isBuiltInStructuralItem &&
                layout.contentFrame.insetBy(dx: -6, dy: -8).contains(point)
            }
            .sorted { lhs, rhs in
                abs(lhs.contentFrame.midY - point.y) < abs(rhs.contentFrame.midY - point.y)
            }
            .first?
            .block
    }

    private func targetBlock(id: UUID) -> DayTimelineBlockSnapshot? {
        blocks.first(where: { $0.id == id })
    }

    private func shouldConnect(_ source: DateInterval, to target: DateInterval) -> Bool {
        let gapMinutes = target.start.timeIntervalSince(source.end) / 60
        return gapMinutes <= 30
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
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(Color.blue)

            Text(event.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)

            Text(event.sourceTitle)
                .font(.system(size: 11, weight: .medium, design: .rounded))
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
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.blue)

                Spacer(minLength: 0)

                Text(timeRangeText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Text(event.title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(2)

            if let location = event.location {
                Label(location, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            } else {
                Text(event.sourceTitle)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
            }
        }
        .padding(14)
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
    var attachmentTargetID: UUID?
}

private struct TimelineBlockLayout: Identifiable {
    let block: DayTimelineBlockSnapshot
    let displayedStartDate: Date
    let blockHeight: CGFloat
    let frame: CGRect
    let contentFrame: CGRect
    let nodeCenterX: CGFloat
    let showsTopConnector: Bool
    let showsBottomConnector: Bool

    var id: UUID { block.id }
}

private struct DayTimelineBlockCard: View {
    let block: DayTimelineBlockSnapshot
    let displayedStartDate: Date
    let blockHeight: CGFloat
    let contentWidth: CGFloat
    let conflictSummary: ScheduleBlockConflictSummary?
    let isChecklistExpanded: Bool
    let isDragging: Bool
    let showsTopConnector: Bool
    let showsBottomConnector: Bool
    let isAttachmentTarget: Bool
    let isAttachedPreview: Bool
    let onEdit: (() -> Void)?
    let onToggleCompletion: () -> Void
    let onToggleChecklistExpansion: (() -> Void)?
    let onToggleChecklistItem: (UUID) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var fillProgress: CGFloat = 0
    @State private var bounceScale: CGFloat = 1.0
    @State private var checkScale: CGFloat = 1.0
    @State private var glowOpacity: CGFloat = 0
    @State private var isAnimating = false

    private var isCompleted: Bool {
        block.status == .completed
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            structureLayer

            HStack(alignment: .top, spacing: usesCompactLayout ? 10 : 12) {
                Color.clear
                    .frame(width: usesCompactLayout ? 40 : 44)

                VStack(alignment: .leading, spacing: isChecklistExpanded && showsChecklistControls ? 12 : 8) {
                    header

                    if showsChecklistControls {
                        checklistSummaryButton
                    }

                    if visibleChecklistRowLimit > 0 {
                        expandedChecklist
                    }
                }
                .padding(.horizontal, usesCompactLayout ? 12 : 16)
                .padding(.vertical, usesCompactLayout ? 11 : 14)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(contentBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(contentBorderColor, lineWidth: conflictSummary == nil ? 1 : 1.25)
                }
                .shadow(
                    color: tintColor.opacity(isDragging ? 0.18 : 0.05),
                    radius: isDragging ? 18 : 10,
                    x: 0,
                    y: isDragging ? 10 : 4
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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

    private var usesCompactLayout: Bool {
        blockHeight < 84 || contentWidth < 188
    }

    private var usesDenseLayout: Bool {
        blockHeight < 76 || contentWidth < 144
    }

    private var usesNarrowLayout: Bool {
        contentWidth < 210
    }

    private var showsChecklistControls: Bool {
        !usesDenseLayout && !sortedChecklistItems.isEmpty && blockHeight >= 104 && contentWidth >= 176
    }

    private var visibleChecklistRowLimit: Int {
        guard isChecklistExpanded, showsChecklistControls else {
            return 0
        }

        let availableHeight = max(blockHeight - 88, 0)
        let fittedRows = Int(floor((availableHeight - 18) / 34))
        return max(0, min(sortedChecklistItems.count, min(fittedRows, 4)))
    }

    private var hiddenChecklistItemCount: Int {
        max(sortedChecklistItems.count - visibleChecklistRowLimit, 0)
    }

    private var hasPrimaryStatusPill: Bool {
        (conflictSummary != nil && !isDragging) || isAttachedPreview || isCompleted
    }

    private var hasSecondaryStatusPill: Bool {
        (!usesDenseLayout && !sortedChecklistItems.isEmpty && !isChecklistExpanded && !usesNarrowLayout) ||
        (block.isTemplateBacked && usesNarrowLayout)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: usesCompactLayout ? 8 : 10) {
            HStack(alignment: .top, spacing: usesCompactLayout ? 10 : 12) {
                if !usesDenseLayout {
                    categoryIcon
                }

                VStack(alignment: .leading, spacing: usesCompactLayout ? 3 : 4) {
                    Text(block.title)
                        .font(.system(size: usesDenseLayout ? 14 : (usesCompactLayout ? 15 : 17), weight: .bold, design: .rounded))
                        .foregroundStyle(isCompleted ? secondaryTextColor : primaryTextColor)
                        .strikethrough(isCompleted, color: secondaryTextColor)
                        .opacity(isCompleted ? 0.82 : 1)
                        .lineLimit(usesDenseLayout ? 1 : (usesCompactLayout ? 2 : 3))
                        .layoutPriority(1)

                    if !usesDenseLayout {
                        HStack(spacing: 6) {
                            if !usesNarrowLayout {
                                Text(block.category.title.uppercased())
                                    .font(.system(size: 10, weight: .black, design: .rounded))
                                    .kerning(0.9)
                                    .foregroundStyle(tintColor.opacity(0.8))
                            }

                            if block.isTemplateBacked && !usesNarrowLayout {
                                Label("Template", systemImage: "sparkles")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(isCompleted ? secondaryTextColor.opacity(0.82) : secondaryTextColor)
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: usesDenseLayout ? 4 : 8) {
                    if isDragging {
                        Text(displayedStartDate.formatted(date: .omitted, time: .shortened))
                            .font(.system(size: usesDenseLayout ? 11 : 12, weight: .black, design: .rounded))
                            .foregroundStyle(tintColor)
                            .padding(.horizontal, usesDenseLayout ? 8 : 10)
                            .padding(.vertical, usesDenseLayout ? 4 : 5)
                            .background(dragPillBackground)
                            .clipShape(Capsule())
                    }

                    completionButton
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            metadataSection
        }
    }

    private var metadataSection: some View {
        Group {
            if usesDenseLayout {
                HStack(spacing: 6) {
                    metadataTimeLabel

                    if hasPrimaryStatusPill && blockHeight >= 88 {
                        primaryStatusPill
                    }

                    Spacer(minLength: 0)
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        metadataTimeLabel
                        primaryStatusPill
                        secondaryStatusPill

                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        metadataTimeLabel

                        if hasPrimaryStatusPill || hasSecondaryStatusPill {
                            HStack(spacing: 6) {
                                primaryStatusPill
                                secondaryStatusPill
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
        }
    }

    private var metadataTimeLabel: some View {
        Text(timeRangeText)
            .font(.system(size: usesCompactLayout ? 12 : 13, weight: .semibold, design: .rounded))
            .foregroundStyle(secondaryTextColor)
            .lineLimit(1)
    }

    @ViewBuilder
    private var primaryStatusPill: some View {
        if let conflictSummary, !isDragging {
            infoPill(
                text: conflictSummary.badgeText,
                foreground: conflictAccentColor,
                background: conflictAccentColor.opacity(0.12)
            )
        } else if isAttachedPreview {
            infoPill(
                text: "Attaching",
                foreground: tintColor,
                background: tintColor.opacity(0.12)
            )
        } else if isCompleted {
            infoPill(
                text: "Done",
                foreground: .green,
                background: Color.green.opacity(0.12)
            )
        }
    }

    @ViewBuilder
    private var secondaryStatusPill: some View {
        if !usesDenseLayout && !sortedChecklistItems.isEmpty && !isChecklistExpanded && !usesNarrowLayout {
            infoPill(
                text: "\(checklistCompletionCount)/\(sortedChecklistItems.count)",
                foreground: secondaryTextColor,
                background: Color.primary.opacity(0.05)
            )
        } else if block.isTemplateBacked && usesNarrowLayout {
            infoPill(
                text: "Template",
                foreground: secondaryTextColor,
                background: Color.primary.opacity(0.05)
            )
        }
    }

    private var structureLayer: some View {
        ZStack(alignment: .topLeading) {
            let nodeSize = usesCompactLayout ? 28.0 : 34.0
            let nodeX = usesCompactLayout ? 12.0 : 10.0
            let nodeY = usesCompactLayout ? 12.0 : 16.0
            let lineX = nodeX + (nodeSize / 2) - 1

            if showsTopConnector {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(connectorColor.opacity(0.85))
                    .frame(width: 2, height: nodeY + 2)
                    .offset(x: lineX, y: 0)
            }

            if showsBottomConnector {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(connectorColor.opacity(0.78))
                    .frame(width: 2, height: max(blockHeight - (nodeY + nodeSize) + 8, 12))
                    .offset(x: lineX, y: nodeY + nodeSize - 4)
            }

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tintColor.opacity(0.16))
                .frame(width: 6, height: max(blockHeight - 8, 32))
                .offset(x: lineX - 2, y: 4)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            tintColor.opacity(isCompleted ? 0.92 : 1),
                            tintColor.opacity(colorScheme == .dark ? 0.75 : 0.88)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: nodeSize, height: nodeSize)
                .overlay {
                    Circle()
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.2 : 0.65), lineWidth: 1)
                }
                .overlay {
                    Image(systemName: iconSystemName)
                        .font(.system(size: usesCompactLayout ? 13 : 15, weight: .black))
                        .foregroundStyle(.white.opacity(0.98))
                }
                .shadow(color: tintColor.opacity(isDragging ? 0.35 : 0.18), radius: isDragging ? 14 : 7, x: 0, y: 4)
                .offset(x: nodeX, y: nodeY)

            if !usesDenseLayout {
                durationChip
                    .offset(x: 0, y: nodeY + nodeSize + 8)
            }
        }
    }

    private var categoryIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(tintColor.opacity(isCompleted ? 0.14 : 0.12))
                .frame(width: usesCompactLayout ? 24 : 28, height: usesCompactLayout ? 24 : 28)

            Image(systemName: iconSystemName)
                .font(.system(size: usesCompactLayout ? 12 : 14, weight: .bold))
                .foregroundStyle(isCompleted ? secondaryTextColor.opacity(0.7) : tintColor)
        }
    }

    private var completionButton: some View {
        Button(action: handleComplete) {
            ZStack {
                if isCompleted || fillProgress > 0.88 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: completionControlSize, weight: .black))
                        .foregroundColor(.green)
                } else {
                    Circle()
                        .stroke(
                            tintColor.opacity(0.32),
                            lineWidth: 1.6
                        )
                        .frame(width: completionControlSize, height: completionControlSize)
                        .overlay(
                            Image(systemName: "circle")
                                .font(.system(size: usesCompactLayout ? 13 : 14, weight: .black))
                                .foregroundStyle(tintColor.opacity(0.9))
                        )
                }
            }
            .scaleEffect(checkScale)
            .shadow(
                color: (isCompleted ? Color.green : tintColor).opacity(fillProgress > 0.88 || isCompleted ? 0.22 : 0.08),
                radius: fillProgress > 0.88 || isCompleted ? 12 : 4,
                x: 0,
                y: 4
            )
        }
        .buttonStyle(.plain)
        .disabled(isAnimating)
        .accessibilityLabel(block.status == .completed ? "Mark item as planned" : "Mark item as completed")
    }

    private var checklistSummaryButton: some View {
        Button(action: onToggleChecklistExpansion ?? {}) {
            HStack(spacing: 8) {
                Text("\(checklistCompletionCount)/\(sortedChecklistItems.count) checklist items")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                Spacer(minLength: 0)

                Image(systemName: isChecklistExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(secondaryTextColor)
            }
        }
        .buttonStyle(.plain)
        .disabled(onToggleChecklistExpansion == nil)
        .accessibilityLabel(isChecklistExpanded ? "Collapse checklist" : "Expand checklist")
    }

    private var expandedChecklist: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(sortedChecklistItems.prefix(visibleChecklistRowLimit)) { item in
                Button {
                    onToggleChecklistItem(item.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(item.isCompleted ? .green : secondaryTextColor)

                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
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

            if hiddenChecklistItemCount > 0 {
                Text("+\(hiddenChecklistItemCount) more in edit view")
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
                return Theme.primaryAccent
            }
        }

        switch block.category {
        case .focus:
            return Theme.primaryAccent
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

    private var contentBackground: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    isCompleted
                    ? (colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.025))
                    : (colorScheme == .light ? Color.white.opacity(0.95) : Color(white: 0.12).opacity(0.9))
                )

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tintColor.opacity(isAttachmentTarget ? 0.18 : 0.08),
                            tintColor.opacity(0.02),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            if fillProgress > 0 {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                tintColor.opacity(0.12),
                                tintColor.opacity(0.04),
                                Color.green.opacity(0.06)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
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

        withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
            bounceScale = 1.02
            checkScale = 1.16
            glowOpacity = 1
        }
        withAnimation(.easeInOut(duration: 0.42)) {
            fillProgress = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) {
                bounceScale = 1.0
                checkScale = 1.0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.52) {
            onToggleCompletion()
            isAnimating = false
            fillProgress = 0
            glowOpacity = 0
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
            return Color.white.opacity(0.46)
        }

        if conflictSummary != nil {
            return conflictAccentColor.opacity(0.52)
        }

        if isCompleted {
            return Color.primary.opacity(colorScheme == .dark ? 0.1 : 0.06)
        }

        return tintColor.opacity(colorScheme == .dark ? 0.2 : 0.14)
    }

    private var contentBorderColor: Color {
        if isAttachmentTarget {
            return tintColor.opacity(0.54)
        }

        return borderColor
    }

    private var connectorColor: Color {
        isAttachmentTarget ? tintColor : tintColor.opacity(colorScheme == .dark ? 0.68 : 0.5)
    }

    private var completionControlSize: CGFloat {
        if usesDenseLayout {
            return 28
        }

        return usesCompactLayout ? 32 : 38
    }

    private var durationBadgeText: String {
        let minutes = max(Int(round(block.endDate.timeIntervalSince(block.startDate) / 60)), 15)
        if minutes < 60 {
            return "\(minutes)m"
        }

        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return "\(hours)h"
        }

        return "\(hours)h\n\(remainder)m"
    }

    private var durationChip: some View {
        Text(durationBadgeText)
            .font(.system(size: usesCompactLayout ? 9 : 10, weight: .black, design: .rounded))
            .foregroundStyle(tintColor.opacity(isCompleted ? 0.84 : 0.94))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(tintColor.opacity(colorScheme == .dark ? 0.2 : 0.1))
            )
    }

    private var dragPillBackground: some View {
        Group {
            if colorScheme == .light {
                Color.white.opacity(0.96)
            } else {
                Color.black.opacity(0.22)
            }
        }
    }

    private func infoPill(text: String, foreground: Color, background: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(background)
            )
    }
}
