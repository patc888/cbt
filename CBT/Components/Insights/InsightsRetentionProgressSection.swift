import SwiftUI

struct InsightsRetentionProgressSection: View {
    let snapshot: RetentionInsightsSnapshot

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(String(localized: "Progress Cards"))
                    .font(DSTypography.sectionTitle)
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if !snapshot.cards.isEmpty {
                    Text(String(localized: "\(snapshot.cards.count) UPDATES"))
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .foregroundStyle(themeManager.selectedColor)
                        .tracking(1.2)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(themeManager.selectedColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if snapshot.cards.isEmpty {
                InsightsRetentionEmptyCard(message: snapshot.emptyStateMessage)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 230), spacing: 10, alignment: .top)],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(snapshot.cards) { card in
                        InsightsRetentionProgressCard(card: card)
                    }
                }
            }

            if !snapshot.patternUnlocks.isEmpty {
                InsightsPersonalPatternUnlocksView(unlocks: snapshot.patternUnlocks)
                    .padding(.top, 4)
            }
        }
    }
}

private struct InsightsPersonalPatternUnlocksView: View {
    let unlocks: [PersonalPatternUnlock]

    @Environment(ThemeManager.self) private var themeManager

    private var unlockedCount: Int {
        unlocks.filter(\.isUnlocked).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(String(localized: "Personal Pattern Unlocks"))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                if unlockedCount > 0 {
                    Text(String(localized: "\(unlockedCount) UNLOCKED"))
                        .font(.system(.caption2, design: .rounded).weight(.black))
                        .foregroundStyle(themeManager.selectedColor)
                        .tracking(1.2)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(themeManager.selectedColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            VStack(spacing: 8) {
                ForEach(unlocks) { unlock in
                    InsightsPatternUnlockRow(unlock: unlock)
                }
            }
        }
        .padding(Theme.paddingMedium)
        .cardStyle()
    }
}

private struct InsightsPatternUnlockRow: View {
    let unlock: PersonalPatternUnlock

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: unlock.iconName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(unlock.isUnlocked ? themeManager.selectedColor : Theme.secondaryText)
                .frame(width: 32, height: 32)
                .background(
                    (unlock.isUnlocked ? themeManager.selectedColor : Theme.secondaryText).opacity(0.12),
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(unlock.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(unlock.message)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(unlock.isUnlocked ? Theme.primaryText : Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                Text(unlock.detail)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DSTheme.cardBackground.opacity(unlock.isUnlocked ? 0.55 : 0.28))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct InsightsRetentionProgressCard: View {
    let card: RetentionInsightCard

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: card.iconName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 34, height: 34)
                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)

                Text(card.title)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                if let valueText = card.valueText {
                    Text(valueText)
                        .font(.system(.title3, design: .rounded).weight(.black))
                        .foregroundStyle(themeManager.selectedColor)
                        .monospacedDigit()
                        .minimumScaleFactor(0.75)
                }
            }

            Text(card.message)
                .font(.system(.body, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            Text(card.detail)
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .padding(Theme.paddingMedium)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}

private struct InsightsRetentionEmptyCard: View {
    let message: String?

    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(themeManager.selectedColor)
                .frame(width: 36, height: 36)
                .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            Text(message ?? String(localized: "A little more data will unlock progress cards."))
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.paddingMedium)
        .cardStyle()
        .accessibilityElement(children: .combine)
    }
}
