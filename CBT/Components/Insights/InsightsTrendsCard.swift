import SwiftUI
import Charts

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
