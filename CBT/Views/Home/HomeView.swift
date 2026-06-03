import SwiftUI
import SwiftData
import OSLog

struct HomeView: View {
    private static let logger = AppLogger.make(category: "HomeView")
    @Binding var selectedTab: FloatingTab
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedDate = Date()
    @State private var showingNewMoodEntry = false
    @State private var showingNewThoughtRecord = false
    @State private var attemptingNewMoodEntry = false
    @State private var attemptingNewThoughtRecord = false
    @State private var showingTipModal = false
    @State private var selectedMoodForFlow: MoodColor? = nil
    @State private var showingBadDayMode = false
    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                DeferredRenderView(
                    isEnabled: scenePhase == .active,
                    delay: .milliseconds(250)
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        AppScreenHeadline(title: String(localized: "Today"))
                        .padding(.horizontal, 16)

                        HomeDashboardPlaceholder()
                    }
                } content: {
                    HomeDashboardContent(
                        selectedTab: $selectedTab,
                        selectedDate: $selectedDate,
                        showingNewMoodEntry: $showingNewMoodEntry,
                        showingNewThoughtRecord: $showingNewThoughtRecord,
                        attemptingNewMoodEntry: $attemptingNewMoodEntry,
                        attemptingNewThoughtRecord: $attemptingNewThoughtRecord,
                        showingTipModal: $showingTipModal,
                        selectedMoodForFlow: $selectedMoodForFlow,
                        showingBadDayMode: $showingBadDayMode
                    )
                }
                .accessibilityIdentifier("home-scroll-view")
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: LayoutMetrics.floatingToolbarBottomInset)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home-screen")
            .navigationTitle("")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            #endif
        }
        .onAppear {
            Self.logger.info("HomeView mounted")
        }
        .sheet(isPresented: $showingNewMoodEntry, onDismiss: { selectedMoodForFlow = nil }) {
            DailyCheckInView()
                .dsSheetPresentation()
        }
        .sheet(isPresented: $showingNewThoughtRecord) {
            NewThoughtRecordFlowView()
                .dsSheetPresentation()
        }
        .sheet(isPresented: $showingBadDayMode) {
            BadDayModeView()
                .onAppear {
                    AchievementService.shared.recordBadDayModeUsed(in: modelContext)
                }
                .dsSheetPresentation(detents: [.large])
        }
    }

}

private struct HomeDashboardPlaceholder: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HomeDashboardSkeleton()
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)
        }
    }
}

// MARK: - Subviews

private struct HomeDashboardContent: View {
    private static let logger = AppLogger.make(category: "HomeDashboardContent")

    private struct DashboardRefreshToken: Equatable {
        let day: Date
        let nonce: Int
    }

    private static let dashboardWeekDates: [Date] = {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (-180...180).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
    }()

    @Binding var selectedTab: FloatingTab
    @Binding var selectedDate: Date
    @Binding var showingNewMoodEntry: Bool
    @Binding var showingNewThoughtRecord: Bool
    @Binding var attemptingNewMoodEntry: Bool
    @Binding var attemptingNewThoughtRecord: Bool
    @Binding var showingTipModal: Bool
    @Binding var selectedMoodForFlow: MoodColor?
    @Binding var showingBadDayMode: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Achievement.createdAt) private var achievements: [Achievement]
    @Query(sort: \TinyWinCompletion.createdAt, order: .reverse) private var tinyWinCompletions: [TinyWinCompletion]
    @Query(sort: \PersonalValue.createdAt) private var personalValues: [PersonalValue]
    @Query(sort: \ValueActionCompletion.createdAt, order: .reverse) private var valueActionCompletions: [ValueActionCompletion]
    @AppStorage(DailyRecommendationService.lastHomeVisitKey) private var lastHomeVisitInterval: Double = 0
    @AppStorage("cbt_retention_last_daily_plan_completed_day") private var lastRetentionDailyPlanCompletedDay = ""
    @AppStorage(WelcomeBackRecoveryState.completionDefaultsKey) private var recoveryCompletedDayKey = ""
    @AppStorage("cbt_streakReengagementReminderEnabled") private var streakReengagementReminderEnabled = false
    @AppStorage(TomorrowAnchor.defaultsKey) private var tomorrowAnchorID = ""
    @AppStorage(TomorrowAnchor.updatedAtDefaultsKey) private var tomorrowAnchorUpdatedAt: Double = 0
    @State private var viewModel = HomeDashboardViewModel()
    @State private var refreshNonce = 0
    @State private var hasAppeared = false
    @State private var sessionLastHomeVisit: Date?
    @State private var hasRecordedHomeVisit = false
    @State private var selectedExercise: Exercise?
    @State private var selectedToolkitExercise: Exercise?
    @State private var triggerLibrary: TriggerLibrarySnapshot = .empty
    @State private var continueItem: ContinueItem?
    @State private var selectedContinueRoute: ContinueRouteSheet?
    @State private var showingActivityPlanner = false
    @State private var showingIntroToCBT = false
    @State private var showingSafetySupport = false
    @State private var showingWeeklyReview = false
    @State private var showingValuesSetup = false
    @State private var journeyStatus: FirstSevenDaysJourneyStatus = .empty
    @State private var toolkitRefreshToken = 0
    @State private var showingRecoveryReminderPrompt = false
    @State private var hasLoggedRecoveryView = false
    private var calendar: Calendar { .current }

    private var heroItems: [DailyPlanItem] {
        [.moodCheckIn, .breathingReset, .exercises, .thoughtRecord, .activityPlanner]
    }

    private var toolkitFavorites: [CopingToolkitTool] {
        CopingToolkitService.shared.favorites(limit: 3)
    }

    private var recentlyUsedToolkitTools: [CopingToolkitTool] {
        CopingToolkitService.shared.recentlyUsed(limit: 3)
    }

    private var completedHeroItems: Int {
        heroItems.filter { viewModel.completionSnapshot.state(for: $0).isCompleted }.count
    }

    private var heroProgress: Double {
        guard !heroItems.isEmpty else { return 0 }
        return Double(completedHeroItems) / Double(heroItems.count)
    }

    private var dailyPlanRecommendations: [DailyRecommendation] {
        guard let duplicateKey = continueItem?.destination.dailyPlanDestinationKey else {
            return viewModel.recommendations
        }
        return viewModel.recommendations.filter { $0.destination.deepLink != duplicateKey }
    }

    private var bestNextStepRecommendation: DailyRecommendation {
        if viewModel.dailyPlanLoopState.isPlanComplete {
            return viewModel.dailyPlanLoopState.optionalTinyAction ?? viewModel.dailyPlanLoopState.primaryNextStep
        }
        return viewModel.dailyPlanLoopState.primaryNextStep
    }

    private var bestNextStepCompletionState: PlanCardCompletionState {
        guard !viewModel.dailyPlanLoopState.isPlanComplete else { return .notTracked }
        if bestNextStepRecommendation.isCompletedToday {
            return .completed
        }
        guard let item = bestNextStepRecommendation.completionItem else { return .notTracked }
        return viewModel.completionSnapshot.state(for: item)
    }

    private var personalizedSpotlightCards: [HomePersonalizedCard] {
        viewModel.personalizedCards.filter { card in
            switch card.id {
            case .checkIn, .restart, .recommendation, .weeklyProgress:
                return true
            case .continueItem, .tinyWin, .badDayMode, .lowEnergyMode:
                return false
            }
        }
    }

    private var recoveryState: WelcomeBackRecoveryState? {
        WelcomeBackRecoveryState.make(
            missedDays: viewModel.badDayContext.missedDays,
            selectedDate: selectedDate,
            activeDates: viewModel.activeDates,
            completedDayKey: recoveryCompletedDayKey,
            calendar: calendar
        )
    }

    private var shouldShowEasierDayPath: Bool {
        viewModel.badDayContext.shouldShow ||
            viewModel.personalizedCards.contains { $0.id == .lowEnergyMode }
    }

    init(
        selectedTab: Binding<FloatingTab>,
        selectedDate: Binding<Date>,
        showingNewMoodEntry: Binding<Bool>,
        showingNewThoughtRecord: Binding<Bool>,
        attemptingNewMoodEntry: Binding<Bool>,
        attemptingNewThoughtRecord: Binding<Bool>,
        showingTipModal: Binding<Bool>,
        selectedMoodForFlow: Binding<MoodColor?>,
        showingBadDayMode: Binding<Bool>
    ) {
        self._selectedTab = selectedTab
        self._selectedDate = selectedDate
        self._showingNewMoodEntry = showingNewMoodEntry
        self._showingNewThoughtRecord = showingNewThoughtRecord
        self._attemptingNewMoodEntry = attemptingNewMoodEntry
        self._attemptingNewThoughtRecord = attemptingNewThoughtRecord
        self._showingTipModal = showingTipModal
        self._selectedMoodForFlow = selectedMoodForFlow
        self._showingBadDayMode = showingBadDayMode
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                AppScreenHeadline(title: String(localized: "Today"))
                .padding(.horizontal, 16)

                HomeHeroCard(
                    selectedDate: selectedDate,
                    completedCount: completedHeroItems,
                    totalCount: heroItems.count,
                    activeDayCount: viewModel.activeDates.count,
                    progress: heroProgress,
                    animate: hasAppeared && !reduceMotion
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .homeEntrance(index: 0, isVisible: hasAppeared, reduceMotion: reduceMotion)

                HomeDateRailCard(
                    selectedDate: $selectedDate,
                    weekDates: Self.dashboardWeekDates,
                    dayHasActivity: { date in
                        viewModel.activeDates.contains(calendar.startOfDay(for: date))
                    }
                )
                .padding(.horizontal, 16)
                .opacity(viewModel.isInitialized ? 1 : 0.6)
                .homeEntrance(index: 1, isVisible: hasAppeared, reduceMotion: reduceMotion)

                if viewModel.isInitialized && shouldShowEasierDayPath {
                    MakeTodayEasierCard(
                        context: viewModel.badDayContext,
                        onBreathingReset: { presentBreathingReset(durationSeconds: 60) },
                        onMoodCheckIn: { attemptingNewMoodEntry = true },
                        onGrounding: { showingBadDayMode = true },
                        onSafetySupport: {
                            AchievementService.shared.recordBadDayModeUsed(in: modelContext)
                            showingSafetySupport = true
                        }
                    )
                    .padding(.horizontal, 16)
                    .homeEntrance(index: 2, isVisible: hasAppeared, reduceMotion: reduceMotion)
                }

                if viewModel.isInitialized {
                    TodayBestNextStepCard(
                        recommendation: bestNextStepRecommendation,
                        explanation: viewModel.dailyPlanLoopState.whyExplanation,
                        completionState: bestNextStepCompletionState,
                        isPlanComplete: viewModel.dailyPlanLoopState.isPlanComplete
                    ) {
                        performRecommendation(bestNextStepRecommendation)
                    }
                    .padding(.horizontal, 16)
                    .homeEntrance(index: shouldShowEasierDayPath ? 3 : 2, isVisible: hasAppeared, reduceMotion: reduceMotion)
                }

                copingToolkitHomeSection
                    .padding(.horizontal, 16)
                    .homeEntrance(index: shouldShowEasierDayPath ? 4 : 3, isVisible: hasAppeared, reduceMotion: reduceMotion)

                TriggerToolsHomeCard(
                    snapshot: triggerLibrary,
                    onOpenTool: perform(triggerTool:),
                    onOpenInsights: { selectedTab = .insights }
                )
                .padding(.horizontal, 16)
                .homeEntrance(index: shouldShowEasierDayPath ? 5 : 4, isVisible: hasAppeared, reduceMotion: reduceMotion)

                FirstSevenDaysJourneyHomeCard(status: journeyStatus) { step in
                    perform(destination: step.destination)
                }
                .padding(.horizontal, 16)
                .homeEntrance(index: shouldShowEasierDayPath ? 6 : 5, isVisible: hasAppeared, reduceMotion: reduceMotion)

                Group {
                    if viewModel.isInitialized {
                        if let recoveryState {
                            WelcomeBackRecoveryCard(
                                state: recoveryState,
                                onResumePreviousPlan: { completeRecovery(.resumePreviousPlan) },
                                onStartFreshToday: { completeRecovery(.startFreshToday) },
                                onRestartMomentum: { completeRecovery(.restartMomentum) }
                            )
                        }

                        DailyPlanView(
                            recommendations: dailyPlanRecommendations,
                            completionSnapshot: viewModel.completionSnapshot,
                            loopState: viewModel.dailyPlanLoopState,
                            pickedResetYesterday: pickedResetYesterday,
                            onRecommendationSelected: performRecommendation,
                            onContinueSelected: { performPersonalizedAction($0.action) },
                            onLogMood: { attemptingNewMoodEntry = true },
                            onThoughtRecord: { attemptingNewThoughtRecord = true },
                            onBreathingReset: { presentBreathingReset(durationSeconds: 60) },
                            onActivityPlanner: { showingActivityPlanner = true }
                        )
                    } else {
                        HomeDashboardSkeleton()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .homeEntrance(index: shouldShowEasierDayPath ? 7 : 6, isVisible: hasAppeared, reduceMotion: reduceMotion)

                VStack(alignment: .leading, spacing: 16) {
                    if !viewModel.isInitialized {
                        HomeDashboardSkeleton()
                    } else {
                        HomeSectionHeader(
                            title: String(localized: "More for today"),
                            subtitle: String(localized: "A few small tools to keep the day steady.")
                        )

                        HomeRecentAchievementsCard(achievements: achievements)

                        TipOfTheDayPlanCard(
                            completionState: viewModel.completionSnapshot.state(for: .tipOfTheDay),
                            action: { showingTipModal = true }
                        )

                        TinyWinHomeCard(
                            state: TinyWinService.state(
                                for: selectedDate,
                                completions: tinyWinCompletions,
                                now: Date(),
                                calendar: calendar
                            ),
                            action: completeTinyWin
                        )

                        ValueActionHomeCard(
                            action: ValuesService.action(
                                for: selectedDate,
                                selectedValues: personalValues,
                                calendar: calendar
                            ),
                            isCompleted: valueActionIsCompleted,
                            onComplete: completeValueAction,
                            onChooseValues: { showingValuesSetup = true }
                        )

                        CopingPlanHomeCard {
                            showingSafetySupport = true
                        }

                        BadDayModeShortcutCard(
                            context: viewModel.badDayContext,
                            action: { showingBadDayMode = true }
                        )

                        NavigationLink {
                            WeeklyReviewView()
                        } label: {
                            HomeWeeklyReviewCard()
                        }
                        .buttonStyle(.plain)

                        TomorrowAnchorCard(
                            selectedAnchor: tomorrowAnchor,
                            updatedAt: tomorrowAnchorDate,
                            onSelect: saveTomorrowAnchor
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .homeEntrance(index: shouldShowEasierDayPath ? 8 : (continueItem == nil ? 7 : 8), isVisible: hasAppeared, reduceMotion: reduceMotion)
            }
            .id(toolkitRefreshToken)
            .responsiveMaxWidth()
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            guard !hasAppeared else { return }
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.spring(response: 0.7, dampingFraction: 0.82)) {
                    hasAppeared = true
                }
            }
        }
        .sheet(isPresented: $showingTipModal, onDismiss: {
            withAnimation {
                viewModel.markItemAsDone(.tipOfTheDay, for: selectedDate, in: modelContext)
            }
        }) {
            TipOfTheDayModal(isPresented: $showingTipModal)
                .dsSheetPresentation(detents: [.medium])
        }
        .sheet(item: $selectedExercise, onDismiss: {
            refreshNonce &+= 1
        }) { exercise in
            NavigationStack {
                ExerciseDetailView(exercise: exercise)
            }
            .dsSheetPresentation()
        }
        .sheet(item: $selectedToolkitExercise, onDismiss: {
            toolkitRefreshToken &+= 1
        }) { exercise in
            NavigationStack {
                ExerciseDetailView(exercise: exercise)
            }
            .dsSheetPresentation()
        }
        .sheet(item: $selectedContinueRoute, onDismiss: {
            refreshNonce &+= 1
        }) { routeSheet in
            NavigationStack {
                TimelineRouteDestinationView(route: routeSheet.route)
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingActivityPlanner, onDismiss: {
            refreshNonce &+= 1
        }) {
            NavigationStack {
                ActivityPlannerView()
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingIntroToCBT) {
            NavigationStack {
                WhatIsCBTPagerView()
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingSafetySupport) {
            NavigationStack {
                SafetyPlanView()
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingValuesSetup, onDismiss: {
            refreshNonce &+= 1
        }) {
            NavigationStack {
                ValuesSelectionView()
            }
            .dsSheetPresentation()
        }
        .sheet(isPresented: $showingWeeklyReview, onDismiss: {
            refreshNonce &+= 1
        }) {
            NavigationStack {
                WeeklyReviewView()
            }
            .dsSheetPresentation()
        }
        .onChange(of: showingNewMoodEntry) { _, isPresented in
            guard !isPresented else { return }
            refreshNonce &+= 1
        }
        .onChange(of: showingNewThoughtRecord) { _, isPresented in
            guard !isPresented else { return }
            refreshNonce &+= 1
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            refreshNonce &+= 1
        }
        .task(id: DashboardRefreshToken(
            day: calendar.startOfDay(for: selectedDate),
            nonce: refreshNonce
        )) {
            await refreshDashboard()
        }
        .withUsageGate(isAttemptingAction: $attemptingNewMoodEntry) {
            showingNewMoodEntry = true
        }
        .withUsageGate(isAttemptingAction: $attemptingNewThoughtRecord) {
            showingNewThoughtRecord = true
        }
        .confirmationDialog(
            String(localized: "Add a gentle reminder?"),
            isPresented: $showingRecoveryReminderPrompt,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Remind me gently")) {
                streakReengagementReminderEnabled = true
                Task {
                    await PersonalizedReminderService.shared.refreshDailyMoodCheckInReminderIfEnabled()
                }
            }
            Button(String(localized: "Not now"), role: .cancel) {}
        } message: {
            Text(String(localized: "A small reminder can help tomorrow feel easier. You can change this anytime in Settings."))
        }
        .onKeyPress(".") {
            toggleManualItems()
            return .handled
        }
    }

    @MainActor
    private func refreshDashboard() async {
        AchievementService.shared.evaluateAchievements(in: modelContext)

        let lastOpenedAt = currentSessionLastHomeVisit()
        let snapshot = LaunchSafeFetch.homeDashboardSnapshot(
            selectedDate: selectedDate,
            visibleDates: Self.dashboardWeekDates,
            from: modelContext
        )
        let recommendations = DailyRecommendationService.shared.primaryRecommendations(
            from: modelContext,
            lastOpenedAt: lastOpenedAt
        )
        journeyStatus = FirstSevenDaysJourneyService.shared.status(from: modelContext)
        continueItem = ContinueItemService.shared.bestItem(
            from: modelContext,
            recommendations: recommendations
        )
        triggerLibrary = PersonalizedTriggerLibraryService.snapshot(
            moodEntries: LaunchSafeFetch.moodEntries(from: modelContext),
            moodCheckIns: LaunchSafeFetch.moodCheckIns(from: modelContext),
            thoughtRecords: LaunchSafeFetch.thoughtRecords(from: modelContext),
            journalEntries: LaunchSafeFetch.journalEntries(from: modelContext),
            flexibleJournalEntries: LaunchSafeFetch.flexibleJournalEntries(from: modelContext),
            exerciseCompletions: LaunchSafeFetch.exerciseCompletions(from: modelContext),
            referenceDate: Date(),
            calendar: calendar
        )

        await viewModel.apply(
            snapshot: snapshot,
            selectedDate: selectedDate,
            recommendations: recommendations
        )

        recordDailyPlanRetentionEvents()
        if recoveryState != nil {
            logRecoveryViewIfNeeded()
        }
        recordHomeVisitIfNeeded()
    }

    @MainActor
    private func toggleManualItems() {
        guard let item = heroItems.first(where: { !viewModel.completionSnapshot.state(for: $0).isCompleted }) else {
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            viewModel.markItemAsDone(
                item,
                for: selectedDate,
                in: modelContext,
                sourceScreen: "HomeShortcut"
            )
            refreshNonce &+= 1
        }
        HapticManager.shared.selection()
    }

    private func recordDailyPlanRetentionEvents() {
        let completedCount = heroItems.filter { viewModel.completionSnapshot.state(for: $0).isCompleted }.count
        guard completedCount > 0 else { return }

        LocalRetentionEventStore.shared.recordOnce(
            .firstDailyPlanItemCompleted,
            sourceScreen: "daily_plan",
            metadata: ["completed_count": "\(completedCount)"]
        )

        guard completedCount >= heroItems.count, !heroItems.isEmpty else { return }
        let dayKey = DailyPlanRetentionDayKey.key(for: selectedDate, calendar: calendar)
        guard lastRetentionDailyPlanCompletedDay != dayKey else { return }
        lastRetentionDailyPlanCompletedDay = dayKey
        LocalRetentionEventStore.shared.record(
            .dailyPlanCompleted,
            sourceScreen: "daily_plan",
            metadata: ["completed_count": "\(completedCount)"]
        )
    }

    private func logRecoveryViewIfNeeded() {
        guard !hasLoggedRecoveryView else { return }
        hasLoggedRecoveryView = true
        Self.logger.info("Local retention event: welcome_back_recovery_viewed")
        LocalRetentionEventStore.shared.record(
            .welcomeBackRecoveryViewed,
            sourceScreen: "home",
            metadata: ["missedDays": "\(viewModel.badDayContext.missedDays)"]
        )
    }

    private func currentSessionLastHomeVisit() -> Date? {
        if let sessionLastHomeVisit {
            return sessionLastHomeVisit
        }

        guard lastHomeVisitInterval > 0 else {
            return nil
        }

        let storedDate = Date(timeIntervalSince1970: lastHomeVisitInterval)
        sessionLastHomeVisit = storedDate
        return storedDate
    }

    private func recordHomeVisitIfNeeded() {
        guard !hasRecordedHomeVisit else { return }
        hasRecordedHomeVisit = true
        lastHomeVisitInterval = Date().timeIntervalSince1970
    }

    private func performRecommendation(_ recommendation: DailyRecommendation) {
        perform(destination: recommendation.destination)
    }

    private func performPersonalizedAction(_ action: HomePersonalizedCardAction) {
        switch action {
        case .moodCheckIn:
            attemptingNewMoodEntry = true
        case .thoughtRecord:
            attemptingNewThoughtRecord = true
        case .breathingReset:
            presentBreathingReset(durationSeconds: 60)
        case .journal:
            selectedTab = .journal
        case .exercises:
            selectedTab = .exercises
        case .insights:
            selectedTab = .insights
        case .assessments:
            selectedTab = .assessments
        case .recommendation(let destination):
            perform(destination: destination)
        }
    }

    private func perform(continueItem: ContinueItem) {
        switch continueItem.destination {
        case .dailyPlan(let destination):
            perform(destination: destination)
        case .thoughtRecord(let id):
            selectedContinueRoute = ContinueRouteSheet(route: .thought(id))
        case .guidedJournal:
            selectedTab = .journal
        case .exercise(let exerciseID):
            if let exercise = LibraryService.shared.exercise(withID: exerciseID) {
                selectedExercise = exercise
            } else {
                selectedTab = .exercises
            }
        case .course, .cbtPath:
            selectedTab = .exercises
        case .assessment:
            selectedTab = .assessments
        case .activityPlanner:
            showingActivityPlanner = true
        }
    }

    private func perform(destination: DailyRecommendationDestination) {
        switch destination {
        case .moodCheckIn:
            attemptingNewMoodEntry = true
        case .thoughtRecord:
            attemptingNewThoughtRecord = true
        case .breathingReset(let durationSeconds):
            presentBreathingReset(durationSeconds: durationSeconds)
        case .behavioralActivation:
            showingActivityPlanner = true
        case .weeklyReview:
            showingWeeklyReview = true
        case .libraryExercise(let exerciseID):
            if let exercise = LibraryService.shared.exercise(withID: exerciseID) {
                selectedExercise = exercise
            } else {
                selectedTab = .exercises
            }
        case .guidedJournal(_):
            selectedTab = .journal
        case .introToCBT:
            showingIntroToCBT = true
        case .course(_), .program(_):
            selectedTab = .exercises
        case .assessments:
            selectedTab = .assessments
        case .safetySupport:
            AchievementService.shared.recordBadDayModeUsed(in: modelContext)
            showingSafetySupport = true
        }
    }

    private func perform(triggerTool: TriggerToolRecommendation) {
        switch triggerTool.kind {
        case .exercise, .libraryItem:
            if let exercise = LibraryService.shared.exercise(withID: triggerTool.destinationID) {
                selectedExercise = exercise
            } else {
                selectedTab = .exercises
            }
        case .course, .cbtPath:
            selectedTab = .exercises
        }
    }

    private func completeRecovery(_ action: WelcomeBackRecoveryAction) {
        recoveryCompletedDayKey = WelcomeBackRecoveryState.completedDayKey(
            after: action,
            on: selectedDate,
            calendar: calendar
        )
        Self.logger.info("Local retention event: welcome_back_recovery_completed")
        LocalRetentionEventStore.shared.record(
            .welcomeBackRecoveryCompleted,
            sourceScreen: "home",
            metadata: ["action": "\(action)"]
        )
        HapticManager.shared.success()

        if !streakReengagementReminderEnabled {
            showingRecoveryReminderPrompt = true
        }

        switch action {
        case .resumePreviousPlan:
            if let continueItem {
                perform(continueItem: continueItem)
            } else if let recommendation = dailyPlanRecommendations.first {
                performRecommendation(recommendation)
            }
        case .startFreshToday:
            attemptingNewMoodEntry = true
        case .restartMomentum:
            presentBreathingReset(durationSeconds: 60)
        }
    }

    private func presentBreathingReset(durationSeconds: Int) {
        BreathingPresenter.shared.present(
            durationSeconds: durationSeconds,
            autoStart: true,
            onComplete: {
                withAnimation {
                    viewModel.markItemAsDone(
                        .breathingReset,
                        for: selectedDate,
                        in: modelContext,
                        durationSeconds: durationSeconds
                    )
                }
                refreshNonce &+= 1
            }
        )
    }

    private var copingToolkitHomeSection: some View {
        let favorites = toolkitFavorites
        let recent = recentlyUsedToolkitTools.filter { tool in
            !favorites.contains(where: { $0.id == tool.id })
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                HomeSectionHeader(
                    title: "Coping Toolkit",
                    subtitle: "Fast tools for emotional regulation."
                )

                Spacer(minLength: 8)

                Button {
                    selectedTab = .exercises
                } label: {
                    Image(systemName: "arrow.up.right")
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .icon(34), expands: false, tint: themeManager.selectedColor, hapticType: .light))
                .accessibilityLabel("Open Coping Toolkit")
            }

            if favorites.isEmpty && recent.isEmpty {
                CopingToolkitMiniRow(
                    tool: CopingToolkitService.shared.filteredTools(for: .quickReset).first,
                    label: "Quick reset",
                    onOpen: openToolkitTool
                )
            } else {
                if !favorites.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(favorites) { tool in
                            CopingToolkitMiniRow(tool: tool, label: "Favorite", onOpen: openToolkitTool)
                        }
                    }
                }

                if !recent.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(recent) { tool in
                            CopingToolkitMiniRow(tool: tool, label: "Recent", onOpen: openToolkitTool)
                        }
                    }
                }
            }
        }
    }

    private func openToolkitTool(_ tool: CopingToolkitTool?) {
        guard let tool else {
            selectedTab = .exercises
            return
        }

        let store = CopingToolkitStore()
        store.recordUsage(tool.id)
        toolkitRefreshToken &+= 1

        switch tool.destination {
        case .breathing(let seconds):
            presentBreathingReset(durationSeconds: seconds)
        case .exercise(let id):
            selectedToolkitExercise = ExerciseService.shared.exercise(withID: id)
        case .safety:
            showingSafetySupport = true
        }
    }

    private var tomorrowAnchor: TomorrowAnchor? {
        TomorrowAnchor(rawValue: tomorrowAnchorID)
    }

    private var tomorrowAnchorDate: Date? {
        guard tomorrowAnchorUpdatedAt > 0 else { return nil }
        return Date(timeIntervalSince1970: tomorrowAnchorUpdatedAt)
    }

    private var pickedResetYesterday: Bool {
        guard tomorrowAnchor == .breathing, let tomorrowAnchorDate else { return false }
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: selectedDate) else { return false }
        return calendar.isDate(tomorrowAnchorDate, inSameDayAs: yesterday)
    }

    private func saveTomorrowAnchor(_ anchor: TomorrowAnchor) {
        HapticManager.shared.selection()
        withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
            tomorrowAnchorID = anchor.rawValue
            tomorrowAnchorUpdatedAt = Date().timeIntervalSince1970
        }
        Task {
            await PersonalizedReminderService.shared.refreshDailyMoodCheckInReminderIfEnabled()
        }
    }

    @MainActor
    private func completeTinyWin(_ win: TinyWin) {
        do {
            _ = try TinyWinService.complete(
                win: win,
                on: selectedDate,
                in: modelContext,
                calendar: calendar
            )
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                viewModel.markItemAsDone(
                    .tinyWin,
                    for: selectedDate,
                    in: modelContext,
                    itemID: win.id
                )
                refreshNonce &+= 1
            }
            HapticManager.shared.success()
        } catch {
            HomeDashboardContent.logger.error("Failed to complete Tiny Win")
        }
    }

    private var valueActionIsCompleted: Bool {
        guard let action = ValuesService.action(
            for: selectedDate,
            selectedValues: personalValues,
            calendar: calendar
        ) else {
            return false
        }

        return ValuesService.isCompleted(
            action: action,
            on: selectedDate,
            completions: valueActionCompletions,
            calendar: calendar
        )
    }

    @MainActor
    private func completeValueAction(_ action: ValueTinyAction) {
        do {
            _ = try ValuesService.complete(
                action: action,
                on: selectedDate,
                in: modelContext,
                calendar: calendar
            )
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                viewModel.markItemAsDone(
                    .valueAction,
                    for: selectedDate,
                    in: modelContext,
                    itemID: action.id
                )
                refreshNonce &+= 1
            }
            HapticManager.shared.success()
        } catch {
            HomeDashboardContent.logger.error("Failed to complete value action")
        }
    }
}

private enum DailyPlanRetentionDayKey {
    static func key(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}

private struct ContinueRouteSheet: Identifiable {
    let route: TimelineRoute

    var id: TimelineRoute { route }
}

private struct ValueActionHomeCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let action: ValueTinyAction?
    let isCompleted: Bool
    let onComplete: (ValueTinyAction) -> Void
    let onChooseValues: () -> Void

    private var accent: Color {
        isCompleted ? Theme.successGreen : themeManager.selectedColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "star.circle.fill")
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: [accent, themeManager.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Act on one value today")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let action {
                VStack(alignment: .leading, spacing: 6) {
                    Text(action.valueName)
                        .font(.system(.caption, design: .rounded).weight(.black))
                        .foregroundStyle(accent)
                        .textCase(.uppercase)

                    Text(action.title)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            footer
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DSTheme.cardBackground)
                .overlay {
                    LinearGradient(
                        colors: [
                            accent.opacity(colorScheme == .dark ? 0.16 : 0.08),
                            themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.1 : 0.04),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(accent.opacity(0.16), lineWidth: 1)
                }
        }
        .shadow(
            color: accent.opacity(colorScheme == .dark ? 0.14 : 0.05),
            radius: colorScheme == .dark ? 16 : 8,
            x: 0,
            y: colorScheme == .dark ? 10 : 5
        )
    }

    private var subtitle: String {
        if action == nil {
            return "Choose a few values, then the app can suggest one tiny action each day."
        }
        if isCompleted {
            return "You practiced this value today."
        }
        return "A small action can keep what matters visible."
    }

    @ViewBuilder
    private var footer: some View {
        if let action {
            if isCompleted {
                Label("Done for today", systemImage: "checkmark.circle.fill")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.successGreen)
            } else {
                Button {
                    HapticManager.shared.selection()
                    onComplete(action)
                } label: {
                    Label("Mark as done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSButtonStyle(variant: .primary, size: .compact, tint: accent, hapticType: nil))
            }
        } else {
            Button {
                HapticManager.shared.selection()
                onChooseValues()
            } label: {
                Label("Choose values", systemImage: "star")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSButtonStyle(variant: .primary, size: .compact, tint: accent, hapticType: nil))
        }
    }
}

private struct WelcomeBackRecoveryCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let state: WelcomeBackRecoveryState
    let onResumePreviousPlan: () -> Void
    let onStartFreshToday: () -> Void
    let onRestartMomentum: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [themeManager.selectedColor, Theme.successGreen],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Welcome back"))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    Text(String(localized: "You do not need to catch up. A small step today is enough."))
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                RecoveryInfoRow(systemImage: "sparkle", text: state.tinyActionSuggestion)

                if let gentleStreakMessage = state.gentleStreakMessage {
                    RecoveryInfoRow(systemImage: "leaf.fill", text: gentleStreakMessage)
                }

                RecoveryInfoRow(
                    systemImage: "flag.checkered",
                    text: String(localized: "Restart momentum: one tiny action today.")
                )
            }

            VStack(spacing: 10) {
                Button(action: onStartFreshToday) {
                    Label(String(localized: "Start fresh today"), systemImage: "sun.max.fill")
                }
                .buttonStyle(DSButtonStyle(variant: .primary, size: .medium, tint: themeManager.selectedColor))

                HStack(spacing: 10) {
                    Button(action: onResumePreviousPlan) {
                        Label(String(localized: "Resume plan"), systemImage: "arrow.uturn.right")
                    }
                    .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, tint: themeManager.selectedColor))

                    Button(action: onRestartMomentum) {
                        Label(String(localized: "One-minute reset"), systemImage: "timer")
                    }
                    .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, tint: Theme.successGreen))
                }
            }
        }
        .padding(Theme.paddingLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                .fill(DSTheme.cardBackground)
                .overlay {
                    LinearGradient(
                        colors: [
                            themeManager.selectedColor.opacity(colorScheme == .dark ? 0.16 : 0.08),
                            Theme.successGreen.opacity(colorScheme == .dark ? 0.12 : 0.06),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
                }
                .shadow(
                    color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.14 : 0.06),
                    radius: colorScheme == .dark ? 16 : 10,
                    x: 0,
                    y: colorScheme == .dark ? 8 : 5
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                .strokeBorder(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct RecoveryInfoRow: View {
    let systemImage: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.successGreen)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(text)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct FirstSevenDaysJourneyHomeCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let status: FirstSevenDaysJourneyStatus
    let action: (FirstSevenDaysJourneyStep) -> Void

    var body: some View {
        switch status.state {
        case .empty:
            EmptyView()
        case .active, .missedDay, .completed:
            card
        }
    }

    @ViewBuilder
    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(iconColor)
                    .frame(width: 38, height: 38)
                    .background(iconColor.opacity(colorScheme == .dark ? 0.22 : 0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            ProgressView(value: Double(status.completedCount), total: Double(max(status.totalCount, 1)))
                .tint(iconColor)
                .accessibilityLabel("\(status.completedCount) of \(status.totalCount) starter journey steps complete")

            if let step = status.currentStep {
                Button {
                    HapticManager.shared.selection()
                    action(step)
                } label: {
                    Label(actionTitle(for: step), systemImage: "arrow.right.circle.fill")
                }
                .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, tint: iconColor))
            }
        }
        .padding(16)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                .strokeBorder(iconColor.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch status.state {
        case .empty:
            return ""
        case .active:
            guard let step = status.currentStep else { return "First 7 Days" }
            return "First 7 Days: Day \(step.day)"
        case .missedDay:
            return "Continue Your First 7 Days"
        case .completed:
            return "First 7 Days Complete"
        }
    }

    private var subtitle: String {
        switch status.state {
        case .empty:
            return ""
        case .active:
            return status.currentStep?.subtitle ?? "One small starter step is ready."
        case .missedDay:
            return "No catching up needed. Pick up with the next step when it fits today."
        case .completed:
            return "You tried the starter path. Your regular Daily Plan is ready to keep supporting you."
        }
    }

    private var iconName: String {
        switch status.state {
        case .completed:
            return "checkmark.seal.fill"
        case .missedDay:
            return "arrow.counterclockwise.circle.fill"
        case .empty, .active:
            return "sparkles"
        }
    }

    private var iconColor: Color {
        switch status.state {
        case .completed:
            return Theme.successGreen
        default:
            return themeManager.selectedColor
        }
    }

    private func actionTitle(for step: FirstSevenDaysJourneyStep) -> String {
        "Open Day \(step.day)"
    }
}

private struct CopingToolkitMiniRow: View {
    @Environment(ThemeManager.self) private var themeManager

    let tool: CopingToolkitTool?
    let label: String
    let onOpen: (CopingToolkitTool?) -> Void

    var body: some View {
        Button {
            onOpen(tool)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: tool?.systemImage ?? "lifepreserver")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tool?.title ?? "Open Toolkit")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(tool.map { "\(label) - \($0.durationLabel)" } ?? "Choose a tool for this moment")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                }

                Spacer()
                Image(systemName: "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(Theme.toggleBackgroundColor(for: .light))
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TodayBestNextStepCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let recommendation: DailyRecommendation
    let explanation: String
    let completionState: PlanCardCompletionState
    let isPlanComplete: Bool
    let action: () -> Void

    private var accent: Color {
        completionState.isCompleted ? Theme.successGreen : themeManager.selectedColor
    }

    private var statusText: String {
        if isPlanComplete {
            return String(localized: "Optional")
        }
        if completionState.isCompleted {
            return String(localized: "Done")
        }
        return recommendation.durationLabel
    }

    private var actionTitle: String {
        if isPlanComplete {
            return String(localized: "Open")
        }
        switch recommendation.type {
        case .moodCheckIn:
            return String(localized: "Check in")
        case .thoughtRecord:
            return String(localized: "Start")
        case .breathingReset, .sleepWindDown:
            return String(localized: "Reset")
        case .behavioralActivation:
            return String(localized: "Plan")
        case .guidedJournal:
            return String(localized: "Write")
        case .libraryExercise, .courseLesson:
            return String(localized: "Practice")
        case .safetySupport:
            return String(localized: "Open")
        }
    }

    var body: some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: recommendation.icon)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(
                            LinearGradient(
                                colors: [accent, themeManager.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(String(localized: "Today's Best Next Step"))
                            .font(.system(.caption, design: .rounded).weight(.black))
                            .textCase(.uppercase)
                            .foregroundStyle(accent)

                        Text(recommendation.title)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(recommendation.subtitle)
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text(statusText)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundStyle(accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(accent.opacity(colorScheme == .dark ? 0.18 : 0.1), in: Capsule())
                }

                Text(explanation)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Text(actionTitle)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 17, weight: .bold))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [accent, themeManager.secondaryColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DSTheme.cardBackground)
                    .overlay {
                        LinearGradient(
                            colors: [
                                accent.opacity(colorScheme == .dark ? 0.18 : 0.09),
                                themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.12 : 0.05),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(accent.opacity(0.16), lineWidth: 1)
                    }
            }
            .shadow(
                color: accent.opacity(colorScheme == .dark ? 0.16 : 0.06),
                radius: colorScheme == .dark ? 18 : 10,
                x: 0,
                y: colorScheme == .dark ? 10 : 6
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's Best Next Step. \(recommendation.title). \(recommendation.subtitle). \(explanation)")
        .accessibilityHint(String(localized: "Tap to open"))
    }
}

private struct HomePersonalizedCardView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let card: HomePersonalizedCard
    let action: () -> Void

    private var accent: Color {
        card.isPriority ? themeManager.selectedColor : secondaryAccent
    }

    private var secondaryAccent: Color {
        switch card.id {
        case .restart:
            return Theme.successGreen
        case .weeklyProgress:
            return themeManager.secondaryColor
        default:
            return themeManager.selectedColor
        }
    }

    var body: some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: card.systemImage)
                    .font(.system(size: 17, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: [accent, themeManager.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(card.title)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(card.subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = card.detail, !detail.isEmpty {
                        Text(detail)
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(Theme.tertiaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(card.actionTitle)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(accent.opacity(0.1), in: Capsule())
            }
            .padding(Theme.paddingMedium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                    .fill(DSTheme.cardBackground)
                    .overlay {
                        LinearGradient(
                            colors: [
                                accent.opacity(colorScheme == .dark ? 0.16 : 0.08),
                                themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.1 : 0.04),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous))
                    }
                    .shadow(
                        color: accent.opacity(colorScheme == .dark ? 0.14 : 0.05),
                        radius: colorScheme == .dark ? 14 : 8,
                        x: 0,
                        y: colorScheme == .dark ? 8 : 4
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadiusMedium, style: .continuous)
                    .strokeBorder(accent.opacity(0.14), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(card.title). \(card.subtitle)")
        .accessibilityHint(String(localized: "Tap to open"))
    }
}

private struct TinyWinHomeCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let state: TinyWinCardState
    let action: (TinyWin) -> Void

    private var win: TinyWin? {
        switch state {
        case .empty:
            return nil
        case .available(let win), .completed(let win), .missed(let win):
            return win
        }
    }

    private var isCompleted: Bool {
        if case .completed = state { return true }
        return false
    }

    private var isMissed: Bool {
        if case .missed = state { return true }
        return false
    }

    private var accent: Color {
        if isCompleted { return Theme.successGreen }
        if isMissed { return Theme.tertiaryText }
        return themeManager.selectedColor
    }

    private var statusText: String {
        switch state {
        case .empty:
            return String(localized: "Tiny Wins are unavailable right now.")
        case .available:
            return String(localized: "A tiny practice, not treatment.")
        case .completed:
            return String(localized: "Completed for this day.")
        case .missed:
            return String(localized: "Missed for this day. Choose today for a fresh Tiny Win.")
        }
    }

    private var iconName: String {
        if isCompleted { return "checkmark.circle.fill" }
        if isMissed { return "clock.badge.exclamationmark" }
        return win?.systemImage ?? "sparkle"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: [accent, themeManager.secondaryColor.opacity(isMissed ? 0.65 : 1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "Tiny Win"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)

                    Text(win?.title ?? String(localized: "Nothing queued"))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(statusText)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let win {
                Text(win.prompt)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            footer
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DSTheme.cardBackground)
                .overlay {
                    LinearGradient(
                        colors: [
                            accent.opacity(colorScheme == .dark ? 0.16 : 0.08),
                            themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.1 : 0.04),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(accent.opacity(0.16), lineWidth: 1)
                }
        }
        .shadow(
            color: accent.opacity(colorScheme == .dark ? 0.14 : 0.05),
            radius: colorScheme == .dark ? 16 : 8,
            x: 0,
            y: colorScheme == .dark ? 10 : 5
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var footer: some View {
        switch state {
        case .empty:
            Label(String(localized: "Empty"), systemImage: "tray")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)
        case .available(let win):
            Button {
                HapticManager.shared.selection()
                action(win)
            } label: {
                Label(win.actionTitle, systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSButtonStyle(variant: .primary, size: .compact, tint: accent, hapticType: nil))
            .accessibilityHint(String(localized: "Marks this Tiny Win complete"))
        case .completed:
            Label(String(localized: "Done"), systemImage: "checkmark.circle.fill")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.successGreen)
        case .missed:
            Label(String(localized: "Missed"), systemImage: "clock")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)
        }
    }
}

private struct CopingPlanHomeCard: View {
    @Environment(ThemeManager.self) private var themeManager

    let action: () -> Void

    var body: some View {
        Button {
            HapticManager.shared.selection()
            action()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "lifepreserver.fill")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 42, height: 42)
                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Rough Patch Plan"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text(String(localized: "Warning signs, helpful actions, contacts, and reminders."))
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(16)
            .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Open Rough Patch Plan"))
    }
}

private struct BadDayModeShortcutCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let context: BadDayModeContext
    let action: () -> Void

    private var subtitle: String {
        switch context.trigger {
        case .missedDays:
            return String(localized: "No catching up. Pick one small reset for today.")
        case .veryLowMood:
            return String(localized: "A softer set of options is ready when the day feels heavy.")
        case .manual, nil:
            return String(localized: "A softer set of options for low-energy days.")
        }
    }

    var body: some View {
        Button {
            HapticManager.shared.mediumImpact()
            action()
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: [themeManager.selectedColor, themeManager.secondaryColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Bad Day Mode"))
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    Text(subtitle)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(DSTheme.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
                    }
            }
            .shadow(
                color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.12 : 0.04),
                radius: colorScheme == .dark ? 14 : 8,
                x: 0,
                y: colorScheme == .dark ? 9 : 5
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Bad Day Mode")
    }
}

private struct MakeTodayEasierCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let context: BadDayModeContext
    let onBreathingReset: () -> Void
    let onMoodCheckIn: () -> Void
    let onGrounding: () -> Void
    let onSafetySupport: () -> Void

    private var subtitle: String {
        switch context.trigger {
        case .missedDays:
            return String(localized: "No catching up today. Pick one tiny support step.")
        case .veryLowMood:
            return String(localized: "The full plan can wait. Choose a one-minute option.")
        case .manual, nil:
            return String(localized: "Use the softer path when today asks for less.")
        }
    }

    private var supportTone: Color {
        colorScheme == .dark ? Theme.warningOrange.opacity(0.92) : Theme.warningOrange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(
                        LinearGradient(
                            colors: [themeManager.selectedColor, supportTone],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Make today easier"))
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ],
                spacing: 8
            ) {
                easierDayButton(
                    title: String(localized: "Breathe"),
                    subtitle: String(localized: "1 min"),
                    systemImage: "wind",
                    action: onBreathingReset
                )

                easierDayButton(
                    title: String(localized: "Name mood"),
                    subtitle: String(localized: "1 min"),
                    systemImage: "face.smiling",
                    action: onMoodCheckIn
                )

                easierDayButton(
                    title: String(localized: "Ground here"),
                    subtitle: String(localized: "5 senses"),
                    systemImage: "hand.raised.fill",
                    action: onGrounding
                )

                easierDayButton(
                    title: String(localized: "Need support"),
                    subtitle: String(localized: "Plan"),
                    systemImage: "cross.case.fill",
                    action: onSafetySupport
                )
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                .fill(DSTheme.cardBackground)
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous)
                        .strokeBorder(themeManager.selectedColor.opacity(0.2), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .contain)
    }

    private func easierDayButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.lightImpact()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .padding(.horizontal, 10)
            .background(Theme.toggleBackgroundColor(for: .light), in: RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}

private struct BadDayModeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeManager.self) private var themeManager
    @Query(sort: \SafetyPlan.updatedAt, order: .reverse) private var safetyPlans: [SafetyPlan]

    @State private var journalText = ""
    @State private var savedJournal = false
    @State private var restartedToday = false
    @State private var completedGroundingSteps = Set<Int>()
    @State private var showingSafetySupport = false
    @State private var errorMessage: String?

    private var activePlan: SafetyPlan? {
        safetyPlans.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        needHelpNowCard
                        roughPatchPlanSection
                        quickOptions
                        restartSection

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.system(.caption, design: .rounded).weight(.medium))
                                .foregroundStyle(Theme.warningOrange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(20)
                    .responsiveMaxWidth()
                }
            }
            .navigationTitle("Bad Day Mode")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $showingSafetySupport) {
                NavigationStack {
                    SafetyPlanView()
                }
                .dsSheetPresentation()
            }
        }
    }

    private var needHelpNowCard: some View {
        NeedHelpNowCard(
            message: String(localized: "Open your rough patch plan before things build further. If you might be in immediate danger, contact local emergency services now. In the U.S. you can call or text 988 for crisis support.")
        ) {
            showingSafetySupport = true
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "Bad Day Mode"), systemImage: "heart.circle.fill")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            Text(String(localized: "Some days ask for less. You do not need to catch up or explain anything. Choose one small thing that feels possible right now."))
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var quickOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Quick Options"))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .textCase(.uppercase)
                .foregroundStyle(Theme.secondaryText)

            Button {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    BreathingPresenter.shared.present(durationSeconds: 60, autoStart: true)
                }
            } label: {
                Label(String(localized: "Breathing Reset"), systemImage: "wind")
            }
            .buttonStyle(DSPrimaryButtonStyle())

            groundingExercise
            oneSentenceJournal
        }
    }

    @ViewBuilder
    private var roughPatchPlanSection: some View {
        if let activePlan {
            RoughPatchPlanSummaryCard(plan: activePlan)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label(String(localized: "Rough Patch Plan"), systemImage: "lifepreserver.fill")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)

                Text(String(localized: "Save warning signs, helpful actions, trusted contacts, grounding steps, and reminders so they are ready when you start slipping."))
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink {
                    SafetyPlanView()
                } label: {
                    Label(String(localized: "Create Plan"), systemImage: "plus.circle.fill")
                }
                .buttonStyle(DSSecondaryButtonStyle())
            }
            .padding(16)
            .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private var groundingExercise: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "Grounding Exercise"), systemImage: "hand.raised.fill")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            Text(String(localized: "Notice one thing you can see, feel, hear, smell, and taste. Tap each line when you have named it."))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(Array(["See", "Feel", "Hear", "Smell", "Taste"].enumerated()), id: \.offset) { index, label in
                Button {
                    if completedGroundingSteps.contains(index) {
                        completedGroundingSteps.remove(index)
                    } else {
                        completedGroundingSteps.insert(index)
                    }
                } label: {
                    HStack {
                        Image(systemName: completedGroundingSteps.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(completedGroundingSteps.contains(index) ? themeManager.selectedColor : Theme.secondaryText)
                        Text(label)
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var oneSentenceJournal: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "One-Sentence Journal"), systemImage: "square.and.pencil")
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            TextField(String(localized: "One sentence about right now"), text: $journalText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)

            Button {
                saveOneSentenceJournal()
            } label: {
                Label(
                    savedJournal ? String(localized: "Saved") : String(localized: "Save Sentence"),
                    systemImage: savedJournal ? "checkmark.circle.fill" : "tray.and.arrow.down.fill"
                )
            }
            .buttonStyle(DSSecondaryButtonStyle())
            .disabled(journalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(16)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var restartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Restart Today"))
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            Text(String(localized: "This records today as a fresh check-in. It does not change older entries or rewrite past streak days."))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                restartToday()
            } label: {
                Label(
                    restartedToday ? String(localized: "Today Restarted") : String(localized: "Restart Today"),
                    systemImage: restartedToday ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill"
                )
            }
            .buttonStyle(DSSecondaryButtonStyle())
            .disabled(restartedToday)
        }
        .padding(16)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func saveOneSentenceJournal() {
        let text = journalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        do {
            try modelContext.cbtStore.insertJournalEntry(
                title: String(localized: "Bad Day Mode"),
                body: text,
                sourceKind: "bad_day_mode",
                sourceID: "one_sentence",
                valueIDs: []
            )
            savedJournal = true
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Could not save that sentence. Please try again.")
        }
    }

    private func restartToday() {
        do {
            let now = Date()
            try modelContext.cbtStore.insertMoodEntry(
                createdAt: now,
                moodScore: BadDayModeService.restartTodayMoodScore,
                notes: BadDayModeService.restartTodayNote
            )
            let checkIn = MoodCheckIn(
                createdAt: now,
                moodScore: BadDayModeService.restartTodayMoodScore,
                notes: BadDayModeService.restartTodayNote
            )
            modelContext.insert(checkIn)
            try modelContext.save()
            AchievementService.shared.evaluateAchievements(in: modelContext)
            restartedToday = true
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "Could not restart today. Please try again.")
        }
    }
}

private struct RoughPatchPlanSummaryCard: View {
    let plan: SafetyPlan

    private var contacts: [EmergencyContact] {
        plan.emergencyContacts.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !$0.relationship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !$0.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 10) {
                Label(String(localized: "Rough Patch Plan"), systemImage: "lifepreserver.fill")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)

                Spacer(minLength: 8)

                NavigationLink {
                    SafetyPlanView()
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Edit Rough Patch Plan"))
            }

            PlanPreviewGroup(
                title: String(localized: "Warning Signs"),
                systemImage: "exclamationmark.triangle.fill",
                items: plan.personalWarningSigns,
                emptyText: String(localized: "No warning signs saved yet.")
            )

            PlanPreviewGroup(
                title: String(localized: "Helpful Actions"),
                systemImage: "hands.sparkles.fill",
                items: plan.copingStrategies,
                emptyText: String(localized: "No helpful actions saved yet.")
            )

            PlanPreviewGroup(
                title: String(localized: "Grounding Steps"),
                systemImage: "hand.raised.fill",
                items: plan.groundingSteps,
                emptyText: String(localized: "No grounding steps saved yet.")
            )

            if !contacts.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel(String(localized: "Trusted Contacts"), systemImage: "person.2.fill")
                    ForEach(contacts.prefix(2)) { contact in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(contact.name.isEmpty ? String(localized: "Trusted contact") : contact.name)
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Theme.primaryText)
                            Text(contactDetail(for: contact))
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Theme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            PlanPreviewGroup(
                title: String(localized: "Reminders"),
                systemImage: "quote.bubble.fill",
                items: plan.reminders,
                emptyText: String(localized: "No reminders saved yet.")
            )
        }
        .padding(16)
        .background(DSTheme.cardBackground, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func contactDetail(for contact: EmergencyContact) -> String {
        [contact.relationship, contact.phoneNumber]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " - ")
    }

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(Theme.secondaryText)
            .textCase(.uppercase)
    }
}

private struct PlanPreviewGroup: View {
    let title: String
    let systemImage: String
    let items: [String]
    let emptyText: String

    private var visibleItems: [String] {
        Array(
            items
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)
                .textCase(.uppercase)

            if visibleItems.isEmpty {
                Text(emptyText)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(visibleItems, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.successGreen)
                                .padding(.top, 1)
                            Text(item)
                                .font(.system(.subheadline, design: .rounded))
                                .foregroundStyle(Theme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
    }
}

private struct HomeWeeklyReviewCard: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 38, height: 38)
                .background(themeManager.selectedColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Weekly Review"))
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(Theme.primaryText)

                Text(String(localized: "Look back at check-ins, stress signals, tiny wins, and what helped."))
                    .font(DSTypography.caption)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(16)
        .background(DSTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct HomeRecentAchievementsCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let achievements: [Achievement]

    private var recentAchievements: [Achievement] {
        Array(
            achievements
                .filter(\.isUnlocked)
                .sorted {
                    ($0.unlockedAt ?? $0.createdAt) > ($1.unlockedAt ?? $1.createdAt)
                }
                .prefix(3)
        )
    }

    var body: some View {
        if !recentAchievements.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "rosette")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(themeManager.selectedColor)
                        .frame(width: 38, height: 38)
                        .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Recent Achievements"))
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(Theme.primaryText)

                        Text(String(localized: "Small signs of care you have already practiced."))
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(spacing: 8) {
                    ForEach(recentAchievements) { achievement in
                        HomeRecentAchievementRow(achievement: achievement)
                    }
                }
            }
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(DSTheme.cardBackground)
                    .overlay {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .strokeBorder(themeManager.selectedColor.opacity(0.12), lineWidth: 1)
                    }
            }
            .shadow(
                color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.12 : 0.04),
                radius: colorScheme == .dark ? 14 : 7,
                x: 0,
                y: colorScheme == .dark ? 8 : 4
            )
        }
    }
}

private struct HomeRecentAchievementRow: View {
    @Environment(ThemeManager.self) private var themeManager

    let achievement: Achievement

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: achievement.imageName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 30, height: 30)
                .background(themeManager.selectedColor.opacity(0.1), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(achievement.achievementDescription)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(achievement.title). \(achievement.achievementDescription)")
    }
}

private struct TomorrowAnchorCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let selectedAnchor: TomorrowAnchor?
    let updatedAt: Date?
    let onSelect: (TomorrowAnchor) -> Void

    private var statusText: String {
        guard let selectedAnchor else {
            return String(localized: "Pick one tiny thing to come back for tomorrow.")
        }

        if let updatedAt, Calendar.current.isDateInToday(updatedAt) {
            return String(localized: "\(selectedAnchor.title) is saved for tomorrow.")
        }

        return String(localized: "Your next anchor is \(selectedAnchor.title.lowercased()).")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    headerIcon
                    titleBlock
                    Spacer(minLength: 8)
                    savedBadge
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        headerIcon
                        titleBlock
                    }
                    savedBadge
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(TomorrowAnchor.allCases) { anchor in
                    TomorrowAnchorButton(
                        anchor: anchor,
                        isSelected: anchor == selectedAnchor
                    ) {
                        onSelect(anchor)
                    }
                }
            }

            if let selectedAnchor {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.uturn.forward.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(themeManager.selectedColor)
                        .padding(.top, 1)

                    Text(selectedAnchor.subtitle)
                        .font(.system(.caption, design: .rounded).weight(.medium))
                        .foregroundStyle(Theme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DSTheme.cardBackground)
                .overlay {
                    LinearGradient(
                        colors: [
                            themeManager.selectedColor.opacity(colorScheme == .dark ? 0.16 : 0.08),
                            themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.1 : 0.04),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
                }
        }
        .shadow(
            color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.14 : 0.05),
            radius: colorScheme == .dark ? 16 : 8,
            x: 0,
            y: colorScheme == .dark ? 10 : 5
        )
        .accessibilityElement(children: .contain)
    }

    private var headerIcon: some View {
        Image(systemName: selectedAnchor?.systemImage ?? "arrow.forward.circle.fill")
            .font(.system(size: 18, weight: .black))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(
                LinearGradient(
                    colors: [themeManager.selectedColor, themeManager.secondaryColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .accessibilityHidden(true)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Tomorrow's Anchor"))
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Text(statusText)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var savedBadge: some View {
        if selectedAnchor != nil {
            Label(String(localized: "Saved"), systemImage: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.successGreen)
                .lineLimit(1)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Theme.successGreen.opacity(0.1), in: Capsule())
        }
    }
}

private struct TomorrowAnchorButton: View {
    @Environment(ThemeManager.self) private var themeManager

    let anchor: TomorrowAnchor
    let isSelected: Bool
    let action: () -> Void

    private var accent: Color {
        isSelected ? Theme.successGreen : themeManager.selectedColor
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : anchor.systemImage)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 18)
                    .accessibilityHidden(true)

                Text(anchor.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(DSButtonStyle(variant: .secondary, size: .compact, tint: accent, hapticType: nil))
        .frame(minHeight: 44)
        .accessibilityLabel(isSelected ? "\(anchor.title), saved for tomorrow" : anchor.title)
    }
}

private struct HomeDashboardSkeleton: View {
    var body: some View {
        VStack(spacing: 16) {
            ForEach(0..<4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: DSCornerRadius.large, style: .continuous)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 100)
            }
        }
    }
}

private struct HomeHeroCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    let selectedDate: Date
    let completedCount: Int
    let totalCount: Int
    let activeDayCount: Int
    let progress: Double
    let animate: Bool

    private var accent: Color {
        themeManager.selectedColor
    }

    private var secondaryAccent: Color {
        themeManager.secondaryColor
    }

    private var dateLabel: String {
        if Calendar.current.isDateInToday(selectedDate) {
            return String(localized: "Today")
        }
        return selectedDate.formatted(.dateTime.weekday(.wide))
    }

    private var headline: String {
        if completedCount >= totalCount, totalCount > 0 {
            return String(localized: "Plan complete")
        }
        if completedCount == 0 {
            return String(localized: "Start with one small win")
        }
        return String(localized: "\(completedCount) of \(totalCount) wins banked")
    }

    private var subheadline: String {
        if completedCount >= totalCount, totalCount > 0 {
            return String(localized: "You showed up for your mind today. Let that count.")
        }
        let remaining = max(totalCount - completedCount, 0)
        return String(localized: "\(remaining) gentle steps left in your CBT rhythm.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 18) {
                    HomeHeroMedallion(accent: accent, secondaryAccent: secondaryAccent, animate: animate)
                    heroCopy
                }

                VStack(alignment: .leading, spacing: 16) {
                    HomeHeroMedallion(accent: accent, secondaryAccent: secondaryAccent, animate: animate)
                    heroCopy
                }
            }

            HomeProgressTrack(progress: progress, accent: .white, animate: animate)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    HomeHeroPill(icon: "checkmark.seal.fill", title: String(localized: "Done"), value: "\(completedCount)/\(totalCount)")
                    HomeHeroPill(icon: "sparkles", title: String(localized: "Active"), value: "\(activeDayCount)d")
                }

                VStack(spacing: 10) {
                    HomeHeroPill(icon: "checkmark.seal.fill", title: String(localized: "Done"), value: "\(completedCount)/\(totalCount)")
                    HomeHeroPill(icon: "sparkles", title: String(localized: "Active"), value: "\(activeDayCount)d")
                }
            }
        }
        .padding(22)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    #if canImport(UIKit)
                    .fill(Color(UIColor.systemBackground))
                    #elseif canImport(AppKit)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    #else
                    .fill(Color.black)
                    #endif
                    .shadow(
                        color: accent.opacity(colorScheme == .dark ? 0.32 : 0.18),
                        radius: colorScheme == .dark ? 26 : 18,
                        x: 0,
                        y: colorScheme == .dark ? 18 : 10
                    )

                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent,
                                secondaryAccent.opacity(colorScheme == .dark ? 0.95 : 0.9),
                                accent.opacity(colorScheme == .dark ? 0.72 : 0.82)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
                .overlay {
                    ZStack {
                        HomeHeroGlowPattern(animate: animate)

                        LinearGradient(
                            colors: [.white.opacity(0.28), .white.opacity(0.04), .clear],
                            startPoint: .topLeading,
                            endPoint: .center
                        )

                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                    }
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(dateLabel), \(headline). \(subheadline)")
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(selectedDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.15), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )

            Text(headline)
                .font(.system(size: 33, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            Text(subheadline)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HomeHeroMedallion: View {
    let accent: Color
    let secondaryAccent: Color
    let animate: Bool

    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: 88, height: 88)
                .scaleEffect(pulse && animate ? 1.1 : 0.94)
                .opacity(pulse && animate ? 0.25 : 0.55)

            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 72, height: 72)
                .overlay {
                    Circle()
                        .stroke(.white.opacity(0.3), lineWidth: 1)
                }

            Image(systemName: "checklist.checked")
                .font(.system(size: 34, weight: .black))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, secondaryAccent.opacity(0.85))
                .shadow(color: .white.opacity(0.35), radius: 10, x: 0, y: 0)
                .scaleEffect(pulse && animate ? 1.05 : 0.98)
        }
        .frame(width: 88, height: 88)
        .onAppear {
            updatePulse()
        }
        .onChange(of: animate) { _, _ in
            updatePulse()
        }
    }

    private func updatePulse() {
        guard animate else {
            pulse = false
            return
        }
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }
}

private struct HomeHeroGlowPattern: View {
    let animate: Bool
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Circle()
                    .fill(.white.opacity(0.16))
                    .frame(width: proxy.size.width * 0.72)
                    .blur(radius: 24)
                    .offset(
                        x: drift && animate ? proxy.size.width * 0.22 : proxy.size.width * 0.06,
                        y: drift && animate ? -proxy.size.height * 0.28 : -proxy.size.height * 0.18
                    )

                Circle()
                    .fill(.black.opacity(0.12))
                    .frame(width: proxy.size.width * 0.9)
                    .blur(radius: 34)
                    .offset(x: proxy.size.width * 0.42, y: proxy.size.height * 0.58)

                ForEach(0..<8, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(index.isMultiple(of: 2) ? 0.24 : 0.14))
                        .frame(width: CGFloat(4 + (index % 3) * 3))
                        .offset(
                            x: proxy.size.width * CGFloat([0.16, 0.35, 0.68, 0.82, 0.24, 0.53, 0.74, 0.9][index]),
                            y: proxy.size.height * CGFloat([0.18, 0.1, 0.22, 0.42, 0.68, 0.78, 0.62, 0.16][index])
                        )
                        .opacity(animate && drift ? 1 : 0.55)
                        .scaleEffect(animate && drift ? 1.2 : 0.85)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            updateDrift()
        }
        .onChange(of: animate) { _, _ in
            updateDrift()
        }
    }

    private func updateDrift() {
        guard animate else {
            drift = false
            return
        }
        withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
            drift = true
        }
    }
}

private struct HomeProgressTrack: View {
    let progress: Double
    let accent: Color
    let animate: Bool

    @State private var visibleProgress = 0.0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.2))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.58)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(10, proxy.size.width * visibleProgress))
                        .overlay(alignment: .trailing) {
                            Circle()
                                .fill(.white)
                                .frame(width: 14, height: 14)
                                .shadow(color: .white.opacity(0.45), radius: 8, x: 0, y: 0)
                                .padding(.trailing, 2)
                        }
                }
            }
            .frame(height: 12)

            HStack {
                Text(String(localized: "Daily rhythm"))
                Spacer()
                Text("\(Int((visibleProgress * 100).rounded()))%")
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.76))
        }
        .onAppear {
            updateProgress(progress)
        }
        .onChange(of: progress) { _, newValue in
            updateProgress(newValue)
        }
    }

    private func updateProgress(_ newValue: Double) {
        if animate {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.85)) {
                visibleProgress = newValue
            }
        } else {
            visibleProgress = newValue
        }
    }
}

private struct HomeHeroPill: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.72))

            Spacer(minLength: 4)

            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 1)
        }
    }
}

private struct HomeDateRailCard: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedDate: Date
    let weekDates: [Date]
    let dayHasActivity: (Date) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    headerTitle
                    Spacer()
                    activeLegend
                }

                VStack(alignment: .leading, spacing: 8) {
                    headerTitle
                    activeLegend
                }
            }

            WeekStripView(
                selectedDate: $selectedDate,
                weekDates: weekDates,
                dayHasActivity: dayHasActivity
            )
            .padding(.horizontal, -12)
            .padding(.bottom, -4)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 10)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(DSTheme.cardBackground)
                .overlay {
                    LinearGradient(
                        colors: [
                            themeManager.selectedColor.opacity(colorScheme == .dark ? 0.18 : 0.1),
                            themeManager.secondaryColor.opacity(colorScheme == .dark ? 0.12 : 0.06),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(themeManager.selectedColor.opacity(0.14), lineWidth: 1)
                }
        }
        .shadow(
            color: themeManager.selectedColor.opacity(colorScheme == .dark ? 0.16 : 0.06),
            radius: colorScheme == .dark ? 18 : 10,
            x: 0,
            y: colorScheme == .dark ? 12 : 6
        )
    }

    private var headerTitle: some View {
        Label(String(localized: "Choose your day"), systemImage: "calendar.badge.clock")
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.primaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
    }

    private var activeLegend: some View {
        Label(String(localized: "Active"), systemImage: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(themeManager.selectedColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct HomeSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            Text(subtitle)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 2)
    }
}

private struct HomeEntranceModifier: ViewModifier {
    let index: Int
    let isVisible: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.98)
            .animation(
                reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.86).delay(Double(index) * 0.08),
                value: isVisible
            )
    }
}

private extension View {
    func homeEntrance(index: Int, isVisible: Bool, reduceMotion: Bool) -> some View {
        modifier(HomeEntranceModifier(index: index, isVisible: isVisible, reduceMotion: reduceMotion))
    }
}
