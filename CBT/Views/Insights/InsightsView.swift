import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Query(filter: #Predicate<MoodEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var moodEntries: [MoodEntry]

    @Query(filter: #Predicate<ThoughtRecord> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var thoughtRecords: [ThoughtRecord]

    @Query(filter: #Predicate<ExerciseCompletion> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var exerciseCompletions: [ExerciseCompletion]
    
    @Query(filter: #Predicate<JournalEntry> { $0.isDeleted == false }, sort: \.createdAt, order: .forward)
    private var journalEntries: [JournalEntry]

    @State private var timeRange: TimeRange = .sevenDays
    @AppStorage("cbt_moodGoalValue") private var moodGoalValue = 7
    @Environment(ThemeManager.self) private var themeManager
    @State private var viewModel = InsightsViewModel()

    enum TimeRange: String, CaseIterable, Identifiable {
        case sevenDays = "7D"
        case thirtyDays = "30D"

        var id: String { rawValue }

        var days: Int {
            switch self {
            case .sevenDays: return 7
            case .thirtyDays: return 30
            }
        }
    }

    var body: some View {
        ZStack {
            ThemedBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    TopHeadlineView(title: "Insights")

                    SegmentedToggle(selection: $timeRange, options: TimeRange.allCases, titleKey: \.rawValue)

                    if viewModel.isCalculating {
                        VStack {
                            ProgressView()
                                .padding()
                            Text("Crunching your data...")
                                .foregroundStyle(Theme.secondaryText)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 40)
                    } else {
                        streaksCard
                        milestonesRingCard
                        trendsCard
                        weeklyAverageCard
                        goalProgressSection
                        
                        topMetricsSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, LayoutMetrics.floatingToolbarBottomInset + 12)
                .responsiveMaxWidth()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await recalculateData()
        }
        .onChange(of: timeRange) { _, _ in
            Task { await recalculateData() }
        }
        .onChange(of: moodEntries.count + thoughtRecords.count + exerciseCompletions.count + journalEntries.count) { _, _ in
            Task { await recalculateData() }
        }
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

    // MARK: - Streaks
    private var streaksCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activity Streaks")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
            
            HStack(spacing: 12) {
                MiniStatCard(
                    title: "Current Streak",
                    value: "\(viewModel.currentStreak)",
                    unit: viewModel.currentStreak == 1 ? "day" : "days",
                    icon: "flame.fill",
                    iconColor: .orange,
                    valueColor: Theme.primaryText,
                    state: viewModel.currentStreak > 0 ? .success : .neutral
                )
                
                MiniStatCard(
                    title: "Longest Streak",
                    value: "\(viewModel.longestStreak)",
                    unit: viewModel.longestStreak == 1 ? "day" : "days",
                    icon: "star.fill",
                    iconColor: .yellow,
                    valueColor: Theme.primaryText,
                    state: .neutral
                )
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Activity streaks: Current \(viewModel.currentStreak) days, Longest \(viewModel.longestStreak) days.")
    }

    // MARK: - Milestones Ring
    private var milestonesRingCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Milestones")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(viewModel.milestonesCompleted)/4")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            ZStack {
                Circle()
                    .stroke(themeManager.secondaryColor.opacity(0.15), lineWidth: 24)
                    .frame(width: 190, height: 190)

                Circle()
                    .trim(from: 0, to: max(0.001, viewModel.consistencyProgress))
                    .stroke(themeManager.secondaryColor, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 190, height: 190)

                Circle()
                    .stroke(themeManager.selectedColor.opacity(0.12), lineWidth: 18)
                    .frame(width: 136, height: 136)

                Circle()
                    .trim(from: 0, to: max(0.001, Double(viewModel.milestonesCompleted) / 4.0))
                    .stroke(themeManager.selectedColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 136, height: 136)

                VStack(spacing: 4) {
                    Text("\(Int((viewModel.consistencyProgress * 100).rounded()))%")
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                        .foregroundStyle(Theme.primaryText)
                    Text("CONSISTENCY")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Consistency Progress")
            .accessibilityValue("\(Int((viewModel.consistencyProgress * 100).rounded())) percent. \(viewModel.milestonesCompleted) of 4 milestones completed.")

            Text("\(viewModel.activeDaysCount) active days in last \(timeRange.days) days")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    // MARK: - Daily Trends
    private var trendsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Daily Trends")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("LAST \(timeRange.days) DAYS")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            if viewModel.dailyMoodAverages.isEmpty {
                Text("No mood data for this range.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 18)
            } else {
                Chart {
                    ForEach(viewModel.dailyMoodAverages) { point in
                        LineMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Mood", point.averageScore)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.2))
                        .foregroundStyle(themeManager.selectedColor)

                        PointMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Mood", point.averageScore)
                        )
                        .foregroundStyle(themeManager.selectedColor)
                    }

                    RuleMark(y: .value("Mood Goal", Double(moodGoalValue)))
                        .foregroundStyle(themeManager.secondaryColor.opacity(0.85))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .chartYScale(domain: 1...10)
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Daily mood trend chart")
                .accessibilityValue("Showing mood averages over the last \(timeRange.days) days. Average mood is \(viewModel.averageMood?.formatted(.number.precision(.fractionLength(1))) ?? "not available").")
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MiniStatCard(
                    title: "Avg Mood",
                    value: viewModel.averageMood.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "-",
                    unit: "/10",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: themeManager.selectedColor,
                    valueColor: Theme.primaryText,
                    state: .neutral
                )

                MiniStatCard(
                    title: "Thought Relief",
                    value: viewModel.averageIntensityImprovement.map { "\($0)" } ?? "-",
                    unit: "pts",
                    icon: "brain",
                    iconColor: themeManager.secondaryColor,
                    valueColor: Theme.primaryText,
                    state: .neutral
                )
            }
            
            if let volatility = viewModel.moodVolatilityLast30Days {
                Divider().opacity(0.5).padding(.vertical, 4)
                HStack {
                    ZStack {
                        Circle()
                            .fill(Theme.toggleBackgroundColor(for: .light))
                            .frame(width: 32, height: 32)
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(themeManager.selectedColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Mood Volatility (\(volatility.formatted(.number.precision(.fractionLength(1)))))")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                        Text("Average day-to-day score change.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Mood volatility is \(volatility.formatted(.number.precision(.fractionLength(1)))). Average day-to-day absolute change in score over last 30 days.")
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
    
    // MARK: - Weekly Overview
    private var weeklyAverageCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly Overview")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("LAST 8 WEEKS")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            if viewModel.weeklyMoodAverages.isEmpty {
                Text("Not enough data to graph weekly trends.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 18)
            } else {
                Chart {
                    ForEach(viewModel.weeklyMoodAverages) { point in
                        BarMark(
                            x: .value("Week", point.weekStart, unit: .weekOfYear),
                            y: .value("Mood", point.averageScore)
                        )
                        .foregroundStyle(themeManager.selectedColor.opacity(0.8))
                        .cornerRadius(4)
                    }

                    RuleMark(y: .value("Mood Goal", Double(moodGoalValue)))
                        .foregroundStyle(themeManager.secondaryColor.opacity(0.85))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .chartYScale(domain: 1...10)
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Weekly mood trend chart")
                .accessibilityValue("Showing weekly average mood over the last 8 weeks.")
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    // MARK: - Goals Section
    private var goalProgressSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Goal Progress")
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            goalProgressCard(
                title: "Consistency Goal",
                subtitle: "\(viewModel.activeDaysCount) of \(viewModel.consistencyGoalTarget) active days",
                progress: viewModel.consistencyProgress,
                tint: themeManager.selectedColor
            )

            goalProgressCard(
                title: "Mood Goal (\(moodGoalValue)+)",
                subtitle: "\(Int((viewModel.moodGoalProgress * 100).rounded()))% entries hit target",
                progress: viewModel.moodGoalProgress,
                tint: themeManager.secondaryColor
            )

            goalProgressCard(
                title: "Thought Relief Goal",
                subtitle: viewModel.averageIntensityImprovement.map { "\($0) of 15 pts average relief" } ?? "No thought records yet",
                progress: viewModel.thoughtGoalProgress,
                tint: .orange
            )

            goalProgressCard(
                title: "Exercise Goal",
                subtitle: "\(Int((viewModel.exerciseProgress * Double(viewModel.exerciseGoalTarget)).rounded())) of \(viewModel.exerciseGoalTarget) exercises",
                progress: viewModel.exerciseProgress,
                tint: .green
            )
        }
    }
    
    // MARK: - Top Metrics
    private var topMetricsSection: some View {
        VStack(spacing: 14) {
            rankingCard(title: "Top Emotions", rows: viewModel.topEmotions.map { ($0.name, $0.count) }, emptyText: "No emotions recorded.")
            rankingCard(title: "Top Triggers", rows: viewModel.topTriggers.map { ($0.name, $0.count) }, emptyText: "No triggers recorded.")
            
            if !viewModel.topDistortions.isEmpty {
                rankingCard(title: "Top Distortions", rows: viewModel.topDistortions.map { ($0.name, $0.count) }, emptyText: "")
            }
        }
    }

    // MARK: - Helpers
    private func goalProgressCard(title: String, subtitle: String, progress: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(Int((min(1, max(0, progress)) * 100).rounded()))%")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.8))
            }

            Text(subtitle)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.toggleBackgroundColor(for: .light))
                        .frame(height: 10)

                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * min(1, max(0, progress)), height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(subtitle)")
        .accessibilityValue("\(Int((min(1, max(0, progress)) * 100).rounded())) percent complete")
    }

    private func rankingCard(title: String, rows: [(String, Int)], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            if rows.isEmpty {
                Text(emptyText)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack {
                            Text(row.0)
                                .font(.system(.body, design: .rounded).weight(.medium))
                            Spacer()
                            Text("\(row.1)")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(themeManager.selectedColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(row.0): \(row.1) times")
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
    
}
