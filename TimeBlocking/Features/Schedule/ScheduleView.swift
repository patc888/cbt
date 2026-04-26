import os
import SwiftData
import SwiftUI

private let logger = Logger(subsystem: "com.melichan.TimeBlocking", category: "ScheduleView")

struct ScheduleView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Query private var blocks: [TimeBlock]

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
    @State private var showDailyConfetti = false

    init() {
        let earliestStartDate = Date.now.addingTimeInterval(-180 * 24 * 60 * 60)
        let latestStartDate = Date.now.addingTimeInterval(180 * 24 * 60 * 60)
        _blocks = Query(
            filter: #Predicate<TimeBlock> { block in
                block.startDate > earliestStartDate &&
                block.startDate < latestStartDate
            },
            sort: \TimeBlock.startDate
        )
    }


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
        scheduleRoot
            .coordinateSpace(name: dragCoordinateSpaceName)
            .animation(.spring(response: 0.32, dampingFraction: 0.84), value: activeDrag?.hoveredDate)
            .animation(.spring(response: 0.32, dampingFraction: 0.84), value: activeDrag?.blockID)
            .overlay {
                activeDragOverlay
            }
            .sheet(item: $editorRoute) { route in
                editorSheet(for: route)
            }
            .sheet(isPresented: $isShowingPlanningGuidance) {
                planningGuidanceSheet
            }
            .task(id: visibleGenerationDates) {
                generateVisibleDates()
            }
            .task(id: calendarLoadTrigger) {
                await refreshVisibleCalendarEvents()
            }
            .onChange(of: scenePhase) { _, newValue in
                handleScenePhaseChange(newValue)
            }
            .onChange(of: appEnvironment.appState.selectedDate) { _, _ in
                handleSelectedDateChange()
            }
            .onChange(of: appEnvironment.appState.isPresentingAddModal) { _, isPresenting in
                handleAddModalPresentationChange(isPresenting)
            }
            .onChange(of: dayTimelineBlocks.map(\.id)) { _, blockIDs in
                handleVisibleTimelineBlockIDsChange(blockIDs)
            }
    }

    private var scheduleRoot: some View {
        ZStack {
            AuroraBackground()
                .ignoresSafeArea()

            contentView

            if showDailyConfetti {
                ConfettiView()
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .zIndex(100)
                    .onAppear {
                        HapticManager.shared.success()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            withAnimation {
                                showDailyConfetti = false
                            }
                        }
                    }
            }
        }
    }

    private func editorSheet(for route: ScheduleEditorRoute) -> some View {
        AddTimeBlockView(
            selectedDate: route.draft.selectedDate,
            editingBlockID: route.editingBlockID,
            entryMode: route.entryMode,
            initialDraft: route.draft,
            onSave: handleEditorSave,
            onDelete: handleEditorDelete
        )
    }

    private func handleEditorSave(_ savedDate: Date) {
        appEnvironment.appState.selectedDate = savedDate
    }

    private func handleEditorDelete(_ deletedDate: Date) {
        guard !Calendar.current.isDate(appEnvironment.appState.selectedDate, inSameDayAs: deletedDate) else {
            return
        }

        appEnvironment.appState.selectedDate = deletedDate
    }

    private func generateVisibleDates() {
        for date in visibleGenerationDates {
            appEnvironment.generateScheduleIfNeeded(
                for: date,
                using: modelContext
            )
        }
    }

    private func handleScenePhaseChange(_ newValue: ScenePhase) {
        guard newValue == .active else {
            return
        }

        Task {
            await refreshVisibleCalendarEvents(forceRefresh: true)
        }
    }

    private func handleSelectedDateChange() {
        clearActiveDrag()
        dragErrorMessage = nil
        timelineErrorMessage = nil
        recentlyCompletedBlockIDs.removeAll()
    }

    private func handleAddModalPresentationChange(_ isPresenting: Bool) {
        guard isPresenting else {
            return
        }

        presentNewBlockEditor(for: appEnvironment.appState.selectedDate)
        appEnvironment.appState.isPresentingAddModal = false
    }

    private func handleVisibleTimelineBlockIDsChange(_ blockIDs: [UUID]) {
        expandedChecklistBlockIDs = expandedChecklistBlockIDs.filter { blockIDs.contains($0) }

        guard let activeDrag, !blockIDs.contains(activeDrag.blockID) else {
            return
        }

        clearActiveDrag()
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            pinnedHeader

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
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
                .padding(.top, 16)
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
        }
        .onPreferenceChange(ScheduleScrollOffsetPreferenceKey.self) { offset in
            topPullDistance = max(offset, 0)
        }
    }


    private var pinnedHeader: some View {
        VStack(spacing: 0) {
            dateHeader
                .padding(.bottom, 12)

            Divider()
                .opacity(0.1)
        }
        .background {
            Color.clear
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        }
    }


    private var dateHeader: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Button {
                    appEnvironment.appState.showDashboard()
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.primaryAccent)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                        .background(Theme.primaryAccent.opacity(0.1))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Open stats")

                Spacer()

                VStack(spacing: 0) {
                    Text(titleForDate(appEnvironment.appState.selectedDate))
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)

                    Text(subtitleForDate(appEnvironment.appState.selectedDate))
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()

                HStack(spacing: 8) {
                    if canRegenerateSelectedDay {
                        Button {
                            regenerateSelectedDay()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Theme.primaryAccent)
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                                .background(Theme.primaryAccent.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Refresh day from routines")
                        .transition(.scale.combined(with: .opacity))
                    }

                    if !calendar.isDateInToday(appEnvironment.appState.selectedDate) {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                appEnvironment.appState.selectedDate = .now
                            }
                            HapticManager.shared.lightImpact()
                        } label: {
                            Text("Today")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.primaryAccent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.primaryAccent.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    Button {
                        appEnvironment.appState.showSettings()
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.primaryAccent)
                            .frame(width: 36, height: 36)
                            .contentShape(Circle())
                            .background(Theme.primaryAccent.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Open settings")
                }

            }
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.top, 8)

            TimeHeaderView(
                selectedDate: selectedDate,
                weekStripDates: weekStripDates,
                calendar: calendar,
                horizontalPadding: 0,
                dateHasItems: { date in
                    appEnvironment.scheduleRepository.hasBlocks(on: date, in: blocks, calendar: calendar) ||
                    appEnvironment.timeCalendarManager.summary(for: date, calendar: calendar).hasEvents
                },
                showHeadline: false
            )
        }
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
            logger.error("Failed to update checklist item from day timeline: \(error)")
        }
    }

    private func toggleCompletion(for blockID: UUID) {
        timelineErrorMessage = nil

        guard let block = fetchBlock(id: blockID) else {
            expandedChecklistBlockIDs.remove(blockID)
            timelineErrorMessage = String(localized: "This time block is no longer available.")
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

            // Check for daily completion
            if nextStatus == .completed {
                let dayBlocks = daySnapshot.blocks
                let remainingPlanned = dayBlocks.filter { $0.status == .planned && $0.id != blockID }.count
                if remainingPlanned == 0 && !dayBlocks.isEmpty {
                    withAnimation {
                        showDailyConfetti = true
                    }
                }
            }

            Task {
                await appEnvironment.syncReminder(for: block, using: modelContext)
            }

        } catch {
            timelineErrorMessage = String(localized: "Unable to update this block right now.")
            logger.error("Failed to update block completion from day timeline: \(error)")
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
                        .tint(Theme.primaryAccent)
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
                    .tint(Theme.primaryAccent)
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
        if dayTimelineBlocks.isEmpty && dayCalendarEvents.isEmpty {
            DayTimelineEmptyState(
                date: appEnvironment.appState.selectedDate,
                onPlan: {
                    presentNewBlockEditor(for: appEnvironment.appState.selectedDate)
                }
            )
        } else {
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
                    tint: Theme.primaryAccent
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
                tint: regeneratedBlocks.isEmpty ? .orange : Theme.primaryAccent
            )
        } catch {
            regenerateErrorMessage = String(localized: "Unable to regenerate this day right now.")
            logger.error("Failed to regenerate schedule blocks: \(error)")
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
                    tint: Theme.primaryAccent
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
                tint: Theme.primaryAccent
            )
        } catch {
            timelineErrorMessage = String(localized: "Unable to resolve overlaps right now.")
            logger.error("Failed to resolve schedule conflicts: \(error)")
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
            timelineErrorMessage = String(localized: "This time block is no longer available.")
            return
        }

        guard block.status == .planned else {
            timelineErrorMessage = String(localized: "Only planned blocks can be retimed on the timeline.")
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
                tint: Theme.primaryAccent
            )
        } catch {
            timelineErrorMessage = String(localized: "Unable to update this block's time right now.")
            logger.error("Failed to reschedule block on timeline: \(error)")
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
            setMoveError(String(localized: "This time block is no longer available."), for: errorTarget)
            return
        }

        guard block.status == .planned else {
            setMoveError(String(localized: "Only planned blocks can be moved to another day."), for: errorTarget)
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
            setMoveError(String(localized: "Unable to move this block right now."), for: errorTarget)
            logger.error("Failed to move schedule block: \(error)")
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
            timelineErrorMessage = String(localized: "This time block is no longer available.")
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
        .foregroundStyle(Theme.primaryAccent)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.primaryAccent.opacity(0.1))
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

    private func titleForDate(_ date: Date) -> String {
        if calendar.isDateInToday(date) {
            return String(localized: "Today")
        } else if calendar.isDateInTomorrow(date) {
            return String(localized: "Tomorrow")
        } else if calendar.isDateInYesterday(date) {
            return String(localized: "Yesterday")
        } else {
            return date.formatted(.dateTime.weekday(.wide))
        }
    }

    private func subtitleForDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day())
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
