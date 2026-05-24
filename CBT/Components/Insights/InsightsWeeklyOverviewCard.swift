import SwiftUI
import Charts

struct InsightsWeeklyOverviewCard: View {
    let weeklyMoodAverages: [WeeklyMoodAverage]
    let moodGoalValue: Int

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(String(localized: "Weekly Overview"))
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Text(String(localized: "LAST 8 WEEKS"))
                    .font(.system(.caption, design: .rounded).weight(.black))
                    .foregroundStyle(Theme.secondaryText.opacity(0.65))
                    .tracking(1.5)
            }

            if weeklyMoodAverages.isEmpty {
                Text(String(localized: "Weekly trends appear once check-ins span more than one week. Keep using the app at a pace that feels manageable."))
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
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    themeManager.selectedColor.opacity(0.95),
                                    themeManager.secondaryColor.opacity(0.55)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(4)
                    }

                    RuleMark(y: .value(String(localized: "Mood Goal"), Double(moodGoalValue)))
                        .foregroundStyle(themeManager.secondaryColor.opacity(0.85))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
                .chartYScale(domain: 0...11)
                .chartPlotStyle { plotArea in
                    plotArea
                        .background(themeManager.selectedColor.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
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
