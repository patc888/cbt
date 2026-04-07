import SwiftUI
import Charts

struct InsightsLoadingStateView: View {
    var body: some View {
        VStack {
            ProgressView()
                .padding()
            Text(String(localized: "Crunching your data..."))
                .foregroundStyle(Theme.secondaryText)
                .font(.subheadline)
        }
        .padding(.vertical, 40)
    }
}

struct InsightsStreaksCard: View {
    let currentStreak: Int
    let longestStreak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Activity Streaks"))
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            HStack(spacing: 12) {
                MiniStatCard(
                    title: String(localized: "Current Streak"),
                    value: "\(currentStreak)",
                    unit: currentStreak == 1 ? String(localized: "day") : String(localized: "days"),
                    icon: "flame.fill",
                    iconColor: .orange,
                    iconGradient: [Color.orange, Color.red],
                    valueColor: Theme.primaryText,
                    state: currentStreak > 0 ? .success : .neutral
                )

                MiniStatCard(
                    title: String(localized: "Longest Streak"),
                    value: "\(longestStreak)",
                    unit: longestStreak == 1 ? String(localized: "day") : String(localized: "days"),
                    icon: "star.fill",
                    iconColor: .yellow,
                    iconGradient: [Color.yellow, Color.orange],
                    valueColor: Theme.primaryText,
                    state: .neutral
                )
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Activity streaks: Current \(currentStreak) days, Longest \(longestStreak) days."))
    }
}

struct InsightsMilestonesCard: View {
    @Binding var timeRange: InsightsTimeRange
    let milestonesCompleted: Int
    let consistencyProgress: Double
    let activeDaysCount: Int

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text(String(localized: "Milestones"))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text("\(milestonesCompleted)/4")
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            SegmentedToggle(selection: $timeRange, options: InsightsTimeRange.allCases, titleKey: \.localizedName)

            ZStack {
                Circle()
                    .stroke(themeManager.secondaryColor.opacity(0.15), lineWidth: 24)
                    .frame(width: 190, height: 190)

                Circle()
                    .trim(from: 0, to: max(0.001, consistencyProgress))
                    .stroke(themeManager.secondaryColor, style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 190, height: 190)

                Circle()
                    .stroke(themeManager.selectedColor.opacity(0.12), lineWidth: 18)
                    .frame(width: 136, height: 136)

                Circle()
                    .trim(from: 0, to: max(0.001, Double(milestonesCompleted) / 4.0))
                    .stroke(themeManager.selectedColor, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 136, height: 136)

                VStack(spacing: 4) {
                    Text("\(Int((consistencyProgress * 100).rounded()))%")
                        .font(.system(.largeTitle, design: .rounded).weight(.black))
                        .foregroundStyle(Theme.primaryText)
                    Text("CONSISTENCY")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.secondaryText)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Consistency Progress")
            .accessibilityValue("\(Int((consistencyProgress * 100).rounded())) percent. \(milestonesCompleted) of 4 milestones completed.")

            Text("\(activeDaysCount) active days in last \(timeRange.days) days")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

struct InsightsTrendsCard: View {
    let timeRange: InsightsTimeRange
    let dailyMoodAverages: [DailyMoodAverage]
    let averageMood: Double?
    let averageIntensityImprovement: Int?
    let moodVolatilityLast30Days: Double?
    let moodGoalValue: Int

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Daily Trends"))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text(String(localized: "LAST \(timeRange.days) DAYS"))
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            if dailyMoodAverages.isEmpty {
                Text(String(localized: "No mood data for this range."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 18)
            } else {
                Chart {
                    ForEach(dailyMoodAverages) { point in
                        LineMark(
                            x: .value(String(localized: "Date"), point.date, unit: .day),
                            y: .value(String(localized: "Mood"), point.averageScore)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 2.2))
                        .foregroundStyle(themeManager.selectedColor)

                        PointMark(
                            x: .value(String(localized: "Date"), point.date, unit: .day),
                            y: .value(String(localized: "Mood"), point.averageScore)
                        )
                        .foregroundStyle(themeManager.selectedColor)
                    }

                    RuleMark(y: .value(String(localized: "Mood Goal"), Double(moodGoalValue)))
                        .foregroundStyle(themeManager.secondaryColor.opacity(0.85))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .chartYScale(domain: 0...10)
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Daily mood trend chart"))
                .accessibilityValue(String(localized: "Showing mood averages over the last \(timeRange.days) days. Average mood is \(averageMood?.formatted(.number.precision(.fractionLength(1))) ?? String(localized: "not available"))."))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MiniStatCard(
                    title: String(localized: "Avg Mood"),
                    value: averageMood.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "-",
                    unit: "/10",
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: themeManager.selectedColor,
                    valueColor: Theme.primaryText,
                    state: .neutral
                )

                MiniStatCard(
                    title: String(localized: "Thought Relief"),
                    value: averageIntensityImprovement.map { "\($0)" } ?? "-",
                    unit: String(localized: "pts"),
                    icon: "brain",
                    iconColor: themeManager.secondaryColor,
                    valueColor: Theme.primaryText,
                    state: .neutral
                )
            }

            if let volatility = moodVolatilityLast30Days {
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
                        Text(String(localized: "Mood Volatility (\(volatility.formatted(.number.precision(.fractionLength(1)))))"))
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.primaryText)
                        Text(String(localized: "Average day-to-day score change."))
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                    }
                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(String(localized: "Mood volatility is \(volatility.formatted(.number.precision(.fractionLength(1)))). Average day-to-day absolute change in score over last 30 days."))
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

struct InsightsWeeklyOverviewCard: View {
    let weeklyMoodAverages: [WeeklyMoodAverage]
    let moodGoalValue: Int

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Weekly Overview"))
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text(String(localized: "LAST 8 WEEKS"))
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            if weeklyMoodAverages.isEmpty {
                Text(String(localized: "Not enough data to graph weekly trends."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .padding(.vertical, 18)
            } else {
                Chart {
                    ForEach(weeklyMoodAverages) { point in
                        BarMark(
                            x: .value(String(localized: "Week"), point.weekStart, unit: .weekOfYear),
                            y: .value(String(localized: "Mood"), point.averageScore)
                        )
                        .foregroundStyle(themeManager.selectedColor.opacity(0.8))
                        .cornerRadius(4)
                    }

                    RuleMark(y: .value(String(localized: "Mood Goal"), Double(moodGoalValue)))
                        .foregroundStyle(themeManager.secondaryColor.opacity(0.85))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .chartYScale(domain: 0...11)
                .frame(height: 180)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(String(localized: "Weekly mood trend chart"))
                .accessibilityValue(String(localized: "Showing weekly average mood over the last 8 weeks."))
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

struct InsightsGoalProgressSection: View {
    let activeDaysCount: Int
    let consistencyGoalTarget: Int
    let consistencyProgress: Double
    let moodGoalValue: Int
    let moodGoalProgress: Double
    let averageIntensityImprovement: Int?
    let thoughtGoalProgress: Double
    let exerciseGoalTarget: Int
    let exerciseProgress: Double

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Goal Progress"))
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)

            InsightsGoalProgressCard(
                title: String(localized: "Consistency Goal"),
                subtitle: String(localized: "\(activeDaysCount) of \(consistencyGoalTarget) active days"),
                progress: consistencyProgress,
                tint: themeManager.selectedColor
            )

            InsightsGoalProgressCard(
                title: String(localized: "Mood Goal (\(moodGoalValue)+)"),
                subtitle: String(localized: "\(Int((moodGoalProgress * 100).rounded()))% entries hit target"),
                progress: moodGoalProgress,
                tint: themeManager.secondaryColor
            )

            InsightsGoalProgressCard(
                title: String(localized: "Thought Relief Goal"),
                subtitle: averageIntensityImprovement.map { String(localized: "\($0) of 15 pts average relief") } ?? String(localized: "No thought records yet"),
                progress: thoughtGoalProgress,
                tint: .orange
            )

            InsightsGoalProgressCard(
                title: String(localized: "Exercise Goal"),
                subtitle: String(localized: "\(Int((exerciseProgress * Double(exerciseGoalTarget)).rounded())) of \(exerciseGoalTarget) exercises"),
                progress: exerciseProgress,
                tint: .green
            )
        }
    }
}

struct InsightsTopMetricsSection: View {
    let topEmotions: [EmotionCount]
    let topTriggers: [TriggerCount]
    let topDistortions: [DistortionCount]

    var body: some View {
        VStack(spacing: 14) {
            InsightsRankingCard(
                title: String(localized: "Top Emotions"),
                rows: topEmotions.map { ($0.name, $0.count) },
                emptyText: String(localized: "No emotions recorded.")
            )
            InsightsRankingCard(
                title: String(localized: "Top Triggers"),
                rows: topTriggers.map { ($0.name, $0.count) },
                emptyText: String(localized: "No triggers recorded.")
            )

            if !topDistortions.isEmpty {
                InsightsRankingCard(
                    title: String(localized: "Top Distortions"),
                    rows: topDistortions.map { ($0.name, $0.count) },
                    emptyText: ""
                )
            }
        }
    }
}

private struct InsightsGoalProgressCard: View {
    let title: String
    let subtitle: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
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
}

private struct InsightsRankingCard: View {
    let title: String
    let rows: [(String, Int)]
    let emptyText: String

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if rows.isEmpty {
                Text(emptyText)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(row.0)
                                .font(.system(.body, design: .rounded).weight(.medium))
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                            Spacer()
                            Text("\(row.1)")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(themeManager.selectedColor.opacity(0.12))
                                .clipShape(Capsule())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
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
