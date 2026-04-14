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
        ZStack {
            ThemedBackground().ignoresSafeArea()

            DeferredRenderView {
                VStack {
                    TopHeadlineView(title: String(localized: "Insights"))
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        #endif
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

    @Query(filter: #Predicate<MoodEntry> { !$0.isDeleted }, sort: \MoodEntry.createdAt, order: .forward)
    private var moodEntries: [MoodEntry]

    @Query(filter: #Predicate<ThoughtRecord> { !$0.isDeleted }, sort: \ThoughtRecord.createdAt, order: .forward)
    private var thoughtRecords: [ThoughtRecord]

    @Query(filter: #Predicate<ExerciseCompletion> { !$0.isDeleted }, sort: \ExerciseCompletion.createdAt, order: .forward)
    private var exerciseCompletions: [ExerciseCompletion]

    @Query(filter: #Predicate<JournalEntry> { !$0.isDeleted }, sort: \JournalEntry.createdAt, order: .forward)
    private var journalEntries: [JournalEntry]

    @State private var viewModel = InsightsViewModel()

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

    private var refreshSignature: String {
        [
            timeRange.rawValue,
            String(moodGoalValue),
            QueryChangeSignature.make(for: moodEntries),
            QueryChangeSignature.make(for: thoughtRecords),
            QueryChangeSignature.make(for: exerciseCompletions),
            QueryChangeSignature.make(for: journalEntries)
        ].joined(separator: "|")
    }

    var body: some View {
        Group {
            if viewModel.isCalculating {
                VStack {
                    TopHeadlineView(title: String(localized: "Insights"))
                    Spacer()
                    InsightsLoadingStateView()
                    Spacer()
                }
            } else if moodEntries.isEmpty && thoughtRecords.isEmpty && exerciseCompletions.isEmpty && journalEntries.isEmpty {
                VStack(spacing: 0) {
                    TopHeadlineView(title: String(localized: "Insights"))
                        .padding(.horizontal, 16)
                    
                    InsightsEmptyStateView(
                        attemptingAddMood: $attemptingAddMood,
                        attemptingAddThought: $attemptingAddThought
                    )
                }
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        TopHeadlineView(title: String(localized: "Insights"))

                        insightsContent
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
                    .responsiveMaxWidth()
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .task(id: refreshSignature) {
            await recalculateData()
        }
    }

    @ViewBuilder
    private var insightsContent: some View {
        InsightsStreaksCard(
            currentStreak: viewModel.currentStreak,
            longestStreak: viewModel.longestStreak
        )

        InsightsMilestonesCard(
            timeRange: $timeRange,
            milestonesCompleted: viewModel.milestonesCompleted,
            consistencyProgress: viewModel.consistencyProgress,
            activeDaysCount: viewModel.activeDaysCount
        )

        InsightsTrendsCard(
            timeRange: timeRange,
            dailyMoodAverages: viewModel.dailyMoodAverages,
            averageMood: viewModel.averageMood,
            averageIntensityImprovement: viewModel.averageIntensityImprovement,
            moodVolatilityLast30Days: viewModel.moodVolatilityLast30Days,
            moodGoalValue: moodGoalValue
        )

        InsightsWeeklyOverviewCard(
            weeklyMoodAverages: viewModel.weeklyMoodAverages,
            moodGoalValue: moodGoalValue
        )

        InsightsGoalProgressSection(
            activeDaysCount: viewModel.activeDaysCount,
            consistencyGoalTarget: viewModel.consistencyGoalTarget,
            consistencyProgress: viewModel.consistencyProgress,
            moodGoalValue: moodGoalValue,
            moodGoalProgress: viewModel.moodGoalProgress,
            averageIntensityImprovement: viewModel.averageIntensityImprovement,
            thoughtGoalProgress: viewModel.thoughtGoalProgress,
            exerciseGoalTarget: viewModel.exerciseGoalTarget,
            exerciseProgress: viewModel.exerciseProgress
        )

        InsightsTopMetricsSection(
            topEmotions: viewModel.topEmotions,
            topTriggers: viewModel.topTriggers,
            topDistortions: viewModel.topDistortions
        )
    }

    private func recalculateData() async {
        await viewModel.recalculate(
            timeRangeDays: timeRange.days,
            moodEntries: moodEntries,
            thoughtRecords: thoughtRecords,
            exerciseCompletions: exerciseCompletions,
            journalEntries: journalEntries,
            moodGoalValue: moodGoalValue
        )
    }
}
