import SwiftData
import SwiftUI

struct ScheduleView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimeBlock.startDate) private var blocks: [TimeBlock]
    @Query private var preferences: [AppPreferences]
    @AppStorage("schedule.hasSeenBlockMoveHint") private var hasSeenBlockMoveHint = false
    @State private var editingBlock: TimeBlock?
    @State private var isRegenerating = false
    @State private var regenerateErrorMessage: String?
    @State private var dragErrorMessage: String?
    @State private var timelineErrorMessage: String?
    @State private var activeDrag: ScheduleBlockDragSession?
    @State private var moveTargetFrames: [Date: CGRect] = [:]
    @State private var feedbackBanner: ScheduleFeedbackBannerState?

    private let dragCoordinateSpaceName = "schedule-drag-surface"

    private var firstWeekday: Int {
        preferences.first?.firstWeekday.rawValue ?? Weekday.monday.rawValue
    }

    private var showsCompletedBlocks: Bool {
        preferences.first?.showsCompletedBlocks ?? true
    }

    private var dayStartHour: Int {
        preferences.first?.dayStartHour ?? 6
    }

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    private var selectedDate: Binding<Date> {
        Binding(
            get: { appEnvironment.appState.selectedDate },
            set: { appEnvironment.appState.selectedDate = $0 }
        )
    }

    private var daySnapshot: ScheduleDaySnapshot {
        appEnvironment.scheduleRepository.daySnapshot(
            for: appEnvironment.appState.selectedDate,
            from: blocks,
            includeCompleted: showsCompletedBlocks
        )
    }

    private var upcomingBlocks: [TimeBlock] {
        appEnvironment.scheduleRepository.upcomingBlocks(from: blocks)
    }

    private var moveTargetDates: [Date] {
        let baseDay = calendar.startOfDay(for: appEnvironment.appState.selectedDate)
        return (-2...2).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: baseDay).map(calendar.startOfDay(for:))
        }
    }

    private var activeDragBlock: TimeBlock? {
        guard let blockID = activeDrag?.blockID else {
            return nil
        }

        return blocks.first { $0.id == blockID }
    }

    private var shouldShowMoveHint: Bool {
        !hasSeenBlockMoveHint && activeDrag == nil && feedbackBanner == nil && !daySnapshot.blocks.isEmpty
    }

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    DateStripHeaderView(
                        selectedDate: selectedDate,
                        firstWeekday: firstWeekday,
                        dateHasItems: blocksExist(on:)
                    )
                    .padding(.top, 64) // Offset for custom header

                    if let activeDragBlock {
                        DayMoveRibbon(
                            targetDates: moveTargetDates,
                            selectedDate: calendar.startOfDay(for: appEnvironment.appState.selectedDate),
                            hoveredDate: activeDrag?.hoveredDate,
                            coordinateSpaceName: dragCoordinateSpaceName,
                            detachNotice: activeDragBlock.template != nil,
                            preservedTimeText: activeDragBlock.startDate.formatted(date: .omitted, time: .shortened)
                        )
                        .onPreferenceChange(DayMoveTargetFramePreferenceKey.self) { moveTargetFrames = $0 }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.paddingMedium) {
                        TimeMetricTile(title: "Planned", value: "\(daySnapshot.plannedCount)", systemImage: "calendar.badge.clock")
                        TimeMetricTile(title: "Completed", value: "\(daySnapshot.completedCount)", systemImage: "checkmark.circle")
                        TimeMetricTile(title: "Scheduled", value: "\(daySnapshot.scheduledMinutes) min", systemImage: "timer")
                        TimeMetricTile(title: "Templates", value: upcomingBlocks.isEmpty ? "Ready" : "\(upcomingBlocks.count) next", systemImage: "square.on.square")
                    }

                    TimeCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(alignment: .top, spacing: 12) {
                                TimeSectionHeader("Today's Plan", subtitle: "Timeline and block list for the selected day")

                                Button {
                                    regenerateSelectedDay()
                                } label: {
                                    Label(isRegenerating ? "Refreshing..." : "Regenerate", systemImage: "arrow.clockwise")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.primaryPurple)
                                .controlSize(.small)
                                .disabled(isRegenerating || activeDrag != nil)
                            }

                            Text(activeDrag == nil ? "Drag blocks on the timeline to retime the day, or use Move in the list to send a block to another day. Timeline drags snap to 15 minutes." : "Drag using the Move handle to send a block to a nearby day. The block keeps its start time and duration.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)

                            if shouldShowMoveHint {
                                MoveHintCallout()
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            if let feedbackBanner {
                                ScheduleFeedbackBanner(state: feedbackBanner)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }

                            if let regenerateErrorMessage {
                                Text(regenerateErrorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }

                            if let dragErrorMessage {
                                Text(dragErrorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }

                            if let timelineErrorMessage {
                                Text(timelineErrorMessage)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                            }

                            Divider()

                            if daySnapshot.blocks.isEmpty {
                                ContentUnavailableView(
                                    "No Time Blocks",
                                    systemImage: "calendar.badge.exclamationmark",
                                    description: Text("This day is ready for planning. Time blocks, checklist items, and routine generation can build here next.")
                                )
                                .padding(.vertical, 20)
                            } else {
                                DayTimelineView(
                                    date: appEnvironment.appState.selectedDate,
                                    blocks: daySnapshot.blocks,
                                    dayStartHour: dayStartHour,
                                    calendar: calendar,
                                    onEdit: { block in
                                        editingBlock = block
                                    },
                                    onMoveBlock: { block, startDate in
                                        rescheduleBlock(block, to: startDate)
                                    }
                                )

                                Divider()

                                VStack(spacing: 0) {
                                    ForEach(daySnapshot.blocks) { block in
                                        TimeBlockRowView(
                                            block: block,
                                            onEdit: {
                                                editingBlock = block
                                            },
                                            dragCoordinateSpaceName: dragCoordinateSpaceName,
                                            isDragging: activeDrag?.blockID == block.id,
                                            emphasizesDragAffordance: shouldShowMoveHint,
                                            onDragBegan: { location in
                                                startDrag(for: block, at: location)
                                            },
                                            onDragChanged: { location in
                                                updateDragLocation(location)
                                            },
                                            onDragEnded: { location in
                                                finishDrag(for: block, at: location)
                                            }
                                        )

                                        if block.id != daySnapshot.blocks.last?.id {
                                            Divider().padding(.vertical, 12)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if !upcomingBlocks.isEmpty {
                        TimeCard {
                            VStack(alignment: .leading, spacing: 16) {
                                TimeSectionHeader("Upcoming", subtitle: "Next planned blocks across the schedule")

                                ForEach(upcomingBlocks) { block in
                                    TimeBlockRowView(block: block) {
                                        editingBlock = block
                                    }

                                    if block.id != upcomingBlocks.last?.id {
                                        Divider().padding(.vertical, 12)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
                .padding(.bottom, 100)
            }
        }
        .coordinateSpace(name: dragCoordinateSpaceName)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: activeDrag?.hoveredDate)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: activeDrag?.blockID)
        .overlay {
            GeometryReader { proxy in
                if let activeDrag, let activeDragBlock {
                    TimeBlockDragPreviewView(
                        block: activeDragBlock,
                        destinationDate: activeDrag.hoveredDate
                    )
                    .position(previewPosition(in: proxy.size, for: activeDrag.location))
                    .allowsHitTesting(false)
                    .transition(.scale(scale: 0.94).combined(with: .opacity))
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { appEnvironment.appState.isPresentingAddModal },
            set: { appEnvironment.appState.isPresentingAddModal = $0 }
        )) {
            AddTimeBlockView(
                selectedDate: appEnvironment.appState.selectedDate,
                onSave: { savedDate in
                    appEnvironment.appState.selectedDate = savedDate
                }
            )
        }
        .sheet(item: $editingBlock) { block in
            AddTimeBlockView(
                selectedDate: block.startDate,
                block: block,
                onSave: { savedDate in
                    appEnvironment.appState.selectedDate = savedDate
                },
                onDelete: { deletedDate in
                    if Calendar.current.isDate(appEnvironment.appState.selectedDate, inSameDayAs: deletedDate) {
                        return
                    }

                    appEnvironment.appState.selectedDate = deletedDate
                }
            )
        }
        .task(id: appEnvironment.appState.selectedDate) {
            appEnvironment.generateScheduleIfNeeded(
                for: appEnvironment.appState.selectedDate,
                using: modelContext
            )
        }
    }

    private func blocksExist(on date: Date) -> Bool {
        appEnvironment.scheduleRepository.hasBlocks(on: date, in: blocks)
    }

    private func regenerateSelectedDay() {
        isRegenerating = true
        regenerateErrorMessage = nil

        do {
            try appEnvironment.scheduleRepository.regenerateTemplateBlocks(
                for: appEnvironment.appState.selectedDate,
                in: modelContext
            )
        } catch {
            regenerateErrorMessage = "Unable to regenerate this day right now."
            assertionFailure("Failed to regenerate schedule blocks: \(error)")
        }

        isRegenerating = false
    }

    private func startDrag(for block: TimeBlock, at location: CGPoint) {
        dragErrorMessage = nil
        moveTargetFrames = [:]
        hasSeenBlockMoveHint = true

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            activeDrag = ScheduleBlockDragSession(
                blockID: block.id,
                location: location,
                hoveredDate: nil
            )
        }
    }

    private func updateDragLocation(_ location: CGPoint) {
        guard activeDrag != nil else {
            return
        }

        activeDrag?.location = location
        activeDrag?.hoveredDate = hoveredDate(for: location)
    }

    private func finishDrag(for block: TimeBlock, at location: CGPoint) {
        guard activeDrag?.blockID == block.id else {
            return
        }

        updateDragLocation(location)
        let hoveredDate = activeDrag?.hoveredDate
        clearActiveDrag()

        guard let hoveredDate else {
            return
        }

        guard !calendar.isDate(block.startDate, inSameDayAs: hoveredDate) else {
            return
        }

        dragErrorMessage = nil

        do {
            try appEnvironment.scheduleRepository.moveBlock(
                block,
                toDay: hoveredDate,
                in: modelContext,
                calendar: calendar
            )
            showFeedback(
                title: "Block moved",
                message: "\"\(block.title)\" is now on \(hoveredDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).",
                systemImage: "checkmark.circle.fill",
                tint: .green
            )
            appEnvironment.appState.selectedDate = hoveredDate
        } catch {
            dragErrorMessage = "Unable to move this block right now."
            assertionFailure("Failed to move schedule block: \(error)")
        }
    }

    private func rescheduleBlock(_ block: TimeBlock, to startDate: Date) {
        timelineErrorMessage = nil

        do {
            try appEnvironment.scheduleRepository.rescheduleBlock(
                block,
                toStartDate: startDate,
                in: modelContext,
                calendar: calendar
            )
            showFeedback(
                title: "Time updated",
                message: "\"\(block.title)\" now starts at \(startDate.formatted(date: .omitted, time: .shortened)).",
                systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                tint: Theme.primaryPurple
            )
        } catch {
            timelineErrorMessage = "Unable to update this block's time right now."
            assertionFailure("Failed to reschedule block on timeline: \(error)")
        }
    }

    private func clearActiveDrag() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            activeDrag = nil
        }
        moveTargetFrames = [:]
    }

    private func hoveredDate(for location: CGPoint) -> Date? {
        moveTargetDates.first { date in
            moveTargetFrames[date]?.contains(location) == true
        }
    }

    private func previewPosition(in size: CGSize, for location: CGPoint) -> CGPoint {
        let previewWidth: CGFloat = 280
        let previewHeight: CGFloat = 126
        let minX = (previewWidth / 2) + 12
        let maxX = max(minX, size.width - (previewWidth / 2) - 12)
        let minY = (previewHeight / 2) + 12
        let maxY = max(minY, size.height - (previewHeight / 2) - 12)

        return CGPoint(
            x: min(max(location.x + 84, minX), maxX),
            y: min(max(location.y - 56, minY), maxY)
        )
    }

    private func showFeedback(
        title: String,
        message: String,
        systemImage: String,
        tint: Color
    ) {
        let state = ScheduleFeedbackBannerState(
            id: UUID(),
            title: title,
            message: message,
            systemImage: systemImage,
            tint: tint
        )

        withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) {
            feedbackBanner = state
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.2))

            guard feedbackBanner?.id == state.id else {
                return
            }

            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                feedbackBanner = nil
            }
        }
    }
}

private struct ScheduleBlockDragSession {
    let blockID: UUID
    var location: CGPoint
    var hoveredDate: Date?
}

private struct ScheduleFeedbackBannerState: Identifiable {
    let id: UUID
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
}

private struct DayMoveRibbon: View {
    let targetDates: [Date]
    let selectedDate: Date
    let hoveredDate: Date?
    let coordinateSpaceName: String
    let detachNotice: Bool
    let preservedTimeText: String

    var body: some View {
        TimeCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .center, spacing: 10) {
                    Label("Move Block", systemImage: "hand.draw.fill")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Spacer(minLength: 0)

                    Text("Drop on a day")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryPurple)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.primaryPurple.opacity(0.12))
                        .clipShape(Capsule())
                }

                Text(ribbonMessage)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(targetDates, id: \.self) { date in
                            DayMoveTargetChip(
                                date: date,
                                isSelectedDay: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                isHovered: hoveredDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false,
                                coordinateSpaceName: coordinateSpaceName
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }

    private var ribbonMessage: String {
        if let hoveredDate {
            let hoveredLabel = hoveredDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
            let detachmentNote = detachNotice ? " It will become a manual block." : ""
            return "Release to move this block to \(hoveredLabel) at \(preservedTimeText).\(detachmentNote)"
        }

        if detachNotice {
            return "Drop on a nearby day to keep the \(preservedTimeText) start. Moving a generated block makes it manual."
        }

        return "Drop on a nearby day to keep the \(preservedTimeText) start and current duration."
    }
}

private struct DayMoveTargetChip: View {
    let date: Date
    let isSelectedDay: Bool
    let isHovered: Bool
    let coordinateSpaceName: String

    var body: some View {
        VStack(spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(isHovered ? .white.opacity(0.84) : Theme.secondaryText)

            Text(date.formatted(.dateTime.day()))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(isHovered ? .white : Theme.primaryText)

            Text(footerText)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(isHovered ? .white.opacity(0.84) : Theme.secondaryText)
        }
        .frame(width: 78)
        .padding(.vertical, 14)
        .background(backgroundShape)
        .overlay(alignment: .topTrailing) {
            if isSelectedDay {
                Circle()
                    .fill(isHovered ? Color.white.opacity(0.9) : Theme.primaryPurple)
                    .frame(width: 8, height: 8)
                    .padding(10)
            }
        }
        .scaleEffect(isHovered ? 1.06 : 1)
        .shadow(
            color: isHovered ? Theme.primaryPurple.opacity(0.22) : .clear,
            radius: 14,
            x: 0,
            y: 10
        )
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: DayMoveTargetFramePreferenceKey.self,
                    value: [date: proxy.frame(in: .named(coordinateSpaceName))]
                )
            }
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isHovered)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(
                isHovered
                    ? AnyShapeStyle(Theme.primaryGradient)
                    : AnyShapeStyle(Theme.primaryPurple.opacity(isSelectedDay ? 0.12 : 0.06))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(
                        isHovered ? Color.white.opacity(0.22) : Theme.primaryPurple.opacity(isSelectedDay ? 0.18 : 0.1),
                        lineWidth: 1
                    )
            }
    }

    private var footerText: String {
        if isHovered {
            return "Drop Here"
        }

        if isSelectedDay {
            return "Current"
        }

        return date.formatted(.dateTime.month(.abbreviated))
    }
}

private struct DayMoveTargetFramePreferenceKey: PreferenceKey {
    static var defaultValue: [Date: CGRect] = [:]

    static func reduce(value: inout [Date: CGRect], nextValue: () -> [Date: CGRect]) {
        value.merge(nextValue()) { _, next in next }
    }
}

private struct MoveHintCallout: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "hand.draw")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Theme.primaryPurple)
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Theme.primaryPurple.opacity(0.12))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Move blocks directly")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Text("Drag a block on the timeline to retime it, or use the Move handle in the list to send it to another nearby day.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.primaryPurple.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.primaryPurple.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct ScheduleFeedbackBanner: View {
    let state: ScheduleFeedbackBannerState

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: state.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(state.tint))

            VStack(alignment: .leading, spacing: 2) {
                Text(state.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)

                Text(state.message)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(state.tint.opacity(0.1))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(state.tint.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct DayTimelineView: View {
    let date: Date
    let blocks: [TimeBlock]
    let dayStartHour: Int
    let calendar: Calendar
    let onEdit: (TimeBlock) -> Void
    let onMoveBlock: (TimeBlock, Date) -> Void

    @State private var dragSession: TimelineBlockDragSession?

    private let hourHeight: CGFloat = 76
    private let labelColumnWidth: CGFloat = 58
    private let snapMinutes = 15
    private let minimumBlockHeight: CGFloat = 54

    private var timelineBounds: TimelineBounds {
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let earliestHour = blocks.map { calendar.component(.hour, from: $0.startDate) }.min() ?? dayStartHour
        let latestEndDate = blocks.map(\.endDate).max() ?? calendar.date(byAdding: .hour, value: 10, to: startOfDay) ?? startOfDay
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

            Text("Drag a block vertically to reschedule it within the selected day. Duration stays fixed.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Theme.primaryPurple.opacity(0.05))

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
                    .padding(.horizontal, 14)
                    .padding(.vertical, 18)

                    ForEach(blocks) { block in
                        let blockWidth = max(proxy.size.width - labelColumnWidth - 40, 150)
                        DayTimelineBlockCard(
                            block: block,
                            displayedStartDate: displayedStartDate(for: block),
                            isDragging: dragSession?.blockID == block.id
                        )
                        .frame(width: blockWidth, height: blockHeight(for: block))
                        .position(
                            x: labelColumnWidth + 24 + (blockWidth / 2),
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
    let isDragging: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(block.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Spacer(minLength: 0)

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
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
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
}
