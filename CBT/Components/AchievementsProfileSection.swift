import SwiftUI

struct AchievementsProfileSection: View {
    @Environment(ThemeManager.self) private var themeManager

    let achievements: [Achievement]
    let progress: [String: AchievementProgress]

    @State private var showsAllAchievements = false

    private var unlockedAchievements: [Achievement] {
        achievements.filter(\.isUnlocked)
    }

    private var unlockedCount: Int {
        unlockedAchievements.count
    }

    private var latestUnlockedAchievements: [Achievement] {
        unlockedAchievements.sorted {
            ($0.unlockedAt ?? $0.createdAt) > ($1.unlockedAt ?? $1.createdAt)
        }
    }

    private var nextAchievements: [Achievement] {
        Array(
            achievements
                .filter { !$0.isUnlocked }
                .sorted { lhs, rhs in
                    let lhsProgress = progress[lhs.title]?.fraction ?? 0
                    let rhsProgress = progress[rhs.title]?.fraction ?? 0

                    if lhsProgress != rhsProgress {
                        return lhsProgress > rhsProgress
                    }

                    let lhsTarget = progress[lhs.title]?.targetCount ?? Int.max
                    let rhsTarget = progress[rhs.title]?.targetCount ?? Int.max
                    if lhsTarget != rhsTarget {
                        return lhsTarget < rhsTarget
                    }

                    return lhs.createdAt < rhs.createdAt
                }
                .prefix(3)
        )
    }

    private var groupedAchievements: [AchievementGroup] {
        AchievementUnlockCondition.allCases.compactMap { condition in
            let matchingAchievements = achievements.filter { $0.unlockCondition == condition }
            guard !matchingAchievements.isEmpty else { return nil }
            return AchievementGroup(condition: condition, achievements: matchingAchievements)
        }
    }

    var body: some View {
        DSCardContainer {
            if achievements.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 88)
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    AchievementCountProgressBar(
                        unlockedCount: unlockedCount,
                        totalCount: achievements.count
                    )

                    if !latestUnlockedAchievements.isEmpty {
                        latestUnlockedStrip
                    }

                    if !nextAchievements.isEmpty {
                        Divider()
                            .overlay(DSTheme.separator.opacity(0.6))

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Next Milestones")
                                .font(DSTypography.cardTitle)
                                .foregroundStyle(DSTheme.primaryText)
                                .textCase(.uppercase)

                            ForEach(nextAchievements) { achievement in
                                AchievementProgressRow(
                                    achievement: achievement,
                                    progress: progress[achievement.title]
                                )
                            }
                        }
                    }

                    Divider()
                        .overlay(DSTheme.separator.opacity(0.6))

                    allAchievementsDisclosure
                }
            }
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                profileIcon
                headerText
                Spacer(minLength: DSSpacing.small)
                countPill
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    profileIcon
                    headerText
                }
                countPill
            }
        }
    }

    private var profileIcon: some View {
        ZStack {
            Circle()
                .fill(themeManager.selectedColor.opacity(0.14))
                .frame(width: 52, height: 52)

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(themeManager.selectedColor)
        }
        .accessibilityHidden(true)
    }

    private var headerText: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Achievements")
                .font(DSTypography.sectionHeader)
                .foregroundStyle(DSTheme.primaryText)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)

            Text("\(unlockedCount) of \(achievements.count) unlocked")
                .font(DSTypography.caption)
                .foregroundStyle(DSTheme.secondaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var countPill: some View {
        Text("\(achievementPercent)%")
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(themeManager.selectedColor)
            .monospacedDigit()
            .lineLimit(1)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(themeManager.selectedColor.opacity(0.12), in: Capsule())
    }

    private var achievementPercent: Int {
        guard !achievements.isEmpty else { return 0 }
        return Int((Double(unlockedCount) / Double(achievements.count) * 100).rounded())
    }

    private var latestUnlockedStrip: some View {
        HStack(spacing: 8) {
            ForEach(Array(latestUnlockedAchievements.prefix(4))) { achievement in
                AchievementCompactPill(achievement: achievement)
            }

            if unlockedCount > 4 {
                Text("+\(unlockedCount - 4)")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(themeManager.selectedColor)
                    .monospacedDigit()
                    .frame(width: 34, height: 34)
                    .background(themeManager.selectedColor.opacity(0.12), in: Circle())
                    .accessibilityLabel("\(unlockedCount - 4) more unlocked achievements")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var allAchievementsDisclosure: some View {
        DisclosureGroup(isExpanded: $showsAllAchievements) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(groupedAchievements) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.condition.label)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(DSTheme.secondaryText)
                            .textCase(.uppercase)

                        VStack(spacing: 4) {
                            ForEach(group.achievements) { achievement in
                                AchievementProgressRow(
                                    achievement: achievement,
                                    progress: progress[achievement.title]
                                )
                            }
                        }
                    }
                }
            }
            .padding(.top, 12)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(themeManager.selectedColor)
                    .frame(width: 22)
                    .accessibilityHidden(true)

                Text("All Achievements")
                    .font(DSTypography.listLabel)
                    .foregroundStyle(DSTheme.primaryText)

                Spacer(minLength: DSSpacing.small)

                Text("\(achievements.count)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(DSTheme.secondaryText)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .tint(themeManager.selectedColor)
    }
}

private struct AchievementGroup: Identifiable {
    let condition: AchievementUnlockCondition
    let achievements: [Achievement]

    var id: String {
        condition.rawValue
    }
}

private struct AchievementCountProgressBar: View {
    @Environment(ThemeManager.self) private var themeManager

    let unlockedCount: Int
    let totalCount: Int

    private var fraction: Double {
        guard totalCount > 0 else { return 0 }
        return min(1, Double(unlockedCount) / Double(totalCount))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DSTheme.elevatedFill)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                themeManager.selectedColor,
                                Color(hex: themeManager.selectedTheme.secondaryHex)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(8, proxy.size.width * fraction))
            }
        }
        .frame(height: 8)
        .accessibilityHidden(true)
    }
}

private struct AchievementCompactPill: View {
    @Environment(ThemeManager.self) private var themeManager

    let achievement: Achievement

    var body: some View {
        ZStack {
            Circle()
                .fill(themeManager.selectedColor.opacity(0.12))
                .frame(width: 34, height: 34)

            Image(systemName: achievement.imageName)
                .font(.system(size: 14, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(themeManager.selectedColor)
        }
        .accessibilityLabel("\(achievement.title), unlocked")
    }
}

private struct AchievementProgressRow: View {
    @Environment(ThemeManager.self) private var themeManager

    let achievement: Achievement
    let progress: AchievementProgress?

    private var progressFraction: Double {
        achievement.isUnlocked ? 1 : (progress?.fraction ?? 0)
    }

    private var statusText: String {
        if achievement.isUnlocked {
            return "Unlocked"
        }
        return progress?.progressText ?? "On the way"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 12) {
                AchievementRowIcon(achievement: achievement)

                VStack(alignment: .leading, spacing: 3) {
                    Text(achievement.title)
                        .font(DSTypography.listLabel)
                        .foregroundStyle(DSTheme.primaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(achievement.achievementDescription)
                        .font(DSTypography.caption)
                        .foregroundStyle(DSTheme.secondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(statusText)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(achievement.isUnlocked ? .white : DSTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.66)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(achievement.isUnlocked ? themeManager.selectedColor : DSTheme.elevatedFill)
                    }
                    .frame(maxWidth: 118, alignment: .trailing)
            }

            AchievementRowProgressBar(fraction: progressFraction, isUnlocked: achievement.isUnlocked)
                .padding(.leading, 48)
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        [
            achievement.title,
            achievement.isUnlocked ? "unlocked" : "on the way",
            achievement.achievementDescription,
            statusText
        ].joined(separator: ". ")
    }
}

private struct AchievementRowIcon: View {
    @Environment(ThemeManager.self) private var themeManager

    let achievement: Achievement

    private var accent: Color {
        achievement.isUnlocked ? themeManager.selectedColor : DSTheme.secondaryText
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(achievement.isUnlocked ? 0.15 : 0.10))
                .frame(width: 36, height: 36)

            Image(systemName: achievement.imageName)
                .font(.system(size: 16, weight: .bold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accent)
                .saturation(achievement.isUnlocked ? 1 : 0)
        }
        .opacity(achievement.isUnlocked ? 1 : 0.72)
        .accessibilityHidden(true)
    }
}

private struct AchievementRowProgressBar: View {
    @Environment(ThemeManager.self) private var themeManager

    let fraction: Double
    let isUnlocked: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DSTheme.elevatedFill)

                Capsule()
                    .fill(isUnlocked ? themeManager.selectedColor : themeManager.selectedColor.opacity(0.64))
                    .frame(width: max(6, proxy.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}
