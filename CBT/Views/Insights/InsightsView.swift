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
    @State private var isDashboardReady = false

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    TopHeadlineView(title: String(localized: "Insights"))

                    if isDashboardReady {
                        InsightsDashboardContent(
                            timeRange: $timeRange,
                            moodGoalValue: moodGoalValue
                        )
                    } else {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.secondary.opacity(0.1))
                            .frame(height: 200)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .task {
            guard !isDashboardReady else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            await Task.yield()
            guard !Task.isCancelled else { return }
            isDashboardReady = true
        }
    }
}

// MARK: - Subviews

private struct InsightsDashboardContent: View {
    private struct RefreshKey: Equatable {
        let timeRange: InsightsTimeRange
        let moodCount: Int
        let thoughtCount: Int
        let completionCount: Int
        let journalCount: Int
        let moodGoalValue: Int
    }

    @Binding var timeRange: InsightsTimeRange
    let moodGoalValue: Int

    @Query(filter: #Predicate<MoodEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var moodEntries: [MoodEntry]

    @Query(filter: #Predicate<ThoughtRecord> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var thoughtRecords: [ThoughtRecord]

    @Query(filter: #Predicate<ExerciseCompletion> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var exerciseCompletions: [ExerciseCompletion]

    @Query(filter: #Predicate<JournalEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var journalEntries: [JournalEntry]

    @State private var viewModel = InsightsViewModel()

    private var refreshKey: RefreshKey {
        RefreshKey(
            timeRange: timeRange,
            moodCount: moodEntries.count,
            thoughtCount: thoughtRecords.count,
            completionCount: exerciseCompletions.count,
            journalCount: journalEntries.count,
            moodGoalValue: moodGoalValue
        )
    }

    var body: some View {
        ZStack {
            if viewModel.isCalculating {
                InsightsLoadingStateView()
            } else {
                insightsContent
            }
        }
        .task(id: refreshKey) {
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
