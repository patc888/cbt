import SwiftUI

struct InsightsStreaksCard: View {
    let currentStreak: Int
    let longestStreak: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Activity Streaks"))
                .font(DSTypography.sectionTitle)
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
