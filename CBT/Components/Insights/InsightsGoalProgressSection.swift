import SwiftUI

struct InsightsGoalProgressSection: View {
    let snapshot: InsightsDashboardSnapshot
    let moodGoalValue: Int

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Goal Progress"))
                .font(DSTypography.sectionTitle)
                .foregroundStyle(Theme.primaryText)

            InsightsGoalProgressCard(
                title: String(localized: "Consistency Goal"),
                subtitle: String(localized: "\(snapshot.activeDaysCount) of \(snapshot.consistencyGoalTarget) active days"),
                progress: snapshot.consistencyProgress,
                tint: themeManager.selectedColor
            )

            InsightsGoalProgressCard(
                title: String(localized: "Mood Goal (\(moodGoalValue)+)"),
                subtitle: String(localized: "\(Int((snapshot.moodGoalProgress * 100).rounded()))% entries hit target"),
                progress: snapshot.moodGoalProgress,
                tint: themeManager.secondaryColor
            )

            InsightsGoalProgressCard(
                title: String(localized: "Thought Relief Goal"),
                subtitle: snapshot.averageIntensityImprovement.map { String(localized: "\($0) of 15 pts average relief") } ?? String(localized: "Thought relief appears after a thought record."),
                progress: snapshot.thoughtGoalProgress,
                tint: .orange
            )

            InsightsGoalProgressCard(
                title: String(localized: "Exercise Goal"),
                subtitle: String(localized: "\(Int((snapshot.exerciseProgress * Double(snapshot.exerciseGoalTarget)).rounded())) of \(snapshot.exerciseGoalTarget) exercises"),
                progress: snapshot.exerciseProgress,
                tint: .green
            )
        }
    }
}

struct InsightsGoalProgressCard: View {
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
