import SwiftUI

struct InsightsTopMetricsSection: View {
    let snapshot: InsightsDashboardSnapshot

    var body: some View {
        VStack(spacing: 14) {
            InsightsRankingCard(
                title: String(localized: "Top Emotions"),
                rows: snapshot.topEmotions.map { ($0.name, $0.count) },
                emptyText: String(localized: "Emotion patterns appear after mood check-ins with emotion tags.")
            )
            InsightsRankingCard(
                title: String(localized: "Top Triggers"),
                rows: snapshot.topTriggers.map { ($0.name, $0.count) },
                emptyText: String(localized: "Trigger patterns appear after check-ins include what was happening around you.")
            )

            InsightsActivityMoodCard(
                activities: snapshot.patternSummary.activityMoodAverages
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

            InsightsThoughtRecordStatsCard(stats: snapshot.thoughtRecordStats)
        }
    }
}

struct InsightsThoughtRecordStatsCard: View {
    let stats: ThoughtRecordCompletionStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Thought Record Practice"))
                .font(DSTypography.sectionTitle)
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if stats.completedCount == 0 && stats.draftCount == 0 {
                Text(String(localized: "Thought record stats appear after you start one."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        statPill(title: String(localized: "Completed"), value: "\(stats.completedCount)")
                        statPill(title: String(localized: "Drafts"), value: "\(stats.draftCount)")
                    }

                    HStack(spacing: 10) {
                        statPill(title: String(localized: "Saved"), value: "\(stats.savedReframeCount)")
                        statPill(title: String(localized: "Favorites"), value: "\(stats.favoriteReframeCount)")
                    }

                    if let average = stats.averageIntensityChange {
                        Text(String(localized: "Feelings shifted by \(average) points on average after completed records."))
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !stats.recurringDistortions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(localized: "Recurring thinking traps"))
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.secondaryText)

                            ForEach(stats.recurringDistortions.prefix(3)) { distortion in
                                HStack {
                                    Text(distortion.name)
                                        .font(.system(.subheadline, design: .rounded).weight(.medium))
                                        .foregroundStyle(Theme.primaryText)
                                    Spacer()
                                    Text("\(distortion.count)")
                                        .font(.system(.caption, design: .rounded).weight(.bold))
                                        .foregroundStyle(Theme.secondaryText)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private func statPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.primaryText)
            Text(title)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.secondaryText.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DSCornerRadius.small, style: .continuous))
    }
}

struct InsightsActivityMoodCard: View {
    let activities: [ActivityMoodAverage]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Mood By Activity"))
                .font(DSTypography.sectionTitle)
                .foregroundStyle(Theme.primaryText)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if activities.isEmpty {
                Text(String(localized: "Activity patterns appear after mood check-ins include what was part of your day."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 10) {
                    ForEach(activities) { activity in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(activity.name)
                                    .font(.system(.body, design: .rounded).weight(.medium))
                                    .foregroundStyle(Theme.primaryText)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("\(activity.entryCount) entries")
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(Theme.secondaryText)
                            }
                            .layoutPriority(1)

                            Spacer()

                            Text("\(activity.averageMood.formatted(.number.precision(.fractionLength(1))))/10")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(Theme.primaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(activity.name): average mood \(activity.averageMood.formatted(.number.precision(.fractionLength(1)))) out of 10 across \(activity.entryCount) entries")
                    }
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
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
                Text(String(localized: "Context patterns appear after check-ins include places, activities, or situations."))
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

    private var maxCount: Int {
        max(rows.map(\.1).max() ?? 1, 1)
    }

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
                        VStack(alignment: .leading, spacing: 7) {
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

                            GeometryReader { proxy in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(themeManager.selectedColor.opacity(0.08))

                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [themeManager.selectedColor, themeManager.secondaryColor.opacity(0.72)],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: proxy.size.width * CGFloat(row.1) / CGFloat(maxCount))
                                }
                            }
                            .frame(height: 6)
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
