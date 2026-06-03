import SwiftUI
import SwiftData

enum InsightsTimeRange: String, CaseIterable, Identifiable {
    case sevenDays = "7D"
    case thirtyDays = "30D"

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .sevenDays: return String(localized: "7D")
        case .thirtyDays: return String(localized: "30D")
        }
    }

    var days: Int {
        switch self {
        case .sevenDays: return 7
        case .thirtyDays: return 30
        }
    }
}

struct InsightsView: View {
    @State private var timeRange: InsightsTimeRange = .sevenDays
    @AppStorage("cbt_moodGoalValue") private var moodGoalValue = 7

    @State private var showingAddMood = false
    @State private var showingAddThought = false
    @State private var attemptingAddMood = false
    @State private var attemptingAddThought = false

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground().ignoresSafeArea()

                DeferredRenderView {
                    VStack {
                        InsightsHeadline()
                            .padding(.horizontal)
                        Spacer()
                    }
                } content: {
                    InsightsDashboardContent(
                        timeRange: $timeRange,
                        moodGoalValue: moodGoalValue,
                        attemptingAddMood: $attemptingAddMood,
                        attemptingAddThought: $attemptingAddThought
                    )
                }
            }
            .navigationTitle("")
            #if os(iOS)
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            #endif
            .hideNavigationBar()
        }
        .sheet(isPresented: $showingAddMood) {
            MoodCheckinView()
                .dsSheetPresentation()
        }
        .sheet(isPresented: $showingAddThought) {
            NewThoughtRecordFlowView()
                .dsSheetPresentation()
        }
        .withUsageGate(isAttemptingAction: $attemptingAddMood) {
            showingAddMood = true
        }
        .withUsageGate(isAttemptingAction: $attemptingAddThought) {
            showingAddThought = true
        }
    }
}

// MARK: - Subviews

private struct InsightsHeadline: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        TopHeadlineView(
            title: String(localized: "Insights"),
            leading: {
                StreakToolbarButton()
            },
            trailing: {
                HStack(spacing: 8) {
                    NavigationLink {
                        AssessmentsView()
                    } label: {
                        Image(systemName: "checklist")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(themeManager.selectedColor)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Open assessments"))

                    NavigationLink {
                        WeeklyReviewView()
                    } label: {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(themeManager.selectedColor)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Open weekly review"))

                    NavigationLink {
                        WeeklyReportView()
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(.body, weight: .bold))
                            .foregroundStyle(themeManager.selectedColor)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Open weekly report"))
                }
            }
        )
    }
}

private struct InsightsDashboardContent: View {
    @Binding var timeRange: InsightsTimeRange
    let moodGoalValue: Int
    @Binding var attemptingAddMood: Bool
    @Binding var attemptingAddThought: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moodEntries: [MoodEntry] = []
    @State private var moodCheckIns: [MoodCheckIn] = []
    @State private var thoughtRecords: [ThoughtRecord] = []
    @State private var exerciseCompletions: [ExerciseCompletion] = []
    @State private var journalEntries: [JournalEntry] = []
    @State private var flexibleJournalEntries: [FlexibleJournalEntry] = []
    @State private var breathingSessions: [BreathingSession] = []
    @State private var valueActionCompletions: [ValueActionCompletion] = []
    @State private var viewModel = InsightsViewModel()
    @State private var hasAppeared = false
    @State private var selectedWeeklyReportDate = Date()
    @State private var weeklyReport: WeeklyReport?
    @State private var weeklyReportIsLoading = true
    @State private var weeklyReportErrorMessage: String?
    @State private var selectedActionInsight: PlainLanguagePatternInsight?
    @State private var reminderPromptMoment: ReminderOptInMoment?
    @State private var isHandlingReminderPrompt = false

    init(
        timeRange: Binding<InsightsTimeRange>,
        moodGoalValue: Int,
        attemptingAddMood: Binding<Bool>,
        attemptingAddThought: Binding<Bool>
    ) {
        self._timeRange = timeRange
        self.moodGoalValue = moodGoalValue
        self._attemptingAddMood = attemptingAddMood
        self._attemptingAddThought = attemptingAddThought
    }
    var body: some View {
        Group {
            if viewModel.isCalculating {
                VStack(spacing: 12) {
                    InsightsHeadline()
                    Spacer()
                    InsightsLoadingStateView()
                    Spacer()
                }
            } else if moodEntries.isEmpty && moodCheckIns.isEmpty && thoughtRecords.isEmpty && exerciseCompletions.isEmpty && journalEntries.isEmpty && flexibleJournalEntries.isEmpty && breathingSessions.isEmpty && valueActionCompletions.isEmpty {
                VStack(spacing: 0) {
                    InsightsHeadline()
                        .padding(.horizontal, 16)
                    
                    InsightsEmptyStateView(
                        attemptingAddMood: $attemptingAddMood,
                        attemptingAddThought: $attemptingAddThought
                    )
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        InsightsHeadline()

                        InsightsStreaksCard(
                            snapshot: viewModel.dashboardSnapshot,
                            timeRange: timeRange,
                            moodGoalValue: moodGoalValue
                        )
                        .insightsEntrance(index: 0, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsMilestonesCard(
                            timeRange: $timeRange,
                            milestonesCompleted: viewModel.milestonesCompleted,
                            consistencyProgress: viewModel.consistencyProgress,
                            activeDaysCount: viewModel.activeDaysCount
                        )
                        .insightsEntrance(index: 1, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        PersonalGrowthDashboardCard(
                            snapshot: viewModel.personalGrowth
                        )
                        .insightsEntrance(index: 2, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsRetentionProgressSection(
                            snapshot: viewModel.retentionInsights
                        )
                        .insightsEntrance(index: 3, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsValuesPracticeCard(
                            weeklySummary: ValuesService.weeklySummary(completions: valueActionCompletions)
                        )
                        .insightsEntrance(index: 4, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsPatternSpotlightSection(
                            summary: viewModel.patternSummary,
                            onMakePlan: { insight in
                                selectedActionInsight = insight
                            }
                        )
                        .insightsEntrance(index: 5, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsCalendarPatternsCard(
                            summary: viewModel.patternSummary.calendarPatterns
                        )
                        .insightsEntrance(index: 5, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsPersonalCopingPlanSection(
                            planItems: viewModel.patternSummary.personalCopingPlan
                        )
                        .insightsEntrance(index: 6, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        CommonTriggersSection(
                            snapshot: viewModel.triggerLibrary
                        )
                        .insightsEntrance(index: 7, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsTrendsCard(
                            timeRange: timeRange,
                            dailyMoodAverages: viewModel.dailyMoodAverages,
                            averageMood: viewModel.averageMood,
                            averageIntensityImprovement: viewModel.averageIntensityImprovement,
                            moodVolatilityLast30Days: viewModel.moodVolatilityLast30Days,
                            moodGoalValue: moodGoalValue
                        )
                        .insightsEntrance(index: 8, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsWeeklyOverviewCard(
                            weeklyMoodAverages: viewModel.weeklyMoodAverages,
                            moodGoalValue: moodGoalValue
                        )
                        .onAppear {
                            AchievementService.shared.recordWeeklyReportViewed(in: modelContext)
                        }
                        .insightsEntrance(index: 9, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsWeeklyReportCard(
                            report: weeklyReport,
                            isLoading: weeklyReportIsLoading,
                            errorMessage: weeklyReportErrorMessage,
                            selectedWeek: selectedWeeklyReportDate,
                            canMoveForward: canMoveToNextWeeklyReport,
                            onPreviousWeek: { moveWeeklyReport(by: -1) },
                            onNextWeek: { moveWeeklyReport(by: 1) },
                            onAddCheckIn: { attemptingAddMood = true }
                        )
                        .onAppear {
                            AchievementService.shared.recordWeeklyReportViewed(in: modelContext)
                            Task { await prepareWeeklyInsightReminderPromptIfNeeded() }
                        }
                        .insightsEntrance(index: 10, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        if let reminderPromptMoment {
                            ReminderOptInPromptView(
                                moment: reminderPromptMoment,
                                isWorking: isHandlingReminderPrompt,
                                onAccept: {
                                    handleReminderPromptAccepted(reminderPromptMoment)
                                },
                                onDismiss: {
                                    handleReminderPromptDismissed(reminderPromptMoment)
                                }
                            )
                            .insightsEntrance(index: 11, isVisible: hasAppeared, reduceMotion: reduceMotion)
                        }

                        InsightsGoalProgressSection(
                            snapshot: viewModel.dashboardSnapshot,
                            moodGoalValue: moodGoalValue
                        )
                        .insightsEntrance(index: 12, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsTopMetricsSection(
                            snapshot: viewModel.dashboardSnapshot
                        )
                        .insightsEntrance(index: 13, isVisible: hasAppeared, reduceMotion: reduceMotion)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
                    .responsiveMaxWidth()
                    .frame(maxWidth: .infinity)
                }
                .onAppear {
                    guard !hasAppeared else { return }
                    if reduceMotion {
                        hasAppeared = true
                    } else {
                        withAnimation(.spring(response: 0.7, dampingFraction: 0.84)) {
                            hasAppeared = true
                        }
                    }
                }
            }
        }
        // Keep the task identity lightweight; avoid hashing live SwiftData
        // records during body evaluation.
        .task(id: "\(timeRange.rawValue)|\(moodGoalValue)|\(moodEntries.count)|\(moodCheckIns.count)|\(thoughtRecords.count)|\(exerciseCompletions.count)|\(journalEntries.count)|\(flexibleJournalEntries.count)|\(breathingSessions.count)|\(valueActionCompletions.count)") {
            await recalculateData()
        }
        .task(id: selectedWeeklyReportDate.timeIntervalSinceReferenceDate) {
            await refreshWeeklyReport()
            await prepareWeeklyInsightReminderPromptIfNeeded()
        }
        .task {
            await refreshFetchedModels()
        }
        .sheet(item: $selectedActionInsight) { insight in
            AddActivityView(
                initialTitle: insight.actionTitle ?? "",
                initialDescription: insight.actionDescription ?? "",
                initialCategory: insight.actionCategory
            )
            .dsSheetPresentation()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshFetchedModels()
                await refreshWeeklyReport()
                await prepareWeeklyInsightReminderPromptIfNeeded()
            }
        }
    }

    @MainActor
    private func refreshFetchedModels() async {
        moodEntries = LaunchSafeFetch.moodEntries(from: modelContext).reversed()
        moodCheckIns = LaunchSafeFetch.moodCheckIns(from: modelContext).reversed()
        thoughtRecords = LaunchSafeFetch.thoughtRecords(from: modelContext).reversed()
        exerciseCompletions = LaunchSafeFetch.exerciseCompletions(from: modelContext).reversed()
        journalEntries = LaunchSafeFetch.journalEntries(from: modelContext).reversed()
        flexibleJournalEntries = LaunchSafeFetch.flexibleJournalEntries(from: modelContext).reversed()
        breathingSessions = LaunchSafeFetch.breathingSessions(from: modelContext).reversed()
        valueActionCompletions = LaunchSafeFetch.valueActionCompletions(from: modelContext).reversed()
    }

    private func recalculateData() async {
        await viewModel.recalculate(
            timeRangeDays: timeRange.days,
            moodEntries: moodEntries,
            moodCheckIns: moodCheckIns,
            thoughtRecords: thoughtRecords,
            exerciseCompletions: exerciseCompletions,
            journalEntries: journalEntries,
            flexibleJournalEntries: flexibleJournalEntries,
            breathingSessions: breathingSessions,
            moodGoalValue: moodGoalValue
        )
    }

    @MainActor
    private func refreshWeeklyReport() async {
        weeklyReportIsLoading = true
        weeklyReportErrorMessage = nil

        do {
            weeklyReport = try WeeklyReportService().generateReport(
                forWeekContaining: selectedWeeklyReportDate,
                from: modelContext
            )
        } catch {
            weeklyReport = nil
            weeklyReportErrorMessage = error.localizedDescription
        }

        weeklyReportIsLoading = false
    }

    @MainActor
    private func prepareWeeklyInsightReminderPromptIfNeeded() async {
        guard !weeklyReportIsLoading, weeklyReport != nil else { return }
        reminderPromptMoment = await ReminderOptInService.shared.promptIfEligible(
            for: .firstWeeklyInsightViewed,
            hasReachedMoment: true
        )
    }

    private func handleReminderPromptAccepted(_ moment: ReminderOptInMoment) {
        guard !isHandlingReminderPrompt else { return }
        isHandlingReminderPrompt = true
        Task {
            _ = await ReminderOptInService.shared.accept(moment, modelContext: modelContext)
            await MainActor.run {
                reminderPromptMoment = nil
                isHandlingReminderPrompt = false
            }
        }
    }

    private func handleReminderPromptDismissed(_ moment: ReminderOptInMoment) {
        ReminderOptInService.shared.dismiss(moment)
        reminderPromptMoment = nil
    }

    private func moveWeeklyReport(by weeks: Int) {
        guard let newDate = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: selectedWeeklyReportDate) else {
            return
        }

        selectedWeeklyReportDate = newDate
    }

    private var canMoveToNextWeeklyReport: Bool {
        let calendar = Calendar.current
        let selectedStart = calendar.dateInterval(of: .weekOfYear, for: selectedWeeklyReportDate)?.start
            ?? calendar.startOfDay(for: selectedWeeklyReportDate)
        let currentStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? calendar.startOfDay(for: Date())
        return selectedStart < currentStart
    }
}

private struct InsightsValuesPracticeCard: View {
    @Environment(ThemeManager.self) private var themeManager

    let weeklySummary: [ValuePracticeSummary]

    private var totalCount: Int {
        weeklySummary.map(\.count).reduce(0, +)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Values Practiced")
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("THIS WEEK")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            if weeklySummary.isEmpty {
                Text("When you complete value-based tiny actions, they will show up here as gentle progress.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 10)
            } else {
                Text("\(totalCount) small \(totalCount == 1 ? "action" : "actions") connected to what matters.")
                    .font(DSTypography.body)
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(weeklySummary.prefix(5)) { summary in
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(themeManager.selectedColor)
                                .accessibilityHidden(true)

                            Text(summary.valueName)
                                .font(DSTypography.body.weight(.semibold))
                                .foregroundStyle(Theme.primaryText)

                            Spacer()

                            Text("\(summary.count)")
                                .font(DSTypography.body.weight(.bold))
                                .foregroundStyle(themeManager.selectedColor)
                                .monospacedDigit()
                        }
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

private struct InsightsEntranceModifier: ViewModifier {
    let index: Int
    let isVisible: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible || reduceMotion ? 0 : 18)
            .scaleEffect(isVisible || reduceMotion ? 1 : 0.98)
            .animation(
                reduceMotion ? nil : .spring(response: 0.62, dampingFraction: 0.86).delay(Double(index) * 0.07),
                value: isVisible
            )
    }
}

private extension View {
    func insightsEntrance(index: Int, isVisible: Bool, reduceMotion: Bool) -> some View {
        modifier(InsightsEntranceModifier(index: index, isVisible: isVisible, reduceMotion: reduceMotion))
    }
}
