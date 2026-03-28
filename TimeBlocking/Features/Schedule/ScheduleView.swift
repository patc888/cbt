import SwiftData
import SwiftUI

struct ScheduleView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \TimeBlock.startDate) private var blocks: [TimeBlock]
    @Query(sort: \ScheduleTemplate.sortOrder) private var templates: [ScheduleTemplate]
    @Query private var preferences: [AppPreferences]
    @AppStorage("schedule.hasSeenBlockMoveHint") private var hasSeenBlockMoveHint = false
    @State private var editorRoute: ScheduleEditorRoute?
    @State private var isRegenerating = false
    @State private var regenerateErrorMessage: String?
    @State private var dragErrorMessage: String?
    @State private var timelineErrorMessage: String?
    @State private var activeDrag: ScheduleBlockDragSession?
    @State private var moveTargetFrames: [Date: CGRect] = [:]
    @State private var feedbackBanner: ScheduleFeedbackBannerState?
    @State private var isShowingPlanningGuidance = false
    @State private var expandedChecklistBlockIDs: Set<UUID> = []
    @State private var recentlyCompletedBlockIDs: Set<UUID> = []
    @State private var completedBuiltInTimelineItemsByDay: [Date: Set<DayTimelineBuiltInItemKind>] = [:]
    @State private var overviewLayer: ScheduleOverviewLayer = .collapsed
    @State private var topPullDistance: CGFloat = 0


    private let dragCoordinateSpaceName = "schedule-drag-surface"
    private let scrollCoordinateSpaceName = "schedule-scroll"
    private let weeklyRevealThreshold: CGFloat = 56

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

    private var dayCalendarEvents: [TimeCalendarEvent] {
        appEnvironment.timeCalendarManager.events(
            on: appEnvironment.appState.selectedDate,
            calendar: calendar
        )
    }

    private var selectedDayOverlappingBlockIDs: Set<UUID> {
        appEnvironment.scheduleRepository.overlappingPlannedBlockIDs(
            on: appEnvironment.appState.selectedDate,
            from: blocks,
            calendar: calendar
        )
    }

    private var resolveConflictsAction: (() -> Void)? {
        selectedDayPlanningGuidance.hasOverlappingBlocks ? { resolveSelectedDayConflicts() } : nil
    }

    private var selectedDayPlanningGuidance: SchedulePlanningGuidanceSnapshot {
        SchedulePlanningGuidanceSnapshot.build(
            for: appEnvironment.appState.selectedDate,
            blocks: daySnapshot.blocks,
            overlappingBlockIDs: selectedDayOverlappingBlockIDs,
            calendarEvents: dayCalendarEvents,
            dayStartHour: dayStartHour,
            calendar: calendar
        )
    }

    private var daySnapshot: ScheduleDaySnapshot {
        let baseSnapshot = appEnvironment.scheduleRepository.daySnapshot(
            for: appEnvironment.appState.selectedDate,
            from: blocks,
            includeCompleted: showsCompletedBlocks,
            calendar: calendar
        )
        
        if showsCompletedBlocks {
            return baseSnapshot
        }
        
        let allSnapshot = appEnvironment.scheduleRepository.daySnapshot(
            for: appEnvironment.appState.selectedDate,
            from: blocks,
            includeCompleted: true,
            calendar: calendar
        )
        
        let visibleBlocks = allSnapshot.blocks.filter { block in
            block.status != .completed || recentlyCompletedBlockIDs.contains(block.id)
        }
        
        return ScheduleDaySnapshot(
            blocks: visibleBlocks,
            completedCount: baseSnapshot.completedCount,
            plannedCount: baseSnapshot.plannedCount,
            scheduledMinutes: baseSnapshot.scheduledMinutes
        )
    }

    @MainActor
    private var dayTimelineBlocks: [DayTimelineBlockSnapshot] {
        daySnapshot.blocks.map(DayTimelineBlockSnapshot.init)
    }

    @MainActor
    private var dayTimelineStructuralItems: [DayTimelineBlockSnapshot] {
        let selectedDay = calendar.startOfDay(for: appEnvironment.appState.selectedDate)
        let completedItems = completedBuiltInTimelineItemsByDay[selectedDay] ?? []
        let wakeUpStart = calendar.date(bySettingHour: dayStartHour, minute: 0, second: 0, of: selectedDay) ?? selectedDay
        let wakeUpEnd = wakeUpStart.addingTimeInterval(15 * 60)
        let sleepStart = calendar.date(byAdding: .day, value: 1, to: selectedDay) ?? selectedDay
        let sleepEnd = sleepStart.addingTimeInterval(15 * 60)

        return [
            DayTimelineBlockSnapshot(
                builtInKind: .wakeUp,
                startDate: wakeUpStart,
                endDate: wakeUpEnd,
                status: completedItems.contains(.wakeUp) ? .completed : .planned
            ),
            DayTimelineBlockSnapshot(
                builtInKind: .sleep,
                startDate: sleepStart,
                endDate: sleepEnd,
                status: completedItems.contains(.sleep) ? .completed : .planned
            )
        ]
    }

    private var hasTemplates: Bool {
        !templates.isEmpty
    }

    private var canRegenerateSelectedDay: Bool {
        !isRegenerating && activeDrag == nil
    }

    private var hasApplicableTemplatesForSelectedDay: Bool {
        let weekday = calendar.component(.weekday, from: appEnvironment.appState.selectedDate)
        let weekdayBit = 1 << (weekday - 1)
        return templates.contains { template in
            template.weekdayMask & weekdayBit != 0
        }
    }

    private var selectedDayBestWindow: ScheduleFreeTimeWindow? {
        guard showsSelectedDayContent else {
            return nil
        }

        return selectedDayPlanningGuidance.bestWindow
    }

    private var hasDetailedSelectedDayGuidance: Bool {
        selectedDayPlanningGuidance.hasOverlappingBlocks ||
        selectedDayPlanningGuidance.hasConflicts ||
        selectedDayPlanningGuidance.hasOpenWindows ||
        selectedDayPlanningGuidance.allDayEventCount > 0
    }

    private var shouldShowSelectedDayUtilityRow: Bool {
        hasApplicableTemplatesForSelectedDay ||
        hasDetailedSelectedDayGuidance ||
        selectedDayPlanningGuidance.hasOverlappingBlocks ||
        selectedDayBestWindow != nil
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

    private var contentHorizontalPadding: CGFloat {
        horizontalSizeClass == .compact ? 16 : 24
    }

    private var weekStripDates: [Date] {
        let today = calendar.startOfDay(for: .now)
        return (-180...180).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: today).map(calendar.startOfDay(for:))
        }
    }


    private var selectedMonthStart: Date {
        ScheduleMonthSupport.startOfMonth(for: appEnvironment.appState.selectedDate, calendar: calendar)
    }

    private var selectedMonthDates: [Date] {
        ScheduleMonthSupport.gridDates(for: appEnvironment.appState.selectedDate, calendar: calendar)
    }

    private var selectedMonthDays: [MonthlyPlanningDay] {
        selectedMonthDates.map { date in
            MonthlyPlanningDay(
                date: date,
                snapshot: appEnvironment.scheduleRepository.daySnapshot(
                    for: date,
                    from: blocks,
                    includeCompleted: true,
                    calendar: calendar
                ),
                isInDisplayedMonth: calendar.isDate(date, equalTo: selectedMonthStart, toGranularity: .month)
            )
        }
    }

    private var selectedMonthSummary: ScheduleMonthSummary {
        ScheduleMonthSummary(days: selectedMonthDays, calendar: calendar)
    }

    private var visibleGenerationDates: [Date] {
        return [calendar.startOfDay(for: appEnvironment.appState.selectedDate)]
    }


    private var visibleCalendarInterval: DateInterval? {
        if overviewLayer == .month {
            return nil
        }

        if weeklyRevealProgress > 0.01 {
            return calendar.dateInterval(of: .weekOfYear, for: appEnvironment.appState.selectedDate)
        }

        let start = calendar.startOfDay(for: appEnvironment.appState.selectedDate)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return DateInterval(start: start, end: end)
    }

    private var weeklyRevealProgress: CGFloat {
        overviewLayer == .week ? 1 : 0
    }

    private var isWeekExpanded: Bool {
        overviewLayer == .week
    }


    private var showsSelectedDayContent: Bool {
        !daySnapshot.blocks.isEmpty || !dayCalendarEvents.isEmpty
    }

    private var calendarLoadTrigger: String {
        guard let visibleCalendarInterval else {
            return "month"
        }

        return [
            String(describing: overviewLayer),
            String(visibleCalendarInterval.start.timeIntervalSinceReferenceDate),
            String(visibleCalendarInterval.end.timeIntervalSinceReferenceDate),
            appEnvironment.timeCalendarManager.accessState.rawValue
        ].joined(separator: "|")
    }

    var body: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            contentView
        }
        .coordinateSpace(name: dragCoordinateSpaceName)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: activeDrag?.hoveredDate)
        .animation(.spring(response: 0.32, dampingFraction: 0.84), value: activeDrag?.blockID)
        .overlay {
            activeDragOverlay
        }
        .sheet(item: $editorRoute) { route in
            AddTimeBlockView(
                selectedDate: route.draft.selectedDate,
                editingBlockID: route.editingBlockID,
                entryMode: route.entryMode,
                initialDraft: route.draft,
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

        .sheet(isPresented: $isShowingPlanningGuidance) {
            planningGuidanceSheet
        }
        .task(id: visibleGenerationDates) {
            for date in visibleGenerationDates {
                appEnvironment.generateScheduleIfNeeded(
                    for: date,
                    using: modelContext
                )
            }
        }
        .task(id: calendarLoadTrigger) {
            await refreshVisibleCalendarEvents()
        }
        .onChange(of: scenePhase) { _, newValue in
            guard newValue == .active else {
                return
            }

            Task {
                await refreshVisibleCalendarEvents(forceRefresh: true)
            }
        }
        .onChange(of: appEnvironment.appState.selectedDate) { _, _ in
            clearActiveDrag()
            dragErrorMessage = nil
            timelineErrorMessage = nil
            recentlyCompletedBlockIDs.removeAll()
        }
        .onChange(of: appEnvironment.appState.isPresentingAddModal) { _, isPresenting in
            guard isPresenting else {
                return
            }

            presentNewBlockEditor(for: appEnvironment.appState.selectedDate)
            appEnvironment.appState.isPresentingAddModal = false
        }
        .onChange(of: dayTimelineBlocks.map(\.id)) { _, blockIDs in
            expandedChecklistBlockIDs = expandedChecklistBlockIDs.filter { blockIDs.contains($0) }

            guard let activeDrag, !blockIDs.contains(activeDrag.blockID) else {
                return
            }

            clearActiveDrag()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)
                
                VStack(spacing: 16) {
                    dateHeader
                    
                    VStack(spacing: 16) {
                        selectedDayUtilityRow
                        moveRibbon
                        if shouldShowMoveHint {
                            MoveHintCallout()
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        sharedScheduleMessages
                        calendarIntegrationStatus
                        calendarLoadingStatus
                        selectedDayContent
                    }
                    .padding(.horizontal, contentHorizontalPadding)
                }
            }
            .padding(.bottom, 120)
            .background(alignment: .top) {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ScheduleScrollOffsetPreferenceKey.self,
                            value: proxy.frame(in: .named(scrollCoordinateSpaceName)).minY
                        )
                }
            }
        }
        .coordinateSpace(name: scrollCoordinateSpaceName)
        .onPreferenceChange(ScheduleScrollOffsetPreferenceKey.self) { offset in
            topPullDistance = max(offset, 0)
        }

    }

    private var dateHeader: some View {
        TimeHeaderView(
            selectedDate: selectedDate,
            weekStripDates: weekStripDates,
            calendar: calendar,
            horizontalPadding: contentHorizontalPadding,
            dateHasItems: { date in
                appEnvironment.scheduleRepository.hasBlocks(on: date, in: blocks, calendar: calendar) ||
                appEnvironment.timeCalendarManager.summary(for: date, calendar: calendar).hasEvents
            }
        )
        .padding(.top, 8)
    }

    @ViewBuilder
    private var moveRibbon: some View {
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
    }

    private func toggleChecklistExpansion(for blockID: UUID) {
        guard dayTimelineBlocks.contains(where: { $0.id == blockID && !$0.checklistItems.isEmpty }) else {
            expandedChecklistBlockIDs.remove(blockID)
            return
        }

        if expandedChecklistBlockIDs.contains(blockID) {
            expandedChecklistBlockIDs.remove(blockID)
        } else {
            expandedChecklistBlockIDs.insert(blockID)
        }
    }

    private func toggleChecklistItem(for blockID: UUID, itemID: UUID) {
        guard let block = fetchBlock(id: blockID),
              let item = (block.checklistItems ?? []).first(where: { $0.id == itemID }) else {
            expandedChecklistBlockIDs.remove(blockID)
            return
        }

        item.isCompleted.toggle()
        item.updatedAt = .now
        block.updatedAt = .now

        do {
            try modelContext.save()
        } catch {
            assertionFailure("Failed to update checklist item from day timeline: \(error)")
        }
    }

    private func toggleCompletion(for blockID: UUID) {
        timelineErrorMessage = nil

        guard let block = fetchBlock(id: blockID) else {
            expandedChecklistBlockIDs.remove(blockID)
            timelineErrorMessage = "This time block is no longer available."
            return
        }

        let nextStatus: TimeBlockStatus
        switch block.status {
        case .planned:
            nextStatus = .completed
            recentlyCompletedBlockIDs.insert(blockID)
        case .completed, .cancelled:
            nextStatus = .planned
            recentlyCompletedBlockIDs.remove(blockID)
        }

        do {
            try appEnvironment.scheduleRepository.setBlockStatus(
                block,
                to: nextStatus,
                in: modelContext
            )
            Task {
                await appEnvironment.syncReminder(for: block, using: modelContext)
            }
        } catch {
            timelineErrorMessage = "Unable to update this block right now."
            assertionFailure("Failed to update block completion from day timeline: \(error)")
        }
    }

    private func toggleBuiltInTimelineItemCompletion(_ itemKind: DayTimelineBuiltInItemKind) {
        let selectedDay = calendar.startOfDay(for: appEnvironment.appState.selectedDate)
        var completedItems = completedBuiltInTimelineItemsByDay[selectedDay] ?? []

        if completedItems.contains(itemKind) {
            completedItems.remove(itemKind)
        } else {
            completedItems.insert(itemKind)
        }

        completedBuiltInTimelineItemsByDay[selectedDay] = completedItems
    }

    @ViewBuilder
    private var selectedDayUtilityRow: some View {
        if shouldShowSelectedDayUtilityRow {
            HStack(spacing: 8) {
                if selectedDayPlanningGuidance.hasOverlappingBlocks, let resolveConflictsAction {
                    Button("Resolve Conflicts", action: resolveConflictsAction)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.primaryPurple)
                        .controlSize(.small)
                }

                if hasApplicableTemplatesForSelectedDay || hasDetailedSelectedDayGuidance || selectedDayBestWindow != nil {
                    Menu {
                        if hasApplicableTemplatesForSelectedDay {
                            Button(isRegenerating ? "Regenerating..." : "Regenerate Day", systemImage: "arrow.clockwise") {
                                regenerateSelectedDay()
                            }
                            .disabled(!canRegenerateSelectedDay)
                        }

                        if hasDetailedSelectedDayGuidance {
                            Button("Planning Guidance", systemImage: "clock.badge.magnifyingglass") {
                                isShowingPlanningGuidance = true
                            }
                        }

                        if let bestWindow = selectedDayBestWindow {
                            Label("Best Slot: \(durationText(for: bestWindow.durationMinutes))", systemImage: "sparkles")
                        }
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.primaryPurple)
                    .controlSize(.small)
                }
            }
        }
    }

    private var planningGuidanceSheet: some View {
        NavigationStack {
            ScrollView {
                SchedulePlanningGuidanceView(
                    snapshot: selectedDayPlanningGuidance,
                    onResolveConflicts: resolveConflictsAction
                )
                .padding()
            }
            .navigationTitle("Planning Guidance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        isShowingPlanningGuidance = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private var selectedDayContent: some View {
        DayTimelineView(
            date: appEnvironment.appState.selectedDate,
            blocks: dayTimelineBlocks,
            structuralItems: dayTimelineStructuralItems,
            calendarEvents: dayCalendarEvents,
            blockConflictsByID: selectedDayPlanningGuidance.blockConflictsByID,
            expandedChecklistBlockIDs: expandedChecklistBlockIDs,
            dayStartHour: dayStartHour,
            calendar: calendar,
            onEdit: { blockID in
                presentEditor(for: blockID)
            },
            onToggleCompletion: { blockID in
                toggleCompletion(for: blockID)
            },
            onToggleStructuralItemCompletion: { itemKind in
                toggleBuiltInTimelineItemCompletion(itemKind)
            },
            onToggleChecklistExpansion: { blockID in
                toggleChecklistExpansion(for: blockID)
            },
            onToggleChecklistItem: { blockID, itemID in
                toggleChecklistItem(for: blockID, itemID: itemID)
            },
            onMoveBlock: { blockID, startDate in
                rescheduleBlock(blockID, to: startDate)
            },
            onCreateBlock: { startDate in
                presentNewBlockEditor(startingAt: startDate)
            }
        )
    }

    private var monthlyOverviewCard: some View {
        TimeCard {
            VStack(alignment: .leading, spacing: 16) {
                MonthlyPlanningView(
                    selectedDate: selectedDate,
                    days: selectedMonthDays,
                    summary: selectedMonthSummary,
                    calendar: calendar,
                    onSelectDay: { date in
                        appEnvironment.appState.selectedDate = date
                        collapseToDay()
                    },
                    onShiftMonth: { offset in
                        shiftSelectedMonth(by: offset)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var sharedScheduleMessages: some View {
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
    }

    @ViewBuilder
    private var calendarIntegrationStatus: some View {
        switch appEnvironment.timeCalendarManager.accessState {
        case .notDetermined:
            CalendarIntegrationBanner(
                title: "Show Apple Calendar events",
                message: "Grant calendar access to overlay device events alongside your time blocks in Day and Week views.",
                actionTitle: "Enable Calendar",
                action: requestCalendarAccess
            )
        case .denied:
            CalendarIntegrationBanner(
                title: "Calendar access denied",
                message: "Apple Calendar events stay hidden until this app is allowed to read calendars in system settings."
            )
        case .restricted:
            CalendarIntegrationBanner(
                title: "Calendar access restricted",
                message: "This device currently restricts calendar access, so Apple Calendar events cannot be shown here."
            )
        case .insufficientAccess:
            CalendarIntegrationBanner(
                title: "Calendar read access unavailable",
                message: "This app needs calendar read access to show Apple Calendar events next to your time blocks."
            )
        case .unsupported:
            CalendarIntegrationBanner(
                title: "Calendar unavailable",
                message: "EventKit is unavailable in this environment, so external calendar events cannot be loaded."
            )
        case .authorized:
            if let lastErrorMessage = appEnvironment.timeCalendarManager.lastErrorMessage {
                Text(lastErrorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private var calendarLoadingStatus: some View {
        if appEnvironment.timeCalendarManager.isLoading {
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)

                Text("Loading Apple Calendar events...")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            }
        }
    }

    private func regenerateSelectedDay() {
        guard canRegenerateSelectedDay else {
            return
        }

        isRegenerating = true
        regenerateErrorMessage = nil

        do {
            guard hasTemplates else {
                showFeedback(
                    title: "No routines yet",
                    message: "Create a routine first, then regenerate this day when you want repeating blocks added.",
                    systemImage: "square.on.square",
                    tint: Theme.primaryPurple
                )
                isRegenerating = false
                return
            }

            let regeneratedBlocks = try appEnvironment.scheduleRepository.regenerateTemplateBlocks(
                for: appEnvironment.appState.selectedDate,
                in: modelContext
            )
            Task {
                await appEnvironment.resyncNotifications(using: modelContext)
            }

            showFeedback(
                title: regeneratedBlocks.isEmpty ? "Nothing to regenerate" : "Day regenerated",
                message: regeneratedBlocks.isEmpty
                    ? "No routines match \(appEnvironment.appState.selectedDate.formatted(.dateTime.weekday(.wide))) yet."
                    : "Routine-backed planned blocks were refreshed for the selected day.",
                systemImage: regeneratedBlocks.isEmpty ? "calendar.badge.exclamationmark" : "arrow.clockwise.circle.fill",
                tint: regeneratedBlocks.isEmpty ? .orange : Theme.primaryPurple
            )
        } catch {
            regenerateErrorMessage = "Unable to regenerate this day right now."
            assertionFailure("Failed to regenerate schedule blocks: \(error)")
        }

        isRegenerating = false
    }

    private func resolveSelectedDayConflicts() {
        guard activeDrag == nil else {
            return
        }

        timelineErrorMessage = nil

        do {
            let resolvedBlocks = try appEnvironment.scheduleRepository.resolveConflicts(
                on: appEnvironment.appState.selectedDate,
                in: modelContext,
                calendar: calendar
            )

            guard !resolvedBlocks.isEmpty else {
                showFeedback(
                    title: "No overlaps found",
                    message: "The selected day does not have overlapping planned blocks to resolve.",
                    systemImage: "checkmark.circle",
                    tint: Theme.primaryPurple
                )
                return
            }

            Task {
                await appEnvironment.resyncNotifications(using: modelContext)
            }

            showFeedback(
                title: "Conflicts resolved",
                message: "\(resolvedBlocks.count) block\(resolvedBlocks.count == 1 ? "" : "s") shifted forward to remove overlaps.",
                systemImage: "arrow.right.circle.fill",
                tint: Theme.primaryPurple
            )
        } catch {
            timelineErrorMessage = "Unable to resolve overlaps right now."
            assertionFailure("Failed to resolve schedule conflicts: \(error)")
        }
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

        guard block.status == .planned else {
            dragErrorMessage = "Only planned blocks can be moved to another day."
            return
        }

        moveBlock(block.id, to: hoveredDate, errorTarget: .drag)
    }

    private func rescheduleBlock(_ blockID: UUID, to startDate: Date) {
        timelineErrorMessage = nil

        guard let block = fetchBlock(id: blockID) else {
            expandedChecklistBlockIDs.remove(blockID)
            timelineErrorMessage = "This time block is no longer available."
            return
        }

        guard block.status == .planned else {
            timelineErrorMessage = "Only planned blocks can be retimed on the timeline."
            return
        }

        do {
            let blockTitle = block.title
            try appEnvironment.scheduleRepository.rescheduleBlock(
                block,
                toStartDate: startDate,
                in: modelContext,
                calendar: calendar
            )
            Task {
                await appEnvironment.syncReminder(for: block, using: modelContext)
            }
            showFeedback(
                title: "Time updated",
                message: "\"\(blockTitle)\" now starts at \(startDate.formatted(date: .omitted, time: .shortened)).",
                systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                tint: Theme.primaryPurple
            )
        } catch {
            timelineErrorMessage = "Unable to update this block's time right now."
            assertionFailure("Failed to reschedule block on timeline: \(error)")
        }
    }

    private func requestCalendarAccess() {
        Task {
            await appEnvironment.timeCalendarManager.requestAccess()
            await refreshVisibleCalendarEvents(forceRefresh: true)
        }
    }

    private func refreshVisibleCalendarEvents(forceRefresh: Bool = false) async {
        guard let visibleCalendarInterval else {
            appEnvironment.timeCalendarManager.clearLoadedRange()
            return
        }

        if forceRefresh {
            appEnvironment.timeCalendarManager.clearLoadedRange()
        }

        await appEnvironment.timeCalendarManager.loadEvents(in: visibleCalendarInterval)
    }

    private func clearActiveDrag() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            activeDrag = nil
        }
        moveTargetFrames = [:]
    }

    @ViewBuilder
    private var activeDragOverlay: some View {
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

    private func moveBlock(
        _ blockID: UUID,
        to destinationDate: Date,
        errorTarget: ScheduleMoveErrorTarget
    ) {
        setMoveError(nil, for: errorTarget)

        guard let block = fetchBlock(id: blockID) else {
            expandedChecklistBlockIDs.remove(blockID)
            setMoveError("This time block is no longer available.", for: errorTarget)
            return
        }

        guard block.status == .planned else {
            setMoveError("Only planned blocks can be moved to another day.", for: errorTarget)
            return
        }

        guard !calendar.isDate(block.startDate, inSameDayAs: destinationDate) else {
            return
        }

        do {
            let blockTitle = block.title
            try appEnvironment.scheduleRepository.moveBlock(
                block,
                toDay: destinationDate,
                in: modelContext,
                calendar: calendar
            )
            Task {
                await appEnvironment.syncReminder(for: block, using: modelContext)
            }
            showFeedback(
                title: "Block moved",
                message: "\"\(blockTitle)\" is now on \(destinationDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).",
                systemImage: "checkmark.circle.fill",
                tint: .green
            )
            appEnvironment.appState.selectedDate = destinationDate
        } catch {
            setMoveError("Unable to move this block right now.", for: errorTarget)
            assertionFailure("Failed to move schedule block: \(error)")
        }
    }

    private func setMoveError(_ message: String?, for target: ScheduleMoveErrorTarget) {
        switch target {
        case .drag:
            dragErrorMessage = message
        }
    }

    private func fetchBlock(id: UUID) -> TimeBlock? {
        let descriptor = FetchDescriptor<TimeBlock>(
            predicate: #Predicate<TimeBlock> { block in
                block.id == id
            }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func presentEditor(for blockID: UUID) {
        guard let block = fetchBlock(id: blockID) else {
            expandedChecklistBlockIDs.remove(blockID)
            timelineErrorMessage = "This time block is no longer available."
            return
        }

        editorRoute = ScheduleEditorRoute(
            editingBlockID: block.id,
            entryMode: .standard,
            draft: TimeBlockEditorDraft(block: block)
        )
    }

    private func presentNewBlockEditor(for date: Date, entryMode: AddTimeBlockView.EntryMode = .standard) {
        presentNewBlockEditor(
            startingAt: defaultStartTime(for: date),
            selectedDate: calendar.startOfDay(for: date),
            entryMode: entryMode
        )
    }

    private func presentNewBlockEditor(
        startingAt startTime: Date,
        selectedDate: Date? = nil,
        entryMode: AddTimeBlockView.EntryMode = .standard
    ) {
        let resolvedSelectedDate = calendar.startOfDay(for: selectedDate ?? startTime)
        editorRoute = ScheduleEditorRoute(
            editingBlockID: nil,
            entryMode: entryMode,
            draft: TimeBlockEditorDraft(
                title: "",
                selectedDate: resolvedSelectedDate,
                startTime: startTime,
                durationMinutes: 60,
                category: .custom,
                notes: ""
            )
        )
    }



    private func shiftSelectedWeek(by offset: Int) {
        guard let shiftedDate = calendar.date(byAdding: .day, value: offset * 7, to: appEnvironment.appState.selectedDate) else {
            return
        }

        appEnvironment.appState.selectedDate = shiftedDate
        if overviewLayer == .collapsed {
            overviewLayer = .week
        }
    }

    private func shiftSelectedMonth(by offset: Int) {
        let monthDate = ScheduleMonthSupport.shiftedMonth(
            for: appEnvironment.appState.selectedDate,
            by: offset,
            calendar: calendar
        )

        let selectedDay = calendar.component(.day, from: appEnvironment.appState.selectedDate)
        let dayRange = calendar.range(of: .day, in: .month, for: monthDate) ?? 1..<29
        let clampedDay = min(selectedDay, dayRange.count)

        let shiftedDate = calendar.date(
            byAdding: .day,
            value: clampedDay - 1,
            to: monthDate
        ) ?? monthDate

        appEnvironment.appState.selectedDate = shiftedDate
    }

    private func defaultStartTime(for date: Date) -> Date {
        let dayStart = calendar.startOfDay(for: date)
        return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: dayStart) ?? date
    }

    private func utilityPill(title: String, detail: String, systemImage: String) -> some View {
        Label {
            Text("\(title): \(detail)")
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .foregroundStyle(Theme.primaryPurple)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.primaryPurple.opacity(0.1))
        .clipShape(Capsule())
    }

    private func durationText(for minutes: Int) -> String {
        if minutes.isMultiple(of: 60) {
            return "\(minutes / 60)h"
        }

        if minutes > 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return "\(hours)h \(remainder)m"
        }

        return "\(minutes) min"
    }

    private func toggleOverviewLayer() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) {
            if overviewLayer == .collapsed {
                overviewLayer = .week
            } else {
                collapseToDay()
            }
        }
    }

    private func collapseToDay() {
        overviewLayer = .collapsed
    }
}

private struct ScheduleBlockDragSession {
    let blockID: UUID
    var location: CGPoint
    var hoveredDate: Date?
}

private struct ScheduleEditorRoute: Identifiable {
    let id = UUID()
    let editingBlockID: UUID?
    let entryMode: AddTimeBlockView.EntryMode
    let draft: TimeBlockEditorDraft
}





private struct ScheduleFeedbackBannerState: Identifiable {
    let id: UUID
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
}

private enum ScheduleOverviewLayer {
    case collapsed
    case week
    case month
}

private struct ScheduleScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}



private enum ScheduleMoveErrorTarget {
    case drag
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

private struct CalendarIntegrationBanner: View {
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.blue)

                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
            }

            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(Color.blue)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.blue.opacity(0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct CalendarEventRow: View {
    let event: TimeCalendarEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(2)

                    Text(timeText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer(minLength: 0)

                Text("Read only")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }

            HStack(spacing: 8) {
                Label(event.sourceTitle, systemImage: "calendar")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.blue)

                if let location = event.location {
                    Label(location, systemImage: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.blue.opacity(0.06))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.blue.opacity(0.12), lineWidth: 1)
        }
    }

    private var timeText: String {
        if event.isAllDay {
            return "All day"
        }

        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }
}

private struct TimeBlockDragPreviewView: View {
    let block: TimeBlock
    let destinationDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: categorySymbol)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(tintColor)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(block.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)

                    Text(timeRangeText)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }
            }

            if let destinationDate {
                Divider()

                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.primaryPurple)

                    Text("Moving to \(destinationDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryPurple)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Theme.primaryPurple.opacity(0.2), lineWidth: 1)
        }
        .frame(width: 280)
    }

    private var categorySymbol: String {
        switch block.category {
        case .focus: return "scope"
        case .personal: return "figure.walk"
        case .admin: return "tray.full.fill"
        case .routine: return "repeat"
        case .custom: return "square.grid.2x2.fill"
        }
    }

    private var tintColor: Color {
        switch block.category {
        case .focus: return Theme.primaryPurple
        case .personal: return Color(hex: "F59E0B")
        case .admin: return Color(hex: "0EA5E9")
        case .routine: return Color(hex: "10B981")
        case .custom: return Color(hex: "64748B")
        }
    }

    private var timeRangeText: String {
        let start = block.startDate.formatted(date: .omitted, time: .shortened)
        let end = block.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }
}
