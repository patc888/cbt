import SwiftUI
import Charts

struct TrendsSection: View {
    @Environment(ThemeManager.self) private var themeManager: ThemeManager?

    let entries: [MoodEntry]
    let title: String

    @AppStorage("cbt_moodGoalEnabled") private var moodGoalEnabled = false
    @AppStorage("cbt_moodGoalValue") private var moodGoalValue = 7

    @State private var selectedRange: TrendsRange = .sevenDays

    init(entries: [MoodEntry], title: String = "Mood Trends") {
        self.entries = entries
        self.title = title
    }

    private var tintColor: Color {
        themeManager?.selectedColor ?? .accentColor
    }

    private var cardBackgroundColor: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    private var cardBorderColor: Color {
        #if os(macOS)
        Color(nsColor: .separatorColor)
        #else
        Color(uiColor: .separator)
        #endif
    }

    private var clampedGoalValue: Int {
        min(10, max(1, moodGoalValue))
    }

    private var filteredEntries: [MoodEntry] {
        DateBucketing.filtered(entries, by: selectedRange) { $0.createdAt }
    }

    private var entriesCountText: String {
        "\(filteredEntries.count) ENTRIES"
    }

    private var dailyMoodAverages: [DailyMoodAverage] {
        let grouped = Dictionary(grouping: filteredEntries) { entry in
            Calendar.current.startOfDay(for: entry.createdAt)
        }

        return grouped.map { date, dayEntries in
            let average = Double(dayEntries.map(\.moodScore).reduce(0, +)) / Double(dayEntries.count)
            return DailyMoodAverage(date: date, averageScore: average)
        }
        .sorted { $0.date < $1.date }
    }

    private var peakAverage: Double? {
        dailyMoodAverages.map(\.averageScore).max()
    }

    private var lowestAverage: Double? {
        dailyMoodAverages.map(\.averageScore).min()
    }

    private var currentMoodScore: Int? {
        filteredEntries.max(by: { $0.createdAt < $1.createdAt })?.moodScore
    }

    private var movingAverageWindow: Int {
        guard !dailyMoodAverages.isEmpty else { return 0 }
        switch selectedRange {
        case .sevenDays:
            return min(5, dailyMoodAverages.count)
        case .thirtyDays, .ninetyDays, .all:
            return min(7, dailyMoodAverages.count)
        }
    }

    private var movingAverage: Double? {
        guard movingAverageWindow > 0 else { return nil }
        let windowValues = dailyMoodAverages.suffix(movingAverageWindow).map(\.averageScore)
        let total = windowValues.reduce(0, +)
        return total / Double(windowValues.count)
    }

    private func scoreText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(value.formatted(.number.precision(.fractionLength(1))))/10"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(entriesCountText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 10) {
                Toggle("Show Goal Line", isOn: $moodGoalEnabled)
                    .font(.subheadline)

                if moodGoalEnabled {
                    Stepper(value: $moodGoalValue, in: 1...10) {
                        Text("Goal: \(clampedGoalValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            RangePicker(title: "Mood Trend Range", selection: $selectedRange)

            if dailyMoodAverages.isEmpty {
                Text("No mood data for this range.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                Chart {
                    ForEach(dailyMoodAverages) { item in
                        LineMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Mood", item.averageScore)
                        )
                        .foregroundStyle(tintColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))

                        PointMark(
                            x: .value("Date", item.date, unit: .day),
                            y: .value("Mood", item.averageScore)
                        )
                        .foregroundStyle(tintColor)
                    }

                    if moodGoalEnabled {
                        RuleMark(y: .value("Goal", Double(clampedGoalValue)))
                            .foregroundStyle(.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                    }
                }
                .chartYScale(domain: 1...10)
                .frame(height: 220)
            }

            MetricCardGrid {
                MetricCard(
                    icon: "arrow.up.right",
                    title: "Peak",
                    value: scoreText(peakAverage)
                )

                MetricCard(
                    icon: "arrow.down.right",
                    title: "Lowest",
                    value: scoreText(lowestAverage)
                )

                MetricCard(
                    icon: "clock",
                    title: "Current",
                    value: currentMoodScore.map { "\($0)/10" } ?? "—"
                )

                MetricCard(
                    icon: "waveform.path.ecg",
                    title: "Moving Average",
                    value: scoreText(movingAverage),
                    subtitle: movingAverageWindow > 0 ? "Last \(movingAverageWindow) daily points" : nil
                )
            }
        }
        .padding(16)
        .background(cardBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(cardBorderColor.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal)
        .tint(tintColor)
        .onAppear {
            if moodGoalValue != clampedGoalValue {
                moodGoalValue = clampedGoalValue
            }
        }
    }
}
