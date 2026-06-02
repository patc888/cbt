import SwiftUI

struct PersonalGrowthDashboardCard: View {
    let snapshot: PersonalGrowthSnapshot

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    scoreBlock
                    Divider()
                    milestoneBlock
                }

                VStack(alignment: .leading, spacing: 16) {
                    scoreBlock
                    milestoneBlock
                }
            }

            emotionChart
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(String(localized: "Personal Growth"))
                .font(DSTypography.sectionTitle)
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Text(String(localized: "90 DAYS"))
                .font(.system(.caption2, design: .rounded).weight(.black))
                .foregroundStyle(themeManager.selectedColor)
                .tracking(1.2)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(themeManager.selectedColor.opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var scoreBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(snapshot.consistencyScore)")
                .font(.system(size: 46, weight: .black, design: .rounded))
                .foregroundStyle(Theme.primaryText)
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("Consistency score \(snapshot.consistencyScore) out of 100")

            VStack(alignment: .leading, spacing: 3) {
                Text(String(localized: "Consistency Score"))
                    .font(.system(.body, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)

                Text("\(snapshot.entriesLastThreeMonths) entries - \(snapshot.averageEntriesPerWeek.formatted(.number.precision(.fractionLength(1)))) per week")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var milestoneBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Milestone Badges"))
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)

            FlowLayout(spacing: 8) {
                ForEach(snapshot.milestones) { milestone in
                    MilestoneBadgeChip(milestone: milestone)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emotionChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "Frequently Used Emotion Tags"))
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(Theme.secondaryText)

            if snapshot.topEmotionTags.isEmpty {
                Text(String(localized: "Emotion bars appear after mood or thought entries include emotion tags."))
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 9) {
                    ForEach(snapshot.topEmotionTags) { emotion in
                        PersonalGrowthEmotionBar(
                            emotion: emotion,
                            maxCount: max(snapshot.topEmotionTags.map(\.count).max() ?? 1, 1)
                        )
                    }
                }
            }
        }
    }
}

private struct MilestoneBadgeChip: View {
    let milestone: UserMilestone

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: milestone.isAchieved ? "checkmark.seal.fill" : "seal")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(milestone.isAchieved ? themeManager.selectedColor : Theme.secondaryText.opacity(0.65))

            Text("\(milestone.entryCount)")
                .font(.system(.caption, design: .rounded).weight(.black))
                .foregroundStyle(Theme.primaryText)

            Text(milestone.title)
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(milestone.isAchieved ? themeManager.selectedColor.opacity(0.12) : Theme.secondaryText.opacity(0.08))
        .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(milestone.title), \(milestone.entryCount) entries, \(milestone.isAchieved ? "achieved" : "not achieved")")
    }
}

private struct PersonalGrowthEmotionBar: View {
    let emotion: EmotionCount
    let maxCount: Int

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(emotion.name)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .layoutPriority(1)

                Spacer()

                Text("\(emotion.count)")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.secondaryText)
                    .monospacedDigit()
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(themeManager.secondaryColor.opacity(0.12))

                    Capsule()
                        .fill(themeManager.selectedColor)
                        .frame(width: proxy.size.width * CGFloat(emotion.count) / CGFloat(maxCount))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(emotion.name): \(emotion.count) uses")
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let rows = rows(in: width, subviews: subviews)
        return CGSize(
            width: width,
            height: rows.reduce(0) { $0 + $1.height } + CGFloat(max(rows.count - 1, 0)) * spacing
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = bounds.origin
        for row in rows(in: bounds.width, subviews: subviews) {
            origin.x = bounds.minX
            for item in row.items {
                item.subview.place(
                    at: origin,
                    proposal: ProposedViewSize(item.size)
                )
                origin.x += item.size.width + spacing
            }
            origin.y += row.height + spacing
        }
    }

    private func rows(in width: CGFloat, subviews: Subviews) -> [(items: [(subview: LayoutSubview, size: CGSize)], height: CGFloat)] {
        var rows: [(items: [(subview: LayoutSubview, size: CGSize)], height: CGFloat)] = []
        var currentItems: [(subview: LayoutSubview, size: CGSize)] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width

            if !currentItems.isEmpty && nextWidth > width {
                rows.append((items: currentItems, height: currentHeight))
                currentItems = [(subview, size)]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                currentItems.append((subview, size))
                currentWidth = nextWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !currentItems.isEmpty {
            rows.append((items: currentItems, height: currentHeight))
        }

        return rows
    }
}
