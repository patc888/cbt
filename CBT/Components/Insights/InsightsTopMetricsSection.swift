import SwiftUI

struct InsightsTopMetricsSection: View {
    let snapshot: InsightsDashboardSnapshot

    var body: some View {
        VStack(spacing: 14) {
            InsightsRankingCard(
                title: String(localized: "Top Emotions"),
                rows: snapshot.topEmotions.map { ($0.name, $0.count) },
                emptyText: String(localized: "No emotions recorded.")
            )
            InsightsRankingCard(
                title: String(localized: "Top Triggers"),
                rows: snapshot.topTriggers.map { ($0.name, $0.count) },
                emptyText: String(localized: "No triggers recorded.")
            )

            InsightsContextCorrelationCard(
                correlations: snapshot.contextTagCorrelations
            )

            if !snapshot.topDistortions.isEmpty {
                InsightsRankingCard(
                    title: String(localized: "Top Distortions"),
                    rows: snapshot.topDistortions.map { ($0.name, $0.count) },
                    emptyText: ""
                )
            }
        }
    }
}

struct InsightsContextCorrelationCard: View {
    let correlations: [ContextTagMoodCorrelation]

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Mood By Context"))
                .font(DSTypography.sectionTitle)
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if correlations.isEmpty {
                Text(String(localized: "No context tags recorded."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(correlations) { correlation in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(correlation.name)
                                    .font(.system(.body, design: .rounded).weight(.medium))
                                    .foregroundStyle(Theme.primaryText)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("\(correlation.entryCount) entries")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .layoutPriority(1)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 3) {
                                Text("\(correlation.averageMood.formatted(.number.precision(.fractionLength(1))))/10")
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(Theme.primaryText)

                                Text(deltaText(for: correlation.deltaFromOverall))
                                    .font(.system(.caption2, design: .rounded).weight(.bold))
                                    .foregroundStyle(deltaColor(for: correlation.deltaFromOverall))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(accessibilityLabel(for: correlation))
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func deltaText(for delta: Double) -> String {
        let formatted = abs(delta).formatted(.number.precision(.fractionLength(1)))
        if delta > 0.05 {
            return "+\(formatted) vs avg"
        } else if delta < -0.05 {
            return "-\(formatted) vs avg"
        } else {
            return "near avg"
        }
    }

    private func deltaColor(for delta: Double) -> Color {
        if delta > 0.05 {
            return themeManager.selectedColor
        } else if delta < -0.05 {
            return Theme.errorRed
        } else {
            return Theme.secondaryText
        }
    }

    private func accessibilityLabel(for correlation: ContextTagMoodCorrelation) -> String {
        "\(correlation.name): average mood \(correlation.averageMood.formatted(.number.precision(.fractionLength(1)))) out of 10, \(deltaText(for: correlation.deltaFromOverall)), \(correlation.entryCount) entries"
    }
}

struct InsightsRankingCard: View {
    let title: String
    let rows: [(String, Int)]
    let emptyText: String

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(DSTypography.sectionTitle)
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
