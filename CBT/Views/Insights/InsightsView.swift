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
                        AppScreenHeadline(title: String(localized: "Insights"))
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
        }
        .sheet(isPresented: $showingAddThought) {
            NewThoughtRecordFlowView()
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
    @State private var viewModel = InsightsViewModel()
    @State private var hasAppeared = false
    @State private var selectedWeeklyReportDate = Date()
    @State private var weeklyReport: WeeklyReport?
    @State private var weeklyReportIsLoading = true
    @State private var weeklyReportErrorMessage: String?

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
                    AppScreenHeadline(title: String(localized: "Insights"))
                    Spacer()
                    InsightsLoadingStateView()
                    Spacer()
                }
            } else if moodEntries.isEmpty && moodCheckIns.isEmpty && thoughtRecords.isEmpty && exerciseCompletions.isEmpty && journalEntries.isEmpty {
                VStack(spacing: 0) {
                    AppScreenHeadline(title: String(localized: "Insights"))
                        .padding(.horizontal, 16)
                    
                    InsightsEmptyStateView(
                        attemptingAddMood: $attemptingAddMood,
                        attemptingAddThought: $attemptingAddThought
                    )
                }
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        AppScreenHeadline(title: String(localized: "Insights"))

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

                        InsightsPatternSpotlightSection(
                            summary: viewModel.patternSummary
                        )
                        .insightsEntrance(index: 2, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsTrendsCard(
                            timeRange: timeRange,
                            dailyMoodAverages: viewModel.dailyMoodAverages,
                            averageMood: viewModel.averageMood,
                            averageIntensityImprovement: viewModel.averageIntensityImprovement,
                            moodVolatilityLast30Days: viewModel.moodVolatilityLast30Days,
                            moodGoalValue: moodGoalValue
                        )
                        .insightsEntrance(index: 3, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsWeeklyOverviewCard(
                            weeklyMoodAverages: viewModel.weeklyMoodAverages,
                            moodGoalValue: moodGoalValue
                        )
                        .onAppear {
                            AchievementService.shared.recordWeeklyReportViewed(in: modelContext)
                        }
                        .insightsEntrance(index: 4, isVisible: hasAppeared, reduceMotion: reduceMotion)

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
                        }
                        .insightsEntrance(index: 5, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsGoalProgressSection(
                            snapshot: viewModel.dashboardSnapshot,
                            moodGoalValue: moodGoalValue
                        )
                        .insightsEntrance(index: 6, isVisible: hasAppeared, reduceMotion: reduceMotion)

                        InsightsTopMetricsSection(
                            snapshot: viewModel.dashboardSnapshot
                        )
                        .insightsEntrance(index: 7, isVisible: hasAppeared, reduceMotion: reduceMotion)
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
        .task(id: "\(timeRange.rawValue)|\(moodGoalValue)|\(moodEntries.count)|\(moodCheckIns.count)|\(thoughtRecords.count)|\(exerciseCompletions.count)|\(journalEntries.count)") {
            await recalculateData()
        }
        .task(id: selectedWeeklyReportDate.timeIntervalSinceReferenceDate) {
            await refreshWeeklyReport()
        }
        .task {
            await refreshFetchedModels()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshFetchedModels()
                await refreshWeeklyReport()
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
    }

    private func recalculateData() async {
        await viewModel.recalculate(
            timeRangeDays: timeRange.days,
            moodEntries: moodEntries,
            moodCheckIns: moodCheckIns,
            thoughtRecords: thoughtRecords,
            exerciseCompletions: exerciseCompletions,
            journalEntries: journalEntries,
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
