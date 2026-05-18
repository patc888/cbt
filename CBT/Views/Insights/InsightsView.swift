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

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var moodEntries: [MoodEntry] = []
    @State private var thoughtRecords: [ThoughtRecord] = []
    @State private var exerciseCompletions: [ExerciseCompletion] = []
    @State private var journalEntries: [JournalEntry] = []
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
    var body: some View {
        Group {
            if viewModel.isCalculating {
                VStack(spacing: 12) {
                    AppScreenHeadline(title: String(localized: "Insights"))
                    Spacer()
                    InsightsLoadingStateView()
                    Spacer()
                }
            } else if moodEntries.isEmpty && thoughtRecords.isEmpty && exerciseCompletions.isEmpty && journalEntries.isEmpty {
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
                            snapshot: viewModel.dashboardSnapshot,
                            moodGoalValue: moodGoalValue
                        )

                        InsightsTopMetricsSection(
                            snapshot: viewModel.dashboardSnapshot
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
                    .responsiveMaxWidth()
                    .frame(maxWidth: .infinity)
                }
            }
        }
        // Keep the task identity lightweight; avoid hashing live SwiftData
        // records during body evaluation.
        .task(id: "\(timeRange.rawValue)|\(moodGoalValue)|\(moodEntries.count)|\(thoughtRecords.count)|\(exerciseCompletions.count)|\(journalEntries.count)") {
            await recalculateData()
        }
        .task {
            await refreshFetchedModels()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshFetchedModels() }
        }
    }

    @MainActor
    private func refreshFetchedModels() async {
        moodEntries = LaunchSafeFetch.moodEntries(from: modelContext).reversed()
        thoughtRecords = LaunchSafeFetch.thoughtRecords(from: modelContext).reversed()
        exerciseCompletions = LaunchSafeFetch.exerciseCompletions(from: modelContext).reversed()
        journalEntries = LaunchSafeFetch.journalEntries(from: modelContext).reversed()
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
