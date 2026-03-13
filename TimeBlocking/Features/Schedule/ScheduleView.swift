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
    @SceneStorage("schedule.presentationMode") private var scheduleModeRawValue = SchedulePresentationMode.day.rawValue
    @State private var editorRoute: ScheduleEditorRoute?
    @State private var isRegenerating = false
    @State private var regenerateErrorMessage: String?
    @State private var dragErrorMessage: String?
    @State private var timelineErrorMessage: String?
    @State private var activeDrag: ScheduleBlockDragSession?
    @State private var moveTargetFrames: [Date: CGRect] = [:]
    @State private var feedbackBanner: ScheduleFeedbackBannerState?
    @State private var expandedChecklistBlockIDs: Set<UUID> = []
    @Namespace private var scheduleModeNamespace

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
        appEnvironment.scheduleRepository.daySnapshot(
            for: appEnvironment.appState.selectedDate,
            from: blocks,
            includeCompleted: showsCompletedBlocks,
            calendar: calendar
        )
    }

    private var upcomingBlocks: [TimeBlock] {
        appEnvironment.scheduleRepository.upcomingBlocks(from: blocks)
    }

    private var hasTemplates: Bool {
        !templates.isEmpty
    }

    private var canRegenerateSelectedDay: Bool {
        !isRegenerating && activeDrag == nil
    }

    private var scheduleMode: SchedulePresentationMode {
        get { SchedulePresentationMode(rawValue: scheduleModeRawValue) ?? .day }
        nonmutating set { scheduleModeRawValue = newValue.rawValue }
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
        horizontalSizeClass == .compact ? 8 : 24
    }

    private var metricColumns: [GridItem] {
        if horizontalSizeClass == .compact {
            return [GridItem(.flexible()), GridItem(.flexible())]
        }

        return [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
    }

    private var selectedWeekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: appEnvironment.appState.selectedDate) else {
            return [calendar.startOfDay(for: appEnvironment.appState.selectedDate)]
        }

        let startDate = calendar.startOfDay(for: weekInterval.start)
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: startDate).map(calendar.startOfDay(for:))
        }
    }

    private var selectedWeekDays: [WeeklyPlanningDay] {
        selectedWeekDates.map { date in
            let snapshot = appEnvironment.scheduleRepository.daySnapshot(
                for: date,
                from: blocks,
                includeCompleted: showsCompletedBlocks,
                calendar: calendar
            )
            let calendarEvents = appEnvironment.timeCalendarManager.events(
                on: date,
                calendar: calendar
            )
            let planningGuidance = SchedulePlanningGuidanceSnapshot.build(
                for: date,
                blocks: snapshot.blocks,
                overlappingBlockIDs: appEnvironment.scheduleRepository.overlappingPlannedBlockIDs(
                    on: date,
                    from: blocks,
                    calendar: calendar
                ),
                calendarEvents: calendarEvents,
                dayStartHour: dayStartHour,
                calendar: calendar
            )

            return WeeklyPlanningDay(
                date: date,
                snapshot: snapshot,
                calendarSummary: appEnvironment.timeCalendarManager.summary(
                    for: date,
                    calendar: calendar
                ),
                conflictCount: planningGuidance.conflictingBlockCount
            )
        }
    }

    private var selectedWeekSummary: ScheduleWeekSummary {
        ScheduleWeekSummary(days: selectedWeekDays, calendar: calendar)
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
        if scheduleMode == .week {
            return selectedWeekDates
        }

        if scheduleMode == .month {
            return selectedMonthDates
        }

        return [calendar.startOfDay(for: appEnvironment.appState.selectedDate)]
    }

    private var visibleCalendarInterval: DateInterval? {
        switch scheduleMode {
        case .day:
            let start = calendar.startOfDay(for: appEnvironment.appState.selectedDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return DateInterval(start: start, end: end)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: appEnvironment.appState.selectedDate)
        case .month:
            return nil
        }
    }

    private var selectedWeekHasCalendarEvents: Bool {
        selectedWeekDays.contains { $0.calendarSummary.hasEvents }
    }

    private var showsSelectedDayContent: Bool {
        !daySnapshot.blocks.isEmpty || !dayCalendarEvents.isEmpty
    }

    private var showsSelectedWeekContent: Bool {
        selectedWeekSummary.hasBlocks || selectedWeekHasCalendarEvents
    }

    private var calendarLoadTrigger: String {
        guard let visibleCalendarInterval else {
            return "month"
        }

        return [
            scheduleModeRawValue,
            String(visibleCalendarInterval.start.timeIntervalSinceReferenceDate),
            String(visibleCalendarInterval.end.timeIntervalSinceReferenceDate),
            appEnvironment.timeCalendarManager.accessState.rawValue
        ].joined(separator: "|")
    }

    private var scheduleModeSelection: Binding<SchedulePresentationMode> {
        Binding(
            get: { scheduleMode },
            set: { scheduleMode = $0 }
        )
    }

    private var metricItems: [ScheduleMetricItem] {
        if scheduleMode == .month {
            return [
                ScheduleMetricItem(title: "Planned", value: "\(selectedMonthSummary.plannedCount)", systemImage: "calendar.badge.clock"),
                ScheduleMetricItem(title: "Completed", value: "\(selectedMonthSummary.completedCount)", systemImage: "checkmark.circle"),
                ScheduleMetricItem(title: "Scheduled", value: selectedMonthSummary.scheduledTimeText, systemImage: "timer"),
                ScheduleMetricItem(title: "Active Days", value: "\(selectedMonthSummary.activeDayCount)", systemImage: "calendar")
            ]
        }

        if scheduleMode == .week {
            return [
                ScheduleMetricItem(title: "Planned", value: "\(selectedWeekSummary.plannedCount)", systemImage: "calendar.badge.clock"),
                ScheduleMetricItem(title: "Completed", value: "\(selectedWeekSummary.completedCount)", systemImage: "checkmark.circle"),
                ScheduleMetricItem(title: "Scheduled", value: "\(selectedWeekSummary.scheduledMinutes) min", systemImage: "timer"),
                ScheduleMetricItem(title: "Busiest", value: selectedWeekSummary.busiestDayLabel, systemImage: "chart.bar.fill")
            ]
        }

        return [
            ScheduleMetricItem(title: "Planned", value: "\(daySnapshot.plannedCount)", systemImage: "calendar.badge.clock"),
            ScheduleMetricItem(title: "Completed", value: "\(daySnapshot.completedCount)", systemImage: "checkmark.circle"),
            ScheduleMetricItem(title: "Scheduled", value: "\(daySnapshot.scheduledMinutes) min", systemImage: "timer"),
            ScheduleMetricItem(title: "Upcoming", value: "\(upcomingBlocks.count)", systemImage: "forward.fill")
        ]
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
        .sheet(item: $editorRoute) { route in
            AddTimeBlockView(
                selectedDate: route.draft.selectedDate,
                editingBlockID: route.editingBlockID,
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
        }
        .onChange(of: appEnvironment.appState.isPresentingAddModal) { _, isPresenting in
            guard isPresenting else {
                return
            }

            presentNewBlockEditor(for: appEnvironment.appState.selectedDate)
            appEnvironment.appState.isPresentingAddModal = false
        }
        .onChange(of: scheduleModeRawValue) { _, _ in
            clearActiveDrag()
            dragErrorMessage = nil
            timelineErrorMessage = nil
        }
        .onChange(of: daySnapshot.blocks.map(\.id)) { _, blockIDs in
            expandedChecklistBlockIDs = expandedChecklistBlockIDs.filter { blockIDs.contains($0) }

            guard let activeDrag, !blockIDs.contains(activeDrag.blockID) else {
                return
            }

            clearActiveDrag()
        }
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                dateHeader
                moveRibbon
                scheduleModeRow
                metricGrid
                scheduleSurface
                upcomingSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, contentHorizontalPadding)
            .padding(.bottom, 100)
        }
    }

    private var dateHeader: some View {
        DateStripHeaderView(
            selectedDate: selectedDate,
            firstWeekday: firstWeekday,
            dateHasItems: blocksExist(on:)
        )
        .padding(.top, 64)
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

    private var scheduleModeRow: some View {
        HStack(alignment: .center, spacing: 12) {
            TimeSegmentedToggle(
                selection: scheduleModeSelection,
                options: SchedulePresentationMode.allCases,
                namespace: scheduleModeNamespace,
                fontSize: 12,
                verticalPadding: 7,
                useMinWidth: true,
                minWidth: 74,
                title: { $0.title }
            )

            Spacer(minLength: 0)

            if scheduleMode == .week || scheduleMode == .month {
                Text(scheduleModeSummaryLabel)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryPurple)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.primaryPurple.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: metricColumns, spacing: Theme.paddingMedium) {
            ForEach(metricItems) { item in
                TimeMetricTile(title: item.title, value: item.value, systemImage: item.systemImage)
            }
        }
    }

    @ViewBuilder
    private var upcomingSection: some View {
        if !upcomingBlocks.isEmpty {
            TimeCard {
                VStack(alignment: .leading, spacing: 16) {
                    TimeSectionHeader("Upcoming", subtitle: "Next planned blocks after the selected day")

                    ForEach(upcomingBlocks) { block in
                        TimeBlockRowView(block: block) {
                            presentEditor(for: block)
                        }

                        if block.id != upcomingBlocks.last?.id {
                            Divider().padding(.vertical, 12)
                        }
                    }
                }
            }
        }
    }

    private func toggleChecklistExpansion(for block: TimeBlock) {
        guard !(block.checklistItems ?? []).isEmpty else {
            return
        }

        if expandedChecklistBlockIDs.contains(block.id) {
            expandedChecklistBlockIDs.remove(block.id)
        } else {
            expandedChecklistBlockIDs.insert(block.id)
        }
    }

    private func blocksExist(on date: Date) -> Bool {
        appEnvironment.scheduleRepository.hasBlocks(on: date, in: blocks)
    }

    @ViewBuilder
    private var scheduleSurface: some View {
        if scheduleMode == .week {
            weeklyPlanningCard
        } else if scheduleMode == .month {
            monthlyPlanningCard
        } else {
            selectedDayCard
        }
    }

    private var selectedDayCard: some View {
        TimeCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    TimeSectionHeader(
                        "Selected Day",
                        subtitle: appEnvironment.appState.selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
                    )

                    Button {
                        regenerateSelectedDay()
                    } label: {
                        Label(isRegenerating ? "Refreshing..." : "Refresh", systemImage: "arrow.clockwise")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.primaryPurple)
                    .controlSize(.small)
                    .disabled(!canRegenerateSelectedDay)
                }

                Text(activeDrag == nil
                     ? "Drag planned blocks on the timeline to retime them, or use Move to send a planned block to another day."
                     : "Drop on a nearby day to move this planned block while keeping its time and duration.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)

                if shouldShowMoveHint {
                    MoveHintCallout()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                sharedScheduleMessages
                calendarIntegrationStatus
                calendarLoadingStatus
                SchedulePlanningGuidanceView(
                    snapshot: selectedDayPlanningGuidance,
                    onResolveConflicts: resolveConflictsAction
                )

                Divider()

                if !showsSelectedDayContent {
                    EmptyStateView(
                        title: "No Blocks Yet",
                        systemImage: "calendar.badge.plus",
                        message: hasTemplates
                            ? "Add a one-off block for this date, or refresh the day to pull in matching templates."
                            : "Add a one-off block for this date, or create a template first if it should repeat.",
                        eyebrow: "Schedule"
                    ) {
                        Button("Add Block") {
                            presentNewBlockEditor(for: appEnvironment.appState.selectedDate)
                        }
                        .buttonStyle(.borderedProminent)

                        if !hasTemplates {
                            Button("Open Templates") {
                                appEnvironment.appState.selectedSection = .templates
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 20)
                } else {
                    DayTimelineView(
                        date: appEnvironment.appState.selectedDate,
                        blocks: daySnapshot.blocks,
                        calendarEvents: dayCalendarEvents,
                        blockConflictsByID: selectedDayPlanningGuidance.blockConflictsByID,
                        dayStartHour: dayStartHour,
                        calendar: calendar,
                        onEdit: { block in
                            presentEditor(for: block)
                        },
                        onMoveBlock: { block, startDate in
                            rescheduleBlock(block, to: startDate)
                        }
                    )

                    Divider()

                    VStack(spacing: 0) {
                        if !daySnapshot.blocks.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(daySnapshot.blocks) { block in
                                    TimeBlockRowView(
                                        block: block,
                                        conflictSummary: selectedDayPlanningGuidance.blockConflictsByID[block.id],
                                        onEdit: {
                                            presentEditor(for: block)
                                        },
                                        isChecklistExpanded: expandedChecklistBlockIDs.contains(block.id),
                                        onToggleChecklistExpansion: {
                                            toggleChecklistExpansion(for: block)
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

                        if !dayCalendarEvents.isEmpty {
                            if !daySnapshot.blocks.isEmpty {
                                Divider().padding(.vertical, 12)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Label("Apple Calendar", systemImage: "calendar")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color.blue)

                                ForEach(dayCalendarEvents) { event in
                                    CalendarEventRow(event: event)

                                    if event.id != dayCalendarEvents.last?.id {
                                        Divider().padding(.vertical, 6)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var weeklyPlanningCard: some View {
        TimeCard {
            VStack(alignment: .leading, spacing: 16) {
                sharedScheduleMessages
                calendarIntegrationStatus
                calendarLoadingStatus

                if !showsSelectedWeekContent {
                    EmptyStateView(
                        title: "No Blocks This Week",
                        systemImage: "calendar.badge.plus",
                        message: hasTemplates
                            ? "Switch weeks, add a one-off block, or open a day and refresh it to pull in matching templates."
                            : "Add a block to any day in this week, or create templates first if the schedule should repeat.",
                        eyebrow: "Weekly Planning"
                    ) {
                        Button("Add Block") {
                            presentNewBlockEditor(for: appEnvironment.appState.selectedDate)
                        }
                        .buttonStyle(.borderedProminent)

                        if !hasTemplates {
                            Button("Open Templates") {
                                appEnvironment.appState.selectedSection = .templates
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 20)
                } else {
                    WeeklyPlanningView(
                        selectedDate: selectedDate,
                        weekDays: selectedWeekDays,
                        calendar: calendar,
                        onShiftWeek: { offset in
                            shiftSelectedWeek(by: offset)
                        },
                        onEditBlock: { block in
                            presentEditor(for: block)
                        },
                        onMoveBlock: { block, date in
                            moveBlock(block, to: date, errorTarget: .drag)
                        }
                    )
                }
            }
        }
    }

    private var monthlyPlanningCard: some View {
        TimeCard {
            VStack(alignment: .leading, spacing: 16) {
                sharedScheduleMessages

                MonthlyPlanningView(
                    selectedDate: selectedDate,
                    days: selectedMonthDays,
                    summary: selectedMonthSummary,
                    calendar: calendar,
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
                    title: "No templates yet",
                    message: "Create a template first, then regenerate this day when you want routine blocks added.",
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
                    ? "No templates match \(appEnvironment.appState.selectedDate.formatted(.dateTime.weekday(.wide))) yet."
                    : "Template-backed planned blocks were refreshed for the selected day.",
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

        moveBlock(block, to: hoveredDate, errorTarget: .drag)
    }

    private func rescheduleBlock(_ block: TimeBlock, to startDate: Date) {
        timelineErrorMessage = nil

        guard block.status == .planned else {
            timelineErrorMessage = "Only planned blocks can be retimed on the timeline."
            return
        }

        do {
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
                message: "\"\(block.title)\" now starts at \(startDate.formatted(date: .omitted, time: .shortened)).",
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
        _ block: TimeBlock,
        to destinationDate: Date,
        errorTarget: ScheduleMoveErrorTarget
    ) {
        setMoveError(nil, for: errorTarget)

        guard block.status == .planned else {
            setMoveError("Only planned blocks can be moved to another day.", for: errorTarget)
            return
        }

        guard !calendar.isDate(block.startDate, inSameDayAs: destinationDate) else {
            return
        }

        do {
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
                message: "\"\(block.title)\" is now on \(destinationDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).",
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

    private func presentEditor(for block: TimeBlock) {
        editorRoute = ScheduleEditorRoute(
            editingBlockID: block.id,
            draft: TimeBlockEditorDraft(block: block)
        )
    }

    private func presentNewBlockEditor(for date: Date) {
        editorRoute = ScheduleEditorRoute(
            editingBlockID: nil,
            draft: TimeBlockEditorDraft(
                title: "",
                selectedDate: calendar.startOfDay(for: date),
                startTime: defaultStartTime(for: date),
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

    private var scheduleModeSummaryLabel: String {
        switch scheduleMode {
        case .day:
            return ""
        case .week:
            return selectedWeekSummary.weekLabel
        case .month:
            return selectedMonthSummary.monthLabel
        }
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
    let draft: TimeBlockEditorDraft
}

private struct ScheduleFeedbackBannerState: Identifiable {
    let id: UUID
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
}

private enum SchedulePresentationMode: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var title: String {
        switch self {
        case .day:
            return "Day"
        case .week:
            return "Week"
        case .month:
            return "Month"
        }
    }
}

private struct ScheduleMetricItem: Identifiable {
    let title: String
    let value: String
    let systemImage: String

    var id: String { title }
}

private struct ScheduleWeekSummary {
    let plannedCount: Int
    let completedCount: Int
    let scheduledMinutes: Int
    let busiestDayLabel: String
    let weekLabel: String
    let hasBlocks: Bool

    init(days: [WeeklyPlanningDay], calendar: Calendar) {
        plannedCount = days.reduce(0) { $0 + $1.snapshot.plannedCount }
        completedCount = days.reduce(0) { $0 + $1.snapshot.completedCount }
        scheduledMinutes = days.reduce(0) { $0 + $1.snapshot.scheduledMinutes }
        hasBlocks = days.contains { !$0.snapshot.blocks.isEmpty }

        if let busiestDay = days.max(by: { $0.snapshot.scheduledMinutes < $1.snapshot.scheduledMinutes }),
           busiestDay.snapshot.scheduledMinutes > 0 {
            busiestDayLabel = busiestDay.date.formatted(.dateTime.weekday(.abbreviated))
        } else {
            busiestDayLabel = "Rest"
        }

        if let firstDate = days.first?.date, let lastDate = days.last?.date {
            if calendar.isDate(firstDate, equalTo: lastDate, toGranularity: .month) {
                weekLabel = "\(firstDate.formatted(.dateTime.month(.abbreviated))) \(firstDate.formatted(.dateTime.day()))-\(lastDate.formatted(.dateTime.day()))"
            } else {
                weekLabel = "\(firstDate.formatted(.dateTime.month(.abbreviated).day()))-\(lastDate.formatted(.dateTime.month(.abbreviated).day()))"
            }
        } else {
            weekLabel = "This Week"
        }
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
